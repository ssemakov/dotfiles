-- Drop-in replacement for tsserver/vtsls. Faster on large TS monorepos.
-- Disabled by default — flip `enabled = true` if vtsls feels slow.
return {
  "pmizio/typescript-tools.nvim",
  enabled = false,
  dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
  ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  opts = {},
}
