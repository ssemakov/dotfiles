return {
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    main = "github-theme", -- lua module name differs from the repo name
    opts = {
      options = {
        transparent = true,
        styles = { comments = "italic" },
      },
      specs = {
        -- Theme default blends diff colors at 15% over #0d1117, and uses a light
        -- grey (fg.subtle) for DiffText. Dial the blend down; raise to taste.
        all = {
          diff = {
            add = "#101f1b", -- 10% #2ea043
            change = "#1e1c16", -- 10% #bb8009
            delete = "#25171c", -- 10% #f85149
            text = "#413213", -- 30% #bb8009 (was a bright grey)
          },
        },
      },
    },
  },
  -- Tell LazyVim which colorscheme to use
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "github_dark_default",
    },
  },
}
