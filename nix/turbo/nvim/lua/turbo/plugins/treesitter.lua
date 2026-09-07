-- nixpkgs ships the main-branch rewrite of nvim-treesitter, which dropped
-- `nvim-treesitter.configs`. There is no ensure_installed/auto_install any
-- more: the parser set is whatever home.nix builds in, and highlighting is
-- started per buffer.
--
-- Worth knowing: the previous config listed parsers but never called setup at
-- all, so treesitter highlighting was never actually on.
require("nvim-treesitter").setup({})

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("turbo_treesitter", { clear = true }),
    callback = function(args)
        local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
        if not lang or not pcall(vim.treesitter.start, args.buf, lang) then
            return
        end

        -- Only take over indenting once the parser actually started.
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
})
