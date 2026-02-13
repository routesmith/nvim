-- ~/.config/nvim/lua/plugins/mini-bufremove.lua
-- Type: Plugin
-- Purpose: Buffer removing (unshow, delete, wipeout), which saves window layout.
--          Which buffer to show in window(s) after its current buffer is
--          removed is decided by the algorithm:
--
--          1. If alternate buffer is listed, use it.
--          2. If previous listed buffer is different, use it.
--          3. Otherwise create a scratch one with nvim_create_buf(true,true) and
--             use it.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-bufremove.md
-- Help: :help mini.bufremove

return {
	"echasnovski/mini.bufremove",
	version = "*",
	keys = {
		{
			"<leader>bd",
			function()
				require("mini.bufremove").delete(0, false)
			end,
			desc = "[b]uffer [d]elete",
		},
		{
			"<leader>bD",
			function()
				require("mini.bufremove").delete(0, true)
			end,
			desc = "[b]uffer [D]elete FORCE",
		},
	},
	opts = {},
}
