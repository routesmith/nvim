-- ~/.config/nvim/lua/plugins/fzf-lua.lua
-- Type: Plugin
-- Purpose: FZF-powered fuzzy finder UI written in Lua with previews and themes.
-- Docs: https://github.com/ibhagwan/fzf-lua
-- Help: :help fzf-lua.txt

-- NOTE: https://lazy.folke.io/spec/lazy_loading#%EF%B8%8F-lazy-key-mappings

-- Directory / file excludes to reuse for functions (define new ones if need be)
local excludes = {
	".git",
	".svn",
	".hg",
	"node_modules",
	".npm",
	".yarn",
	"venv",
	".venv",
	"__pycache__",
	".cargo",
	"target",
	".m2",
	".gradle",
	".bundle",
	"vendor",
	".cache",
	".local/share",
	".local/state",
	".var",
	".mozilla",
	".config/google-chrome",
	".thunderbird",
	".vscode",
	".config/Code",
	".Trash",
	".thumbnails",
	".next",
	".nuxt",
	".parcel-cache",
	".idea",
	".terraform",
	".direnv",
	".zcompdump*",
	".oh-my-zsh",
	".viminfo",
	".zsh_history",
}

-- Build rg --glob exclusions
local glob_excludes = {}
for _, pattern in ipairs(excludes) do
	table.insert(glob_excludes, "--glob")
	table.insert(glob_excludes, "!" .. pattern)
end

local function grep_dotfiles()
	local home = vim.fn.expand("~")

	require("fzf-lua").live_grep({
		cwd = home,
		hidden = true,
		silent = true,
		rg_opts = table.concat(glob_excludes, " "),
	})
end

local function choose_root_and_grep()
	local fd_root = vim.fn.expand("~") -- start scanning from home

	-- Assemble excludes into CLI format
	local exclude_strs = {}
	for _, entry in ipairs(excludes) do
		table.insert(exclude_strs, string.format("--exclude '%s'", entry))
	end

	-- Build command string with scan root
	local fd_cmd =
		string.format("fd --type d --hidden --follow --color never %s . '%s'", table.concat(exclude_strs, " "), fd_root)

	require("fzf-lua").fzf_exec(fd_cmd, {
		prompt = "Choose directory to grep:",
		actions = {
			["default"] = function(selected)
				require("fzf-lua").live_grep({
					cwd = selected[1],
					silent = true,
				})
			end,
		},
	})
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
			"<leader>fd",
			function()
				require("fzf-lua").diagnostics_document()
			end,
			desc = "[f]ind [d]iagnostics (diagnostics_document())",
		},
		{
			"<leader>ff",
			function()
				require("fzf-lua").files()
			end,
			desc = "[f]ind [f]iles in CWD. (files())",
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
			"<leader>fr",
			function()
				require("fzf-lua").oldfiles()
			end,
			desc = "[f]ind [r]ecent files (oldfiles())",
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
			"<leader>sf",
			function()
				require("fzf-lua").live_grep()
			end,
			desc = "[s]earch [f]iles in CWD. (live_grep())",
		},
		{
			"<leader>sn",
			function()
				require("fzf-lua").live_grep({ cwd = vim.fn.stdpath("config") })
			end,
			desc = "[s]earch [n]eovim configs. (live_grep())",
		},
		{
			"<leader>sp",
			function()
				require("fzf-lua").live_grep({
					cwd = vim.fn.stdpath("data") .. "/lazy/",
				})
			end,
			desc = "[s]earch neovim [p]lugins (live_grep())",
		},
		{
			"<leader>sB",
			function()
				require("fzf-lua").builtin()
			end,
			desc = "[s]earch [B]uiltin (builtin())",
		},
		{
			"<leader>sd",
			function()
				grep_dotfiles()
			end,
			desc = "[s]earch [d]otfiles (~) (live_grep)",
		},
		{
			"<leader>sr",
			function()
				choose_root_and_grep()
			end,
			desc = "[s]elect [r]oot and grep (live_grep)",
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
