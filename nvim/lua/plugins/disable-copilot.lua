-- Disable GitHub Copilot entirely.
-- Codeium (neocodeium) is kept — see neocodeium.lua.
return {
  -- Disable plugin specs
  { "folke/sidekick.nvim", enabled = false },
  { "zbirenbaum/copilot.lua", enabled = false },
  { "github/copilot.vim", enabled = false },
  { "CopilotC-Nvim/CopilotChat.nvim", enabled = false },
  { "giuxtaposition/blink-cmp-copilot", enabled = false },

  -- Strip copilot from the LSP server list so nvim-lspconfig doesn't start it
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.copilot = nil
      return opts
    end,
  },

  -- Stop mason-lspconfig from auto-installing copilot
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(s)
        return s ~= "copilot"
      end, opts.ensure_installed or {})
      opts.automatic_installation = false
      return opts
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(s)
        return s ~= "copilot"
      end, opts.ensure_installed or {})
      opts.automatic_installation = false
      return opts
    end,
  },
}
