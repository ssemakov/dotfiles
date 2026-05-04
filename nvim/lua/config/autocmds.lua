-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function local_is_file_uri(uri)
  return type(uri) == "string" and uri:match("^file://") ~= nil
end

local buf_attach_client = vim.lsp.buf_attach_client
vim.lsp.buf_attach_client = function(bufnr, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if client and client.name == "gopls" then
    local uri = vim.uri_from_bufnr(bufnr)
    if not local_is_file_uri(uri) then
      return false
    end
  end

  return buf_attach_client(bufnr, client_id)
end

local function local_disable_lsp_features_for_non_file_buffer(bufnr)
  local uri = vim.uri_from_bufnr(bufnr)
  if local_is_file_uri(uri) then
    return
  end

  if vim.lsp.semantic_tokens then
    pcall(vim.lsp.semantic_tokens.enable, false, { bufnr = bufnr })
  end
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "FileType" }, {
  group = vim.api.nvim_create_augroup("local_non_file_buffer_lsp_features", { clear = true }),
  callback = function(event)
    local_disable_lsp_features_for_non_file_buffer(event.buf)
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("local_gopls_file_scheme_only", { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= "gopls" then
      return
    end

    local_disable_lsp_features_for_non_file_buffer(event.buf)

    local uri = vim.uri_from_bufnr(event.buf)
    if not local_is_file_uri(uri) then
      vim.lsp.buf_detach_client(event.buf, client.id)
    end
  end,
})
