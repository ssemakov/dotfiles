-- yetone/avante.nvim — Cursor-style AI sidebar. Default provider is `claude`,
-- which reads ANTHROPIC_API_KEY (or AVANTE_ANTHROPIC_API_KEY).
-- Its <leader>a* keys yield to ones claudecode/agentic already registered with lazy.
return {
  {
    "yetone/avante.nvim",
    build = "make", -- fetches prebuilt binaries
    event = "VeryLazy",
    version = false, -- tagged releases lag far behind main
    opts = {},
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      { "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = { file_types = { "markdown", "Avante" } },
    ft = { "Avante" },
  },
}
