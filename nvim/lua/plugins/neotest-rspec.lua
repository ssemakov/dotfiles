return {
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "olimorris/neotest-rspec" },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, require("neotest-rspec"))
    end,
  },
}
