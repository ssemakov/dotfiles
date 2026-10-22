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

-- System clipboard: y/p use it (LazyVim sets this; a bare config doesn't). firenvim
-- forwards Cmd+V as <D-v>, which nvim leaves unmapped; vim.paste handles every mode.
vim.o.clipboard = "unnamedplus"
vim.keymap.set({ "n", "i", "x", "c" }, "<D-v>", function()
  vim.paste(vim.fn.getreg("+", 1, true), -1)
end)

-- Harper grammar checker (brew install harper). Firenvim buffers are *.txt → filetype text.
vim.lsp.config("harper_ls", {
  cmd = { "harper-ls", "--stdio" },
  filetypes = { "markdown", "text" },
})
vim.lsp.enable("harper_ls")
-- Harper reports hints, and firenvim's canvas draws their undercurl as faint 1px dots.
-- No signs: with signcolumn=auto the "H" column pops in/out and shifts the text.
-- Harper's message is "Did you mean to spell `x` this way?"; its fixes only exist as code
-- actions. Fetch them per diagnostic and show `R: "<first replacement>"` instead.
local fixes = {} -- message+flagged text → first replacement, or false if Harper has none
local requested = {}
local function fix_key(d)
  local ok, text = pcall(vim.api.nvim_buf_get_text, d.bufnr, d.lnum, d.col, d.end_lnum, d.end_col, {})
  return d.message .. "\0" .. (ok and table.concat(text, "\n") or "")
end
vim.diagnostic.config({
  signs = false,
  virtual_text = {
    format = function(d)
      local fix = fixes[fix_key(d)]
      if fix == nil then
        return nil -- still fetching; hide rather than flash the long message
      end
      return fix and ('R: "' .. fix .. '"') or d.message
    end,
    -- Neovim prints only the last diagnostic's message per line (a textarea paragraph
    -- is one line); carry the others' messages in their prefixes so every fix shows.
    prefix = function(d, i, total)
      return i < total and ("■ " .. d.message .. " ") or "■"
    end,
  },
})
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = function(ev)
    local client = vim.lsp.get_clients({ bufnr = ev.buf, name = "harper_ls" })[1]
    if not client then
      return
    end
    for _, d in ipairs(ev.data.diagnostics) do
      local key = fix_key(d)
      if not requested[key] then
        requested[key] = true
        local params = {
          textDocument = { uri = vim.uri_from_bufnr(ev.buf) },
          range = d.user_data.lsp.range,
          context = { diagnostics = { d.user_data.lsp } },
        }
        client:request("textDocument/codeAction", params, function(_, actions)
          fixes[key] = false
          for _, a in ipairs(actions or {}) do
            local r = a.title:match("^Replace with: “(.*)”$")
            if r then
              fixes[key] = r
              break
            end
          end
          vim.diagnostic.show(d.namespace, ev.buf)
        end, ev.buf)
      end
    end
  end,
})

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
      -- Follow macOS appearance (the key only exists in dark mode). firenvim's canvas has no
      -- terminal to query, but every frame is a fresh nvim, so checking at startup is enough.
      if vim.fn.system("defaults read -g AppleInterfaceStyle"):match("Dark") then
        -- Not *_high_contrast: those color hints like body text, hiding Harper's virtual text.
        vim.cmd.colorscheme("github_dark_default")
      else
        require("github-theme").setup({
          -- High contrast maps hints to near-black fg.muted, so Harper's virtual text
          -- looks like real text. Dim hints to the theme's fg.subtle gray.
          specs = { github_light_high_contrast = { diag = { hint = "#66707b" } } },
        })
        vim.cmd.colorscheme("github_light_high_contrast")
      end
    end,
  },
})
