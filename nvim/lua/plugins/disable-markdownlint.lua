-- Disable markdownlint (markdownlint-cli2) that LazyVim's markdown extra enables
-- via nvim-lint, while keeping the rest of markdown language support.
return {
  "mfussenegger/nvim-lint",
  optional = true,
  opts = function(_, opts)
    opts.linters_by_ft = opts.linters_by_ft or {}
    opts.linters_by_ft.markdown = {}
  end,
}
