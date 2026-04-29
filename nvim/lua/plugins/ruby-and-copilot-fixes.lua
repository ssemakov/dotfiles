return {
  -- 1. Make rubocop use the project's bundled gem instead of mason's globally-installed
  --    rubocop, which conflicts with `standard` (rubocop ~> 1.65.0 vs mason's 1.86.1).
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rubocop = {
          mason = false,
          cmd = { "bundle", "exec", "rubocop", "--lsp" },
        },
        copilot = { enabled = false },
        copilot_ls = { enabled = false },
      },
    },
  },
}
