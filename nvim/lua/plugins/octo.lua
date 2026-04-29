return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      enable_builtin = true,
      use_local_fs = true,
    },
    keys = {
      { "<leader>gi", "<cmd>Octo issue list<cr>", desc = "List issues (Octo)" },
      { "<leader>gp", "<cmd>Octo pr list<cr>", desc = "List PRs (Octo)" },
      { "<leader>gP", "<cmd>Octo pr create<cr>", desc = "Create PR (Octo)" },
      { "<leader>gr", "<cmd>Octo review start<cr>", desc = "Start review (Octo)" },
      { "<leader>gS", "<cmd>Octo search<cr>", desc = "Search GitHub (Octo)" },
    },
  },
}
