local safe = vim.fn.expand("~/workspace/dotfiles/bin/safe")

local function sandboxed(command, args)
  return {
    command = safe,
    args = vim.list_extend({ "--", command }, args or {}),
  }
end

return {
  "carlos-algms/agentic.nvim",
  --- @type agentic.PartialUserConfig
  opts = {
    provider = "claude-agent-acp",
    acp_providers = {
      ["claude-agent-acp"] = sandboxed("claude-agent-acp"),
      ["claude-acp"] = sandboxed("claude-code-acp"),
      ["gemini-acp"] = sandboxed("gemini", { "--acp" }),
      ["codex-acp"] = sandboxed("codex-acp"),
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
