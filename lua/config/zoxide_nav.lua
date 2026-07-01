-- ~/.config/nvim/lua/config/zoxide_nav.lua
-- Purpose: FZF-Lua-powered Zoxide integration for find (files/grep) and mini.files.
--          Supports cross-platform preview fallback between Unix and PowerShell.
-- Requires: fzf-lua, zoxide, optionally bat, ls/head, or PowerShell

local M = {}

-- Extract path from zoxide query line
local function parse_zoxide_path(line)
	if line then
		return line:match("^%s*[%d%.]+%s+(.*)")
	end
	return nil
end

-- Platform-aware directory preview logic
local function preview_dir(dir)
	if not dir or vim.fn.isdirectory(dir) ~= 1 then
		return { "Not a valid directory or no directory selected." }
	end

	local sysname = vim.loop.os_uname().sysname
	local command

	if sysname == "Windows_NT" then
		if vim.fn.executable("ls") == 1 and vim.fn.executable("head") == 1 then
			command = "ls -F " .. vim.fn.fnameescape(dir) .. " | head -200"
		else
			-- Use PowerShell fallback
			return vim.fn.systemlist({
				"powershell",
				"-NoProfile",
				"-Command",
				"Get-ChildItem -Force -Name -LiteralPath '" .. dir .. "'",
			})
		end
	else
		command = "ls -F " .. vim.fn.fnameescape(dir) .. " | head -200"
	end

	local handle = io.popen(command)
	if handle then
		local output = handle:read("*a")
		handle:close()
		return vim.split(output, "\n", { plain = true, trimempty = true })
	else
		return { "Error: Could not list directory contents for preview." }
	end
end

-- Set the tab-local working directory (":tcd") so CWD-scoped pickers,
-- statusline, and LSP root heuristics all follow the picked dir.
local function tcd(dir)
	vim.cmd("tcd " .. vim.fn.fnameescape(dir))
end

-- FZF-Lua Zoxide picker with platform-aware preview.
-- actions_map: { ["default"] = fn(dir), ["ctrl-g"] = fn(dir), ... }
local function zoxide_fzf_picker(actions_map)
	local fzf = require("fzf-lua")

	local actions = {}
	for key, cb in pairs(actions_map) do
		actions[key] = function(selected)
			local dir = parse_zoxide_path(selected[1])
			if dir and vim.fn.isdirectory(dir) == 1 then
				cb(dir)
			else
				vim.notify("Invalid or no directory selected", vim.log.levels.WARN)
			end
		end
	end

	fzf.fzf_exec("zoxide query -ls", {
		prompt = "Zoxide> ",
		preview = {
			fn = function(lines)
				local dir = parse_zoxide_path(lines[1])
				return preview_dir(dir)
			end,
			layout = "right",
			width = "50%",
			wrap = false,
		},
		actions = actions,
	})
end

local function open_mini_files(dir)
	if pcall(require, "mini.files") then
		require("mini.files").open(dir)
	else
		vim.notify("mini.files not loaded", vim.log.levels.WARN)
	end
end

function M.setup()
	-- Zoxide → find. One frecency list, verb chosen inside the picker.
	-- Every action :tcd's the tab first so downstream CWD-scoped maps follow.
	vim.keymap.set("n", "<leader>zf", function()
		zoxide_fzf_picker({
			["default"] = function(dir)
				tcd(dir)
				require("fzf-lua").files()
			end,
			["ctrl-g"] = function(dir)
				tcd(dir)
				require("fzf-lua").live_grep()
			end,
			["ctrl-e"] = open_mini_files,
			["ctrl-d"] = function(dir)
				tcd(dir)
				vim.notify("cwd → " .. dir)
			end,
		})
	end, { desc = "Zoxide: tcd + find (enter=files, C-g=grep, C-e=mini, C-d=cd)" })

	-- Zoxide → mini.files (browse only, no tcd)
	vim.keymap.set("n", "<leader>ze", function()
		zoxide_fzf_picker({ ["default"] = open_mini_files })
	end, { desc = "Zoxide: Open in mini.files" })
end

return M
