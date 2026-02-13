-- ~/.config/nvim/lua/config/keymaps.lua
-- Type: Config
-- Purpose: Defines general custom keybindings (some keybinds will be in specific configs)
-- Docs: https://neovim.io/doc/user/map.html
-- Help: :help vim.keymap.set

-- Pull in zoxide_nav
require("config.zoxide_nav").setup()

-- Do nothing with a naked s
vim.keymap.set("n", "s", "<Nop>", { desc = "Unassigned (was s: substitute character, juse use cl)" })
vim.keymap.set("n", "S", "<Nop>", { desc = "Unassigned (was S: substitute line, juse use cc)" })

-- Open the package manager.
vim.keymap.set("n", "<leader>L", "<cmd>Lazy<cr>", { desc = "[L]azy" })
vim.keymap.set("n", "<leader>Ls", "<cmd>Lazy sync<cr>", { desc = "[L]azy sync" })

-- Buffer stuff
vim.keymap.set("n", "<leader>k", "<cmd>bnext<cr>", { desc = "[k] buffer next" })
vim.keymap.set("n", "<leader>j", "<cmd>bprev<cr>", { desc = "[j] buffer prev" })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "<Leader>vs", "<Cmd>normal! <C-v>$<CR>", { desc = "Visual block to end of line" })

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics [Q]uickfix list" })
vim.keymap.set("n", "gl", function()
	vim.diagnostic.open_float()
end, { desc = "Open diagnostics at cursor in floating window" })

--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })
vim.keymap.set("n", "<Leader>wv", "<C-W>t<C-W>H<C-W><C-W>", { desc = "Split [w]indow horizontal → [v]ertical" })
vim.keymap.set("n", "<Leader>wh", "<C-W>t<C-W>K<C-W><C-W>", { desc = "Split [w]indow vertical → [h]orizontal" })

vim.keymap.set("n", "DS", [[:%s/[ <Tab>]//g<CR>]], { desc = "Delete all spaces and tabs" })
vim.keymap.set("n", "DR", [[:g/^$/d<CR>]], { desc = "Delete empty lines" })
vim.keymap.set("n", "DE", [[:g/^[\t ]*$/d<CR>]], { desc = "Delete empty or whitespace-only lines" })
vim.keymap.set("n", "DW", [[:%s/^[\t ]*$//g<CR>]], { desc = "Clear lines with only whitespace" })

vim.keymap.set("n", "DT", [[o<C-R>=strftime("%a %m-%d-%Y:")<CR><Esc>]], { desc = "Insert current date" })
vim.keymap.set("n", "UT", [[o<C-R>=strftime("%a %b %d %T %Z %Y")<CR><Esc>]], { desc = "Insert current UTC time" })
vim.keymap.set(
	"n",
	"CT",
	[[o<C-R>=strftime("%a %b %d @ %T %Z (%z) %Y")<CR><Esc>]],
	{ desc = "Insert local time with UTC offset" }
)

-- Keeping the cursor centered.
-- vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll downwards' })
-- vim.keymap.set('n', '<C-u>', '<C-u>z', { desc = 'Scroll upwards' })
-- vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next result' })
-- vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous result' })

-- Open URL with gX
vim.keymap.set("n", "gX", function()
	local uri = vim.fn.expand("<cfile>")
	if uri ~= "" then
		vim.ui.open(uri)
	end
end, { desc = "Open URI under cursor" })
