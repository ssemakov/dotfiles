-- Tool execution stays in the ACP process launched through bin/safe.
return {
  {
    "yetone/avante.nvim",
    build = "make", -- fetches prebuilt binaries
    event = "VeryLazy",
    version = false, -- tagged releases lag far behind main
    opts = function()
      local safehouse = require("config.safehouse")
      return {
        provider = "claude-code",
        acp_providers = {
          ["claude-code"] = safehouse.acp("claude-agent-acp", nil, {
            rw_dirs = { "~/.claude", "~/.claude.json" },
            features = { "clipboard", "keychain" },
          }),
          codex = safehouse.acp("codex-acp", nil, {
            rw_dirs = { "~/.codex" },
            features = { "clipboard", "keychain" },
            env = { INITIAL_AGENT_MODE = "agent-full-access" },
          }),
          ["gemini-cli"] = safehouse.acp("gemini", { "--acp" }),
          goose = safehouse.acp("goose", { "acp" }),
          opencode = safehouse.acp("opencode", { "acp" }),
          ["kimi-cli"] = safehouse.acp("kimi", { "acp" }),
        },
        behaviour = { auto_approve_tool_permissions = false },
      }
    end,
    config = function(_, opts)
      require("config.safehouse").guard_avante_acp()
      require("avante").setup(opts)
      local config = require("avante.config")
      local providers = {}
      for name in pairs(config.providers) do
        providers[name] = { disable_tools = true }
      end
      -- Saved native-provider selections must not restore unsandboxed tool use.
      config.override({ provider = opts.provider, providers = providers })
    end,
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
