-- Write Session.vim to cwd on exit so tmux-resurrect's
-- `@resurrect-strategy-nvim 'session'` (which runs `nvim -S`) can restore it.
return {
  {
    "LazyVim/LazyVim",
    init = function()
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          if vim.fn.argc(-1) == 0 then return end
          local cwd = vim.fn.getcwd()
          if vim.fn.filewritable(cwd) == 2 then
            vim.cmd("mksession! " .. vim.fn.fnameescape(cwd .. "/Session.vim"))
          end
        end,
      })
    end,
  },
}
