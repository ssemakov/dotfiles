-- toppair/peek.nvim — live markdown preview rendered in a webview window.
-- Requires Deno (brew install deno); the build step compiles the webview app.
return {
  {
    "toppair/peek.nvim",
    event = { "VeryLazy" },
    build = "deno task --quiet build:fast",
    config = function()
      require("peek").setup({
        app = "webview", -- render in a dedicated webview window, not the browser
      })
      vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
    end,
    keys = {
      {
        "<leader>mp",
        function()
          local peek = require("peek")
          if peek.is_open() then
            peek.close()
          else
            peek.open()
          end
        end,
        desc = "Markdown Preview (peek.nvim)",
        ft = "markdown",
      },
    },
  },
}
