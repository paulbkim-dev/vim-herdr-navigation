-- vim-herdr-navigation — Neovim side
--
-- Seamless <C-h/j/k/l> navigation between Neovim splits and herdr panes: move
-- between Neovim splits, and at a split edge hand off to herdr so focus crosses
-- into the neighbouring herdr pane. When not inside herdr it falls back to tmux
-- (if any) or plain wincmd, so a tmux setup keeps working.
--
-- <C-h/j/k/l> is only the default: g:herdr_nav_keys swaps any direction's key,
-- and g:herdr_nav_no_mappings plus the <Plug>(HerdrNavigate*) mappings allow
-- any binding at all. See the mapping section at the bottom.
--
-- Load it so it wins over other <C-h/j/k/l> mappings (e.g. vim-tmux-navigator).
-- The simplest reliable way is to drop it in your config's after/plugin dir:
--   cp editor/nvim.lua ~/.config/nvim/after/plugin/herdr_nav.lua
-- or source it from your config after plugins load:
--   dofile("/path/to/vim-herdr-navigation/editor/nvim.lua")

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: cross into the surrounding multiplexer.
  if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == "" then
      herdr = "herdr"
    end
    -- Target this pane explicitly: `--current` resolves to the server's
    -- globally focused pane, which is not necessarily the one we are in.
    vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--pane", vim.env.HERDR_PANE_ID })
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux[dir])
  end
end

-- <Plug> mappings, one per direction, so any key can drive the navigation.
local plug = {
  left = "<Plug>(HerdrNavigateLeft)",
  down = "<Plug>(HerdrNavigateDown)",
  up = "<Plug>(HerdrNavigateUp)",
  right = "<Plug>(HerdrNavigateRight)",
}
local wincmds = { left = "h", down = "j", up = "k", right = "l" }
for dir, lhs in pairs(plug) do
  vim.keymap.set("n", lhs, function()
    nav(wincmds[dir], dir)
  end, { silent = true, desc = "Navigate " .. dir .. " (vim/herdr)" })
end

-- Default keys: <C-h/j/k/l>. Two ways to change them (set before this file
-- loads), both mirrored on the herdr side by HERDR_NAV_KEY_LEFT/DOWN/UP/RIGHT
-- (see "Custom keys" in the README):
--   vim.g.herdr_nav_keys       replace any subset of the defaults, e.g.
--                              { left = "<C-Left>", right = "<C-Right>" };
--                              an empty string drops that direction
--   vim.g.herdr_nav_no_mappings = 1
--                              define no keys at all; bind the <Plug>
--                              mappings above yourself
if vim.g.herdr_nav_no_mappings ~= 1 then
  local keys = vim.tbl_extend("force", {
    left = "<C-h>",
    down = "<C-j>",
    up = "<C-k>",
    right = "<C-l>",
  }, vim.g.herdr_nav_keys or {})
  for dir, lhs in pairs(keys) do
    if plug[dir] and lhs ~= "" then
      vim.keymap.set("n", lhs, plug[dir], { silent = true, remap = true })
    end
  end
end
