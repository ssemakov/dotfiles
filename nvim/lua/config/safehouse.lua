local M = {}

M.command = vim.fn.expand("~/workspace/dotfiles/bin/safe")

function M.acp(command, args, opts)
  opts = opts or {}
  local command_args = {}

  for _, dir in ipairs(opts.rw_dirs or {}) do
    vim.list_extend(command_args, { "--add-dir-rw", vim.fn.expand(dir) })
  end
  for _, feature in ipairs(opts.features or {}) do
    command_args[#command_args + 1] = "--enable=" .. feature
  end
  command_args[#command_args + 1] = "--"

  local tool_versions = vim.fn.expand("~/.tool-versions")
  if vim.fn.filereadable(tool_versions) == 1 then
    for _, line in ipairs(vim.fn.readfile(tool_versions)) do
      local version = line:match("^nodejs%s+(%S+)")
      if version then
        command_args[#command_args + 1] = "ASDF_NODEJS_VERSION=" .. version
        break
      end
    end
  end
  for name, value in pairs(opts.env or {}) do
    command_args[#command_args + 1] = name .. "=" .. value
  end
  command_args[#command_args + 1] = command

  return {
    command = M.command,
    args = vim.list_extend(command_args, args or {}),
    -- Avante does not inherit HOME when spawning an ACP provider.
    env = { HOME = vim.env.HOME, TMPDIR = vim.env.TMPDIR },
  }
end

local avante_guard_installed = false

function M.guard_avante_acp()
  if avante_guard_installed then
    return
  end
  local ACPClient = require("avante.libs.acp_client")
  local new = assert(ACPClient.new, "Avante ACP constructor changed; review the Safehouse integration")

  -- Avante supplies host-side file callbacks even for sandboxed ACP providers.
  -- Remove them before capability negotiation and request dispatch.
  ACPClient.new = function(self, config)
    assert(config.command == M.command, "Avante ACP providers must launch through bin/safe")
    assert(not config.transport_type or config.transport_type == "stdio", "Avante ACP requires sandboxed stdio")
    config = vim.deepcopy(config)
    config.handlers = config.handlers or {}
    config.handlers.on_read_file = nil
    config.handlers.on_write_file = nil
    local client = new(self, config)
    assert(
      client.capabilities.fs.readTextFile == false
        and client.capabilities.fs.writeTextFile == false
        and client.capabilities.terminal == false,
      "Avante enabled host tools; review the Safehouse integration"
    )
    return client
  end
  avante_guard_installed = true
end

return M
