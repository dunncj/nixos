local telescope = require("telescope")

telescope.setup({})

-- Native fzf sorter, built by nix. Falls through quietly if unavailable.
pcall(telescope.load_extension, "fzf")

local builtin = require("telescope.builtin")

vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>gf", builtin.git_files, { desc = "Find git files" })
vim.keymap.set("n", "<leader>vh", builtin.help_tags, { desc = "Help tags" })

vim.keymap.set("n", "<leader>fg", function()
    builtin.grep_string({ search = vim.fn.expand("<cword>") })
end, { desc = "Grep word under cursor" })

vim.keymap.set("n", "<leader>pWs", function()
    builtin.grep_string({ search = vim.fn.expand("<cWORD>") })
end, { desc = "Grep WORD under cursor" })

vim.keymap.set("n", "<leader>ps", function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") })
end, { desc = "Grep prompt" })
