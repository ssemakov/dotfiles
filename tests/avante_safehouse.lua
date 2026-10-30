-- Run with a clean Neovim: nvim --headless -u NONE -i NONE -l tests/avante_safehouse.lua
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root .. "/nvim")
for _, path in ipairs(vim.fn.glob(vim.fn.stdpath("data") .. "/lazy/*", false, true)) do
  vim.opt.rtp:append(path)
end

local safehouse = require("config.safehouse")
local spec = dofile(root .. "/nvim/lua/plugins/avante.lua")[1]
local opts = spec.opts()
local config = require("avante.config")

-- Exercise real config merging with a previously saved native API provider.
config.get_last_used_model = function()
  return nil, "claude", true
end
package.loaded.avante = { setup = config.setup }
spec.config(nil, opts)
assert(config.provider == "claude-code")
for _, provider in pairs(config.providers) do
  assert(provider.disable_tools == true, "Native API provider retained host tools")
end
for name, provider in pairs(opts.acp_providers) do
  assert(provider.command == safehouse.command, name)
  assert(provider.env.HOME == vim.env.HOME, "ACP must supply HOME to bin/safe")
  assert(vim.tbl_contains(provider.args, "--"), "Agent arguments must follow --")
end

local ACPClient = require("avante.libs.acp_client")
local host_calls = 0
local host_handler = function()
  host_calls = host_calls + 1
end
local provider = vim.deepcopy(opts.acp_providers["claude-code"])
provider.handlers = {
  on_read_file = host_handler,
  on_write_file = host_handler,
  on_session_update = host_handler,
}
local client = ACPClient:new(provider)
assert(not client.capabilities.fs.readTextFile)
assert(not client.capabilities.fs.writeTextFile)
assert(not client.capabilities.terminal)
assert(provider.handlers.on_read_file == host_handler, "Guard mutated caller-owned config")
assert(client.config.handlers.on_session_update == host_handler, "Guard removed normal ACP updates")

local rejected = {}
client._send_error = function(_, id, _, code)
  assert(code == ACPClient.ERROR_CODES.METHOD_NOT_FOUND)
  rejected[id] = true
end
client:_handle_read_text_file(1, { sessionId = "test", path = "/outside/workspace" })
client:_handle_write_text_file(2, { sessionId = "test", path = "/outside/workspace", content = "must not write" })
assert(rejected[1] and rejected[2] and host_calls == 0, "ACP request reached host file handlers")

assert(not pcall(ACPClient.new, ACPClient, { command = "claude-agent-acp", args = {} }))
assert(not pcall(ACPClient.new, ACPClient, { command = safehouse.command, transport_type = "tcp", args = {} }))
safehouse.guard_avante_acp() -- Reloading configuration must not stack wrappers.
local second = ACPClient:new(provider)
assert(not second.capabilities.fs.readTextFile)

print("PASS: Avante wraps ACP providers, rejects host file requests and unwrapped transports, disables native tools")
