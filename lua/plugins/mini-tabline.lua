-- ~/.config/nvim/lua/plugins/mini-tabline.lua
-- Type: Plugin
-- Purpose: Lightweight, customizable tabline that shows listed buffers.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-tabline.md
-- Help: :help mini.tabline

return {
	"echasnovski/mini.tabline",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.tabline").setup({
			show_icons = true,
			set_vim_settings = false, -- avoids setting `showtabline` and `tabline`
		})
	end,
}
