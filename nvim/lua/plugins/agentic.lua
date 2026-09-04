return {
  "carlos-algms/agentic.nvim",
  --- @type agentic.PartialUserConfig
  opts = { provider = "claude-agent-acp" }, -- ~/.local/bin symlink; asdf shim breaks in repos pinning another node
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
