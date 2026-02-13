-- ~/.config/nvim/lua/plugins/harpoon.lua
-- Type: Plugin
-- Purpose: Harpoon 2: fast navigation between marked files with number-based
--          jump keys. Ideal for jumping between a small working set of files
--          without using full fuzzy search.
-- Docs: https://github.com/ThePrimeagen/harpoon/tree/harpoon2
-- Help: :help harpoon-toc

return {
	{
		"theprimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("harpoon"):setup()
		end,
		keys = {
			{
				"<leader>A",
				function()
					require("harpoon"):list():add()
				end,
				desc = "harpoon file",
			},
			{
				"<leader>a",
				function()
					local harpoon = require("harpoon")
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "harpoon quick menu",
			},
			{
				"<leader>1",
				function()
					require("harpoon"):list():select(1)
				end,
				desc = "harpoon to file 1",
			},
			{
				"<leader>2",
				function()
					require("harpoon"):list():select(2)
				end,
				desc = "harpoon to file 2",
			},
			{
				"<leader>3",
				function()
					require("harpoon"):list():select(3)
				end,
				desc = "harpoon to file 3",
			},
			{
				"<leader>4",
				function()
					require("harpoon"):list():select(4)
				end,
				desc = "harpoon to file 4",
			},
			{
				"<leader>5",
				function()
					require("harpoon"):list():select(5)
				end,
				desc = "harpoon to file 5",
			},
		},
	},
}
