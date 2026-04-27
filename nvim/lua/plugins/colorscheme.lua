return {
  -- Tokyonight: use the darkest "night" variant, transparent so terminal bg shows through
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
      on_highlights = function(hl, c)
        -- bump contrast on common UI elements
        hl.LineNr = { fg = c.fg_dark }
        hl.CursorLineNr = { fg = c.orange, bold = true }
        hl.Comment = { fg = c.comment, italic = true }
        hl.Visual = { bg = c.bg_visual, bold = true }
      end,
    },
  },
  -- Tell LazyVim which colorscheme to use
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-night",
    },
  },
}
