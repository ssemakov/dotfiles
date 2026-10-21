-- Minimal config for firenvim (nvim in browser textareas), separate from LazyVim.
-- Runs as NVIM_APPNAME=nvim-firenvim; firenvim#install bakes that into its launcher,
-- so the build step below must only ever run from this config.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Frames are textarea-sized: no statusline, wrap prose at word boundaries.
vim.o.laststatus = 0
vim.o.wrap = true
vim.o.linebreak = true

-- Harper grammar checker (brew install harper). Firenvim buffers are *.txt → filetype text.
vim.lsp.config("harper_ls", {
  cmd = { "harper-ls", "--stdio" },
  filetypes = { "markdown", "text" },
})
vim.lsp.enable("harper_ls")
-- Harper reports hints, and firenvim's canvas draws their undercurl as faint 1px dots.
vim.diagnostic.config({ virtual_text = true })

require("lazy").setup({
  { "glacambre/firenvim", build = ":call firenvim#install(0)" },
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    config = function()
      vim.cmd.colorscheme("github_light_default")
    end,
  },
})
