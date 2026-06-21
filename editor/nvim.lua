-- vim-herdr-navigation — Neovim side
--
-- Seamless <C-h/j/k/l> navigation between Neovim splits and herdr panes: move
-- between Neovim splits, and at a split edge hand off to herdr so focus crosses
-- into the neighbouring herdr pane. When not inside herdr it falls back to tmux
-- (if any) or plain wincmd, so a tmux setup keeps working.
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
    vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
  elseif vim.env.TMUX and vim.env.TMUX ~= "" then
    local tmux = { left = "Left", down = "Down", up = "Up", right = "Right" }
    pcall(vim.cmd, "TmuxNavigate" .. tmux[dir])
  end
end

local function map(lhs, wincmd, dir, desc)
  vim.keymap.set("n", lhs, function()
    nav(wincmd, dir)
  end, { silent = true, noremap = true, desc = desc })
end

map("<C-h>", "h", "left", "Navigate left (vim/herdr)")
map("<C-j>", "j", "down", "Navigate down (vim/herdr)")
map("<C-k>", "k", "up", "Navigate up (vim/herdr)")
map("<C-l>", "l", "right", "Navigate right (vim/herdr)")
