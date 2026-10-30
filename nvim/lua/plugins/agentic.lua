local sandboxed = require("config.safehouse").acp

-- safehouse only auto-selects its claude-code profile for a command named `claude`
local claude = sandboxed("claude-agent-acp", nil, {
  rw_dirs = { "~/.claude", "~/.claude.json" },
  features = { "clipboard", "keychain" },
})

return {
  "carlos-algms/agentic.nvim",
  --- @type agentic.PartialUserConfig
  opts = {
    provider = "codex-acp",
    acp_providers = {
      ["claude-agent-acp"] = claude,
      ["claude-acp"] = claude, -- plugin default points at the renamed claude-code-acp binary
      ["gemini-acp"] = sandboxed("gemini", { "--acp" }),
      ["codex-acp"] = sandboxed("codex-acp", nil, {
        rw_dirs = { "~/.codex" },
        features = { "clipboard", "keychain" },
        -- codex runs every command under sandbox-exec, which macOS refuses to nest
        -- inside safehouse; full access drops that inner sandbox and its approvals
        env = { INITIAL_AGENT_MODE = "agent-full-access" },
      }),
      ["opencode-acp"] = sandboxed("opencode", { "acp" }),
      ["cursor-acp"] = sandboxed("cursor-agent", { "acp" }),
      ["copilot-acp"] = sandboxed("copilot", { "--acp", "--stdio" }),
      ["auggie-acp"] = sandboxed("auggie", { "--acp" }),
      ["mistral-vibe-acp"] = sandboxed("vibe-acp"),
      ["cline-acp"] = sandboxed("cline", { "--acp" }),
      ["goose-acp"] = sandboxed("goose", { "acp" }),
      ["kiro-acp"] = sandboxed("kiro-cli", { "acp" }),
      ["pi-acp"] = sandboxed("pi-acp"),
    },
  },
  keys = {
    {
      "<C-\\>",
      function()
        require("agentic").toggle()
      end,
      mode = { "n", "v", "i" },
      desc = "Toggle Agentic Chat",
    },
    {
      "<leader>ac",
      function()
        require("agentic").add_selection_or_file_to_context()
      end,
      mode = { "n", "v" },
      desc = "Add file/selection to Agentic context",
    },
    {
      "<leader>an",
      function()
        require("agentic").new_session()
      end,
      mode = { "n", "v" },
      desc = "New Agentic session",
    },
  },
}
