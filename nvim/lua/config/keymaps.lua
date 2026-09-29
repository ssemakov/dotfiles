-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Neovide is a real GUI app, so Cmd+V arrives as the <D-v> keycode rather than
-- a terminal paste. Unmapped, Neovide types the literal "<D-v>" text instead
-- of pasting (https://neovide.dev/faq.html).
if vim.g.neovide then
  vim.keymap.set({ "n", "i", "v", "c", "t" }, "<D-v>", function()
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end, { silent = true, desc = "Paste (system clipboard)" })
end

-- Copy the current buffer's file path to the system clipboard (+ register).
vim.keymap.set("n", "<leader>fy", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify(path, vim.log.levels.INFO, { title = "Copied absolute path" })
end, { desc = "Copy absolute file path" })

vim.keymap.set("n", "<leader>fY", function()
  local path = vim.fn.fnamemodify(vim.fn.expand("%"), ":.")
  vim.fn.setreg("+", path)
  vim.notify(path, vim.log.levels.INFO, { title = "Copied relative path" })
end, { desc = "Copy relative file path" })

-- Toggle LSP for the current buffer. Diagnostics-off (<leader>ud) only hides output;
-- this stops the servers, which is what reclaims CPU on big TS monorepos.
vim.keymap.set("n", "<leader>uo", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients > 0 then
    vim.lsp.stop_client(clients)
    vim.notify("LSP off", vim.log.levels.WARN)
  else
    vim.cmd.edit() -- re-triggers FileType, servers re-attach
    vim.notify("LSP on")
  end
end, { desc = "Toggle LSP (buffer)" })
