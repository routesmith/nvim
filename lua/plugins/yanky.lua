-- ~/.config/nvim/lua/plugins/yanky.lua
-- Type: Plugin
-- Purpose: Enhanced yank/put/delete with history ring and smart paste
-- Docs: https://github.com/gbprod/yanky.nvim
-- Help: :help yanky.nvim

return {
	"gbprod/yanky.nvim",
	version = false,
	event = "VeryLazy",
	opts = {
		ring = {
			history_length = 100,
			storage = "shada", -- or "memory"
		},
		system_clipboard = {
			sync_with_ring = true,
		},
		highlight = {
			on_put = true,
			on_yank = true,
		},
		picker = {
			select = {
				action = nil,
			},
		},
	},
	keys = {
		{ "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put yanked text after cursor" },
		{ "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put yanked text before cursor" },
		{
			"gp",
			"<Plug>(YankyGPutAfter)",
			mode = { "n", "x" },
			desc = "Put yanked text after cursor and leave the cursor after",
		},
		{
			"gP",
			"<Plug>(YankyGPutBefore)",
			mode = { "n", "x" },
			desc = "Put yanked text before cursor and leave the cursor after",
		},
		{ "=p", "<Plug>(YankyPutAfterLinewise)", desc = "Put yanked text in line below" },
		{ "=P", "<Plug>(YankyPutBeforeLinewise)", desc = "Put yanked text in line above" },
		{ "[y", "<Plug>(YankyCycleForward)", desc = "Cycle forward through yank history" },
		{ "]y", "<Plug>(YankyCycleBackward)", desc = "Cycle backward through yank history" },
		{ "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "[y]anky yank" },

		-- paste from yank history via snacks
		{
			"<leader>fy",
			function()
				Snacks.picker.yanky()
			end,
			mode = { "n", "x" },
			desc = "[f]ind [y]ank history (snacks)",
		},
	},
}
