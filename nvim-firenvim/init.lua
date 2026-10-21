-- Minimal config for editing browser textareas, separate from LazyVim: firenvim
-- (embedded frames) and nvim-ghost (GhostText into Neovide, via the `ghost` alias).
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
vim.o.number = true
vim.o.relativenumber = true

-- Harper grammar checker (brew install harper). Firenvim buffers are *.txt → filetype text.
vim.lsp.config("harper_ls", {
  cmd = { "harper-ls", "--stdio" },
  filetypes = { "markdown", "text" },
})
vim.lsp.enable("harper_ls")
-- Harper reports hints, and firenvim's canvas draws their undercurl as faint 1px dots.
vim.diagnostic.config({ virtual_text = true })

-- Never take over textareas on focus (leaves small inputs and other extensions alone):
-- open firenvim with the browser shortcut (chrome://extensions/shortcuts), `:q` to hand back.
vim.g.firenvim_config = { localSettings = { [".*"] = { takeover = "never" } } }

require("lazy").setup({
  { "glacambre/firenvim", build = ":call firenvim#install(0)" },
  {
    "subnut/nvim-ghost.nvim",
    -- Each firenvim frame is its own headless nvim; keep the GhostText server out of them.
    cond = not vim.g.started_by_firenvim,
    init = function()
      -- nvim-ghost fires `User <hostname>` for each new buffer, hence "*.*" (not lazy's
      -- `User LazyDone` etc.). Ghost buffers are unnamed and buftype=nofile, which
      -- vim.lsp.enable skips and Harper can't check (URI "file://"), and GhostText rarely
      -- sends a filetype. So name it (never written), default to text, start Harper here.
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("nvim_ghost_user_autocommands", { clear = false }),
        pattern = "*.*",
        callback = function(ev)
          if vim.api.nvim_buf_get_name(0) == "" then
            vim.api.nvim_buf_set_name(0, vim.fs.joinpath(vim.fn.tempname(), ev.match .. ".txt"))
          end
          if vim.bo.filetype == "" then
            vim.bo.filetype = "text"
          end
          vim.lsp.start(vim.lsp.config.harper_ls, { bufnr = 0 })
        end,
      })
    end,
  },
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    config = function()
      -- Not *_high_contrast: those color hints like body text, hiding Harper's virtual text.
      vim.cmd.colorscheme("github_dark_default")
    end,
  },
})
