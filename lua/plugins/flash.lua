-- ~/.config/nvim/lua/plugins/flash.lua
-- Type: Plugin
-- Purpose: Flash enhances f/F/t/T motions and operators with Treesitter and
--          remote navigation support for faster, more intuitive movement.
-- Docs: https://github.com/folke/flash.nvim
-- Help: :help flash.nvim

-- NOTE:  Flash config for more full functionality, but I found it to be too
--        too distracting and we already have Treesitter functionality.

-- return {
-- 	"folke/flash.nvim",
-- 	event = "VeryLazy",
-- 	opts = {},
--   keys = {
--     { "s",  mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
--     { "r",  mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
--     { "S",  mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
--     { "<c-s>", mode = "c", function() require("flash").toggle() end, desc = "Toggle Flash Search" },
--   },
-- }

--        Remote flash mode though is cool, because it spans windows.
--        This configuration just enables Remote flash mode, showing
--        the label for the jump after the match.
return {
	"folke/flash.nvim",
	event = "VeryLazy",
	opts = {
		modes = {
			-- disable char-based motions and search mode
			char = { enabled = false },
			search = { enabled = false },
			-- enable only Remote Flash
			remote = {
				enabled = true,
				config = {}, -- use default
			},
		},
		jump = {
			autojump = false,
		},
		label = {
			after = true,
			before = false,
			current = false,
		},
	},
	keys = {
		{
			"<leader>r",
			function()
				require("flash").remote()
			end,
			desc = "Remote Flash",
			mode = { "n" },
		},
	},
}
