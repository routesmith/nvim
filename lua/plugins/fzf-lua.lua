-- ~/.config/nvim/lua/plugins/fzf-lua.lua
-- Type: Plugin
-- Purpose: FZF-powered fuzzy finder UI written in Lua with previews and themes.
-- Docs: https://github.com/ibhagwan/fzf-lua
-- Help: :help fzf-lua.txt

-- NOTE: https://lazy.folke.io/spec/lazy_loading#%EF%B8%8F-lazy-key-mappings

-- find ≡ search: one <leader>f prefix. Filename-match and content-match are the
-- same intent, so they live in one picker with an in-place flip (C-g files→grep,
-- C-f grep→files) instead of two prefixes to remember. opts.last_query carries
-- the typed text across the flip when fzf-lua provides it.
-- ponytail: query carry-over degrades to "" on older fzf-lua; flip still works.
local function to_grep(_, opts)
	require("fzf-lua").live_grep({ query = opts and opts.last_query or "" })
end

local function to_files(_, opts)
	require("fzf-lua").files({ query = opts and opts.last_query or "" })
end

return {
	"ibhagwan/fzf-lua",
	-- optional for icon support
	-- dependencies = { "nvim-tree/nvim-web-devicons" },
	-- or if using mini.icons/mini.nvim
	dependencies = { "echasnovski/mini.icons" },
	grep = { rg_glob = true },
	cmd = { "FzfLua" },
	opts = {},
	keys = {
		{
			"<leader>ff",
			function()
				require("fzf-lua").files({ actions = { ["ctrl-g"] = to_grep } })
			end,
			desc = "[f]ind [f]iles in cwd (C-g → grep)",
		},
		{
			"<leader>fg",
			function()
				require("fzf-lua").live_grep({ actions = { ["ctrl-f"] = to_files } })
			end,
			desc = "[f]ind by [g]rep in cwd (C-f → files)",
		},
		{
			"<leader>fr",
			function()
				require("fzf-lua").oldfiles()
			end,
			desc = "[f]ind [r]ecent files (oldfiles())",
		},
		{
			"<leader>fh",
			function()
				require("fzf-lua").helptags()
			end,
			desc = "[f]ind [h]elp (helptags())",
		},
		{
			"<leader>fk",
			function()
				require("fzf-lua").keymaps()
			end,
			desc = "[f]ind [k]eymaps (keymaps())",
		},
		{
			"<leader>fd",
			function()
				require("fzf-lua").diagnostics_document()
			end,
			desc = "[f]ind [d]iagnostics (diagnostics_document())",
		},
		{
			"<leader>fb",
			function()
				require("fzf-lua").builtin()
			end,
			desc = "[f]zf [b]uiltin pickers (builtin())",
		},
		{
			"<leader>fn",
			function()
				require("fzf-lua").live_grep({ cwd = vim.fn.stdpath("config") })
			end,
			desc = "[f]ind in [n]eovim config (live_grep())",
		},
		{
			"<leader>fp",
			function()
				require("fzf-lua").live_grep({ cwd = vim.fn.stdpath("data") .. "/lazy/" })
			end,
			desc = "[f]ind in neovim [p]lugins (live_grep())",
		},
		{
			"<leader>fw",
			function()
				require("fzf-lua").grep_cword()
			end,
			desc = "[f]ind [w]ord under cursor - stops at punctuation / whitespace (grep_cword())",
		},
		{
			"<leader>fW",
			function()
				require("fzf-lua").grep_cWORD()
			end,
			desc = "[f]ind [W]ord under cursor - longer token including punctuation / whitespace (grep_cWORD())",
		},
		{
			"<leader><leader>",
			function()
				require("fzf-lua").buffers()
			end,
			desc = "[ ] Find existing buffers",
		},
		{
			"<leader>/",
			function()
				require("fzf-lua").lgrep_curbuf()
			end,
			desc = "[/] Search the current buffer (lgrep_curbuf())",
		},
	},
}
