vim.g.mapleader = " "

vim.keymap.set("n", "<leader>t", vim.cmd.Ex, { desc = "File explorer" })

-- Splits
vim.keymap.set("n", "<leader>vs", "<C-w>v", { desc = "Split vertical" })
vim.keymap.set("n", "<leader>hs", "<C-w>s", { desc = "Split horizontal" })

-- Window navigation. The old config sent these to ZellijNavigate*; agartha
-- runs tmux, where panes are already on <prefix> h/j/k/l, so these stay as
-- plain window moves and the two do not overlap.
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Explicit system-clipboard yanks, kept from the old config.
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to clipboard" })
vim.keymap.set("n", "<leader>Y", [["+Y]], { desc = "Yank line to clipboard" })

-- Paste over a selection without the replaced text clobbering the register.
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste, keep register" })

-- Write/quit
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Write" })
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<leader>x", "<cmd>x<CR>", { desc = "Write and quit" })
