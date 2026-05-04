return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        gopls = {
          on_init = function(client)
            vim.lsp.semantic_tokens.enable(false, { client_id = client.id })
          end,
          root_dir = function(bufnr, on_dir)
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name:match("^%w[%w+.-]*://") then
              return
            end

            local root = vim.fs.root(bufnr, "go.work")
              or vim.fs.root(bufnr, "go.mod")
              or vim.fs.root(bufnr, ".git")
            if root then
              on_dir(root)
            end
          end,
          settings = {
            gopls = {
              semanticTokens = false,
            },
          },
        },
      },
    },
  },
}
