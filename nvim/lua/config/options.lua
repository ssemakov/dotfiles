-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim fills diff filler lines with "╱"; github-theme leaves DiffDelete's fg
-- unset, so those stripes render in full-brightness Normal fg. Blank them out.
vim.opt.fillchars:append({ diff = " " })

-- Disable unused legacy language providers (silences :checkhealth warnings, faster startup)
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
