-- A separate writing profile for ovim's Alacritty popup: NVIM_APPNAME=nvim-ovim.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Could not install lazy.nvim:\n" .. output)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.o.termguicolors = true
-- Use theme cursor colors in the terminal, including on empty cells.
vim.opt.guicursor = {
  "n-v-c-sm:block-Cursor/lCursor",
  "i-ci-ve:ver35-Cursor/lCursor",
  "r-cr-o:hor20-Cursor/lCursor",
  "a:blinkon0",
}
vim.o.number = true
vim.o.relativenumber = true
vim.o.wrap = true
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.laststatus = 0
vim.o.clipboard = "unnamedplus"
vim.o.mouse = "a"
vim.o.ignorecase = true
vim.o.smartcase = true
-- ovim owns the temporary file and watches it for changes.
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

for _, key in ipairs({ "j", "k" }) do
  vim.keymap.set({ "n", "x" }, key, function()
    return vim.v.count == 0 and "g" .. key or key
  end, { expr = true })
end
vim.keymap.set({ "n", "i", "x", "c" }, "<D-v>", function()
  vim.paste(vim.fn.getreg("+", 1, true), -1)
end)
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Grammar fixes / code actions" })
vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Show diagnostic" })

-- Use the same grammar server as the browser-writing profile, when installed.
if vim.fn.executable("harper-ls") == 1 then
  vim.lsp.config("harper_ls", {
    cmd = { "harper-ls", "--stdio" },
    filetypes = { "markdown", "text" },
  })
  vim.lsp.enable("harper_ls")
end
vim.diagnostic.config({ signs = false, virtual_text = false, float = { border = "rounded" } })

local function sync_terminal_colors()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if normal.fg and normal.bg then
    -- Alacritty checks the underlying cell's contrast even for a custom cursor.
    -- Blank cells inherit terminal defaults, so keep those in sync with Normal.
    vim.api.nvim_ui_send(("\27]10;#%06x\7\27]11;#%06x\7"):format(normal.fg, normal.bg))
  end
end

local function set_appearance(background)
  vim.o.background = background
  vim.cmd.colorscheme(background == "dark" and "github_dark_default" or "github_light_high_contrast")
  sync_terminal_colors()
end

local terminal_colors_group = vim.api.nvim_create_augroup("OvimTerminalColors", { clear = true })
vim.api.nvim_create_autocmd("UIEnter", {
  group = terminal_colors_group,
  callback = sync_terminal_colors,
})
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = terminal_colors_group,
  callback = function()
    vim.api.nvim_ui_send("\27]110\7\27]111\7")
  end,
})

require("lazy").setup({
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup({
        groups = {
          github_light_high_contrast = {
            Cursor = { fg = "#efe7d7", bg = "#332b22" },
            Visual = { fg = "#efe7d7" },
            VisualNOS = { link = "Visual" },
          },
        },
        specs = {
          github_light_high_contrast = {
            -- Warm paper backgrounds and softer text for the writing popup.
            bg0 = "#e5dccb", -- menus and floating windows
            bg1 = "#efe7d7", -- editor background
            bg2 = "#e8dfce", -- folds and secondary surfaces
            bg3 = "#e2d7c3", -- cursor line
            fg0 = "#827765", -- line numbers
            fg1 = "#4c463c", -- body text
            sel0 = "#6b5740", -- visual selection
            diag = { hint = "#7b7465" },
          },
        },
      })
      -- Set the initial theme before the first redraw; keep following it below.
      local appearance = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
      set_appearance(appearance:match("Dark") and "dark" or "light")
    end,
  },
  {
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    dependencies = { "github-theme" },
    opts = {
      update_interval = 3000,
      set_dark_mode = function()
        set_appearance("dark")
      end,
      set_light_mode = function()
        set_appearance("light")
      end,
    },
  },
}, {
  change_detection = { notify = false },
})
