return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview (working tree)" },
    { "<leader>gD", "<cmd>DiffviewOpen origin/HEAD...HEAD<cr>", desc = "Diffview vs origin/HEAD" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history (current file)" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File history (branch)" },
    { "<leader>gx", "<cmd>DiffviewClose<cr>", desc = "Diffview close" },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      default = { layout = "diff2_horizontal" }, -- side-by-side
      merge_tool = { layout = "diff3_mixed" },
    },
  },
}
