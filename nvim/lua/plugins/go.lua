  return {
    -- richer Go tooling: struct tag editing, fillstruct, impl, etc.
    {
      "ray-x/go.nvim",
      dependencies = { "ray-x/guihua.lua", "neovim/nvim-lspconfig", "nvim-treesitter/nvim-treesitter" },
      ft = { "go", "gomod" },
      build = ':lua require("go.install").update_all_sync()',
      opts = {
        lsp_cfg = false,
        lsp_inlay_hints = { enable = false },
      },
    },
  }

