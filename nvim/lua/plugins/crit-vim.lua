return {
  {
    dir = vim.fn.expand("~/workspace/crit-vim"),
    name = "crit-vim",
    lazy = false, -- need VimEnter to register the socket on startup
  },
}
