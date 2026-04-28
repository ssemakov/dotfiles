return {
  "monkoose/neocodeium",
  event = "VeryLazy",
  config = function()
    local neocodeium = require("neocodeium")
    neocodeium.setup()

    vim.keymap.set("i", "<A-f>", neocodeium.accept, { desc = "Codeium: accept suggestion" })
    vim.keymap.set("i", "<A-w>", neocodeium.accept_word, { desc = "Codeium: accept word" })
    vim.keymap.set("i", "<A-l>", neocodeium.accept_line, { desc = "Codeium: accept line" })
    vim.keymap.set("i", "<A-]>", neocodeium.cycle_or_complete, { desc = "Codeium: next suggestion" })
    vim.keymap.set("i", "<A-[>", function()
      neocodeium.cycle_or_complete(-1)
    end, { desc = "Codeium: prev suggestion" })
    vim.keymap.set("i", "<A-c>", neocodeium.clear, { desc = "Codeium: clear" })
  end,
}
