vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Deliberately not smartindent: treesitter supplies indentexpr per language
-- (see plugins/treesitter.lua) and the two fight over comments and closing
-- brackets. This matches the commented-out line in the old config.

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"

vim.opt.updatetime = 50

-- The old config set `syntax = "off"` to hand highlighting entirely to
-- treesitter. That relied on auto_install pulling any missing parser, which
-- cannot work here - the parser set is fixed by nix. Leaving syntax on means
-- a filetype with no parser still gets regex highlighting instead of none.
