return {
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "marilari88/neotest-vitest" },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(
        opts.adapters,
        require("neotest-vitest")({
          is_test_file = function(file_path)
            if not file_path then
              return false
            end
            return file_path:match("%.vitest%.[jt]sx?$")
              or file_path:match("%.test%.[jt]sx?$")
              or file_path:match("%.spec%.[jt]sx?$")
          end,
        })
      )
    end,
  },
}
