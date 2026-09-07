-- Plugins themselves are installed by nix (see ../../../../home.nix), so
-- there is no lazy.nvim bootstrap here and no lazy-lock.json to drift. Each
-- module below is just the setup call for one plugin.
require("turbo.plugins.colors")
require("turbo.plugins.treesitter")
require("turbo.plugins.autoclose")
require("turbo.plugins.telescope")
require("turbo.plugins.snippets")
require("turbo.plugins.completion")
require("turbo.plugins.lsp")
