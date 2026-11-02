local repo = assert(vim.env.HERDR_NAV_TEST_REPO, "HERDR_NAV_TEST_REPO is required")
local log = assert(vim.env.HERDR_NAV_TEST_LOG, "HERDR_NAV_TEST_LOG is required")

dofile(repo .. "/editor/nvim.lua")

local function callback(lhs)
  local normalized = string.upper(lhs)
  for _, mapping in ipairs(vim.api.nvim_get_keymap("n")) do
    if mapping.lhs == normalized then
      assert(type(mapping.callback) == "function", lhs .. " must use a Lua callback")
      return mapping.callback
    end
  end
  error(lhs .. " must have a normal-mode mapping")
end

for _, lhs in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
  callback(lhs)
end

vim.cmd("vsplit")
vim.cmd("wincmd l")
local right = vim.api.nvim_get_current_win()
callback("<C-h>")()
assert(vim.api.nvim_get_current_win() ~= right, "Ctrl+h must move inside Neovim first")
assert(vim.fn.filereadable(log) == 0, "internal split movement must not call Herdr")

vim.cmd("only")
callback("<C-l>")()
assert(vim.fn.filereadable(log) == 1, "edge navigation must call Herdr")
local lines = vim.fn.readfile(log)
assert(#lines == 1, "edge navigation must make one Herdr call")
local expected = vim.env.HERDR_NAV_TEST_EXPECT or "pane focus --direction right --pane w-test:p1"
assert(lines[1] == expected, "unexpected Herdr command: " .. lines[1])

print("Neovim navigation verification passed")
