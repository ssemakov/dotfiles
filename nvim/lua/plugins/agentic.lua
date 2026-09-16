local safe = vim.fn.expand("~/workspace/dotfiles/bin/safe")

local function global_tool_version(tool)
  local tool_versions = vim.fn.expand("~/.tool-versions")
  if vim.fn.filereadable(tool_versions) ~= 1 then
    return nil
  end

  for _, line in ipairs(vim.fn.readfile(tool_versions)) do
    local name, version = line:match("^(%S+)%s+(%S+)")
    if name == tool then
      return version
    end
  end
end

local node_version = global_tool_version("nodejs")

local function sandboxed(command, args, opts)
  opts = opts or {}
  local command_args = {}

  for _, dir in ipairs(opts.rw_dirs or {}) do
    command_args[#command_args + 1] = "--add-dir-rw"
    command_args[#command_args + 1] = vim.fn.expand(dir)
  end

  for _, feature in ipairs(opts.features or {}) do
    command_args[#command_args + 1] = "--enable=" .. feature
  end

  command_args[#command_args + 1] = "--"
  if node_version then
    command_args[#command_args + 1] = "ASDF_NODEJS_VERSION=" .. node_version
  end
  command_args[#command_args + 1] = command

  return {
    command = safe,
    args = vim.list_extend(command_args, args or {}),
  }
end

return {
  "carlos-algms/agentic.nvim",
  --- @type agentic.PartialUserConfig
  opts = {
    provider = "codex-acp",
    acp_providers = {
      ["claude-agent-acp"] = sandboxed("claude-agent-acp", nil, { features = { "clipboard" } }),
      ["claude-acp"] = sandboxed("claude-code-acp", nil, { features = { "clipboard" } }),
      ["gemini-acp"] = sandboxed("gemini", { "--acp" }),
      ["codex-acp"] = sandboxed("codex-acp", nil, {
        rw_dirs = { "~/.codex" },
        features = { "clipboard", "keychain" },
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
