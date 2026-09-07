-- Bracket/quote autoclosing.
require("autoclose").setup()

-- Auto close and rename HTML/JSX tag pairs. (In the old repo these two were
-- in files named after each other - autoclose.lua held autotag and vice
-- versa. Same plugins, correct names.)
require("nvim-ts-autotag").setup({
    opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
    },
})
