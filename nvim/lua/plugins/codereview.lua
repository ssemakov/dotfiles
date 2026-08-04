---@module "lazy"
---@type LazySpec
return {
  "afewyards/codereview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "CodeReview",
    "CodeReviewAI",
    "CodeReviewAIFile",
    "CodeReviewStart",
    "CodeReviewSubmit",
    "CodeReviewApprove",
    "CodeReviewOpen",
    "CodeReviewPipeline",
    "CodeReviewComments",
    "CodeReviewFiles",
    "CodeReviewToggleScroll",
    "CodeReviewCommits",
  },
  -- :CodeReview only lists the first API page (30 PRs) — plenary returns
  -- headers as an array, so the plugin's Link-header pagination never fires.
  init = function()
    vim.api.nvim_create_user_command("CodeReviewPR", function(o)
      local n = tonumber(o.args:match("%d+"))
      if not n then
        return vim.notify("CodeReviewPR: need a PR number", vim.log.levels.ERROR)
      end
      require("codereview.mr.detail").open({ id = n })
    end, { nargs = 1, desc = "Open a PR by number" })
  end,
  ---@module "codereview"
  ---@type codereview.Config
  opts = {
    -- token comes from $GITHUB_TOKEN (set in .zshrc from `gh auth token`)
    ai = {
      enabled = true,
      provider = "claude_cli",
      -- "info" floods a Rails diff with nits; suggestion+ is the actionable band
      review_level = "suggestion",
      -- default 500 skips whole controllers/models silently
      max_file_size = 1200,
      claude_cli = {
        cmd = "claude",
        model = nil,
        -- plugin default is "code-review"; no such agent is registered here
        agent = nil,
      },
      -- merged with the plugin's built-in lockfile/vendor/minified defaults
      skip_patterns = {
        "db/schema.rb",
        "db/structure.sql",
        "spec/fixtures/**",
        "spec/cassettes/**",
        "**/__snapshots__/**",
        "*.snap",
        "config/locales/**",
      },
    },
  },
}
