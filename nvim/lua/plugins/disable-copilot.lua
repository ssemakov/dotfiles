-- Kill all forms of GitHub Copilot — neocodeium is the AI completion in use.
return {
  { "zbirenbaum/copilot.lua", enabled = false },
  { "zbirenbaum/copilot-cmp", enabled = false },
  { "giuxtaposition/blink-cmp-copilot", enabled = false },
  { "AndreM222/copilot-lualine", enabled = false },

  -- Strip "copilot" from mason-lspconfig auto-install list.
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(s)
        return s ~= "copilot" and s ~= "copilot-language-server"
      end, opts.ensure_installed or {})
    end,
  },
}
