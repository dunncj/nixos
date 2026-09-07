local ls = require("luasnip")

-- friendly-snippets ships VSCode-format snippets; nothing loads them on its own.
require("luasnip.loaders.from_vscode").lazy_load()

ls.filetype_extend("javascript", { "jsdoc" })

vim.keymap.set("i", "<C-s>e", function()
    ls.expand()
end, { silent = true, desc = "Expand snippet" })

vim.keymap.set({ "i", "s" }, "<C-s>;", function()
    ls.jump(1)
end, { silent = true, desc = "Next snippet slot" })

vim.keymap.set({ "i", "s" }, "<C-s>,", function()
    ls.jump(-1)
end, { silent = true, desc = "Previous snippet slot" })

vim.keymap.set({ "i", "s" }, "<C-E>", function()
    if ls.choice_active() then
        ls.change_choice(1)
    end
end, { silent = true, desc = "Cycle snippet choice" })
