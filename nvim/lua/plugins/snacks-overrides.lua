-- Override LazyVim Snacks defaults that fight with Diffview / fail at startup.
return {
  {
    "folke/snacks.nvim",
    keys = {
      -- Disable LazyVim's Snacks Picker bindings that we replace with Diffview.
      { "<leader>gd", false },
      { "<leader>gD", false },
      { "<leader>gh", false },
      { "<leader>gH", false },
    },
    opts = {
      -- The dashboard's git widget runs `git diff --diff-filter=u …` on startup;
      -- it errors when the cwd is not a git repo or when run with no args. We
      -- already use Diffview for git, so skip the dashboard auto-run.
      dashboard = {
        sections = {
          { section = "header" },
          { section = "keys",   gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },
}
