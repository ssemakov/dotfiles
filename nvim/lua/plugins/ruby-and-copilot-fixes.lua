return {
  -- Make rubocop use the project's bundled gem instead of mason's globally-installed
  -- rubocop, which conflicts with `standard` (rubocop ~> 1.65.0 vs mason's 1.86.1).
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

  -- ruby-lsp + Standard addon already formats on save. Drop rubocop from conform's
  -- ruby formatter list so we don't run it twice (and so format-on-save isn't slow).
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      -- Empty list = conform falls through to LSP formatting (ruby-lsp + Standard).
      opts.formatters_by_ft.ruby = {}
      opts.formatters_by_ft.eruby = {}
      return opts
    end,
  },
}
