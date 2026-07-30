-- tpope/vim-abolish — case coercion on the word under cursor.
-- crc camelCase, crs snake_case, crm MixedCase, cru UPPER_CASE, cr- dash-case, cr. dot.case.
-- Load eagerly: abolish maps `cr` as an <expr> mapping using getchar(), which
-- breaks under lazy.nvim's keys/event replay. A native mapping set at startup
-- reads the real keypress and shadows flash.nvim's operator-pending `r`.
return {
  { "tpope/vim-abolish", lazy = false },
}
