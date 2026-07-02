-- ~/.config/nvim/lua/config/options.lua
-- Type: Config
-- Purpose: Sets global, window, and buffer-level Neovim options
-- Docs: https://neovim.io/doc/user/options.html
-- Help: :help vim.opt

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = "a"

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

local sysname = vim.loop.os_uname().sysname
local is_windows = sysname == "Windows_NT"
local is_macos = sysname == "Darwin"

-- Set clipboard
if is_windows then
	-- Requires win32yank.exe in PATH
	vim.g.clipboard = {
		name = "win32yank",
		copy = { ["+"] = "win32yank.exe -i", ["*"] = "win32yank.exe -i" },
		paste = { ["+"] = "win32yank.exe -o", ["*"] = "win32yank.exe -o" },
		cache_enabled = 0,
	}
elseif is_macos then
	-- Match the dotfiles clipboard policy: copy through the local clipper
	-- bridge when available, paste from the native macOS clipboard.
	local copy_command = vim.fn.executable("nc") == 1 and "nc localhost 8377" or "pbcopy"
	vim.g.clipboard = {
		name = copy_command:match("^nc") and "clipper" or "macOS",
		copy = { ["+"] = copy_command, ["*"] = copy_command },
		paste = { ["+"] = "pbpaste", ["*"] = "pbpaste" },
		cache_enabled = 0,
	}
else
	local osc52 = require("vim.ui.clipboard.osc52")
	vim.g.clipboard = {
		name = "OSC52 + xclip",
		copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
		paste = {
			-- Request UTF8_STRING: WSLg/Wayland owners don't offer the legacy
			-- STRING target, which caused "target STRING not available".
			-- WSLg has no primary-selection owner, so * aliases clipboard;
			-- reading unowned primary errored "target STRING not available".
			["+"] = "xclip -selection clipboard -out -t UTF8_STRING",
			["*"] = "xclip -selection clipboard -out -t UTF8_STRING",
		},
		cache_enabled = 1,
	}
end
-- Keep dd/yy/p on Neovim's internal registers so linewise survives (routing
-- through +/xclip drops the linewise flag -> charwise inline paste). Mirror
-- yanks (not deletes) to the system clipboard one-way so Windows still gets
-- every yank; p never reads + back, so the regtype stays intact.
vim.o.clipboard = ""
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankToSystemClipboard", { clear = true }),
	callback = function()
		local e = vim.v.event
		if e.operator == "y" then
			vim.fn.setreg("+", e.regcontents, e.regtype)
		end
	end,
})

-- Set shell
if is_windows then
	vim.opt.shell = "pwsh"
	vim.opt.shellcmdflag = "-NoLogo -NoProfile -Command"
elseif vim.fn.executable("/bin/zsh") == 1 then
	vim.opt.shell = "/bin/zsh"
end

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
-- vim.schedule(function()
-- 	vim.o.clipboard = "unnamedplus"
-- end)
-- vim.o.clipboard = "unnamedplus"
--
-- vim.o.shell = "/bin/zsh"
-- vim.o.shellcmdflag = "-c"

-- Height of the command window
vim.o.cmdwinheight = 30

-- Convert tabs to spaces
vim.o.expandtab = true
-- Amount to indent with << and >
vim.o.shiftwidth = 4
-- How many spaces are shown per <Tab>
vim.o.tabstop = 4
-- How many spaces are applied when pressing <Tab>
vim.o.softtabstop = 4
-- When enabled, the <Tab> key will indent by 'shiftwidth' if the cursor is in leading whitespace.
vim.o.smarttab = true
-- Do smart autoindenting when starting a new line.
vim.o.smartindent = true
-- Keep indentation from previous line
vim.o.autoindent = true

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Folding levels open by default
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
--
-- Keep signcolumn on by default
vim.o.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250

-- Make key combos feel snappy
vim.o.timeoutlen = 500
-- Prevents ESC delays in tmux and terminals
vim.o.ttimeoutlen = 0

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.o.inccommand = "split"

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- Save/restore session history (marks, registers, search, etc.)
-- Help: :help 'shada'
-- Docs: https://neovim.io/doc/user/options.html#'shada'
-- ! - save and restore global variables
-- '100 - store marks for the last 100 files
-- <100 - Save up to 100 lines of register contents
-- s20 - Save registers with up to 20 KiB of content
-- h - Disable search highlighting on startup
vim.opt.shada = "!,'100,<100,s20,h"
