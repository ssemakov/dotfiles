return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
  keys = {
    { "<leader>go", "<cmd>Octo actions<cr>", desc = "Octo actions" },
    { "<leader>gp", "<cmd>Octo pr list<cr>", desc = "Octo PR list" },
  },
  opts = { picker = "snacks" },
}
