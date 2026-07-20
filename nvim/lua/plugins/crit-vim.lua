return {
  {
    dir = vim.fn.expand("~/workspace/crit-vim"),
    name = "crit-vim",
    lazy = false, -- need VimEnter to register the socket on startup
    config = function()
      require("crit-vim").setup({ default_keys = true }) -- <leader>C{,C} comment operator
    end,
  },
}
