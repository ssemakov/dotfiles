return {
  {
    "subnut/nvim-ghost.nvim",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("nvim_ghost_user_autocommands", { clear = false }),
        pattern = "*.*",
        callback = function(ev)
          if vim.api.nvim_buf_get_name(0) == "" then
            vim.api.nvim_buf_set_name(0, vim.fs.joinpath(vim.fn.tempname(), ev.match .. ".txt"))
          end
          if vim.bo.filetype == "" then
            vim.bo.filetype = "text"
          end
        end,
      })
    end,
  },
}
