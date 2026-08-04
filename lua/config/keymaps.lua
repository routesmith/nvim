-- ~/.config/nvim/lua/config/keymaps.lua
-- Type: Config
-- Purpose: Defines general custom keybindings (some keybinds will be in specific configs)
-- Docs: https://neovim.io/doc/user/map.html
-- Help: :help vim.keymap.set

-- Pull in focused reusable modules.
require("config.zoxide_nav").setup()
require("config.artifact_thread").setup()
local buffer_reference = require("config.buffer_reference")

-- Naked `S` is unbound in normal mode (use `cc` instead). `s` is left as
-- Vim's default substitute-char so it can serve as the prefix for
-- mini.surround (`sa`/`sd`/`sr`/`sf`/`sF`/`sh`); a longer prefix like
-- `gs*` is fragile under timeoutlen because of the extra waiting gap
-- between `g` and `s`. If you prefer change-letter, use `cl` instead of
-- `s`.
vim.keymap.set("n", "S", "<Nop>", { desc = "Unassigned (was S: substitute line, use cc)" })

-- Open the package manager.
vim.keymap.set("n", "<leader>L", "<cmd>Lazy<cr>", { desc = "[L]azy" })
vim.keymap.set("n", "<leader>Ls", "<cmd>Lazy sync<cr>", { desc = "[L]azy sync" })

-- Buffer stuff
vim.keymap.set("n", "<leader>k", "<cmd>bnext<cr>", { desc = "[k] buffer next" })
vim.keymap.set("n", "<leader>j", "<cmd>bprev<cr>", { desc = "[j] buffer prev" })

local function copy_buffer_reference(representation)
	local reference, err = buffer_reference.get({ representation = representation })
	if not reference then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	vim.fn.setreg("+", reference, "c")
	vim.notify(("copied %s buffer reference"):format(representation))
end

local capture_root = vim.fn.fnamemodify(vim.fn.stdpath("state"), ":h") .. "/capture"
local uv = vim.uv or vim.loop

local function capture(line1, line2)
	vim.fn.mkdir(capture_root, "p")
	local slug = vim.fn.fnamemodify(vim.fn.getcwd(), ":t"):lower()
		:gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
	local base = ("%s/%s-%s"):format(
		capture_root,
		os.date("%Y%m%dT%H%M%S"),
		slug ~= "" and slug or "capture"
	)
	local file, n = base .. ".md", 2
	while uv.fs_stat(file) do
		file = ("%s-%d.md"):format(base, n)
		n = n + 1
	end

	local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
	if vim.fn.writefile(lines, file, "s") ~= 0 then
		vim.notify("capture failed → " .. file, vim.log.levels.ERROR)
		return
	end
	vim.notify("captured → " .. file)
end

local function promote_as(name)
	if name == nil or name == "" then
		return
	end
	if name == "." or name == ".." or name:find("[/\\\\]") then
		vim.notify("promotion requires a filename without path separators", vim.log.levels.ERROR)
		return
	end
	if vim.fn.fnamemodify(name, ":e") == "" then
		name = name .. ".md"
	end

	local file = capture_root .. "/" .. name
	if uv.fs_lstat(file) then
		vim.notify("promotion refused; destination exists → " .. file, vim.log.levels.ERROR)
		return
	end
	if vim.fn.mkdir(capture_root, "p") == 0 then
		vim.notify("promotion failed; could not create capture directory", vim.log.levels.ERROR)
		return
	end

	local ok, err = pcall(vim.cmd, "saveas " .. vim.fn.fnameescape(file))
	if not ok then
		vim.notify("promotion failed → " .. err, vim.log.levels.ERROR)
	end
end

local function promote_manually()
	vim.ui.input({ prompt = "Promote capture as: " }, promote_as)
end

-- Grammar is advisory. When the current buffer is a recognized artifact, offer
-- candidate names continuing its thread; otherwise this is exactly the prompt
-- it has always been. Manual entry is always one keystroke away, and any name
-- typed there is accepted.
local MANUAL = "Enter manually…"
local NEW_SUBJECT = "New subject…"

-- Intent-first. The ordinary path is new buffer → write → promote, where there
-- is no artifact for grammar to read. So ask what this should become, then let
-- grammar complete that intent: which thread it joins, and at what sequence.
local function promote_from_intent()
	local artifact_thread = require("config.artifact_thread")
	local entries = artifact_thread.corpus()
	local kinds = artifact_thread.kinds(entries)
	if #kinds == 0 then
		return promote_manually()
	end

	vim.ui.select(vim.list_extend(kinds, { MANUAL }), { prompt = "Promote as what?" }, function(kind)
		if kind == nil then
			return
		end
		if kind == MANUAL then
			return promote_manually()
		end

		local names = artifact_thread.thread_candidates(entries, kind)
		vim.ui.select(vim.list_extend(names, { NEW_SUBJECT }), {
			prompt = kind .. " — which thread?",
		}, function(choice)
			if choice == nil then
				return
			end
			if choice == NEW_SUBJECT then
				-- Prefilled up to the subject, so only the subject is typed.
				return vim.ui.input({
					prompt = "Promote capture as: ",
					default = ("%s--01--"):format(kind),
				}, promote_as)
			end
			promote_as(choice)
		end)
	end)
end

local function promote()
	local candidates = require("config.artifact_thread").promotion_candidates(
		vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
	)
	if #candidates == 0 then
		return promote_from_intent()
	end

	local items = vim.list_extend(vim.deepcopy(candidates), { MANUAL })
	vim.ui.select(items, { prompt = "Promote as:" }, function(choice)
		if choice == nil then
			return
		end
		if choice == MANUAL then
			return promote_manually()
		end
		promote_as(choice)
	end)
end

local function find_capture()
	if vim.fn.isdirectory(capture_root) == 0 then
		vim.notify("no captures: capture directory does not exist")
		return
	end
	if #vim.fn.readdir(capture_root) == 0 then
		vim.notify("no captures: capture directory is empty")
		return
	end
	require("fzf-lua").files({ cwd = capture_root })
end

vim.api.nvim_create_user_command("Capture", function(args)
	capture(args.line1, args.line2)
end, { range = "%", desc = "Capture buffer or selected lines" })

vim.api.nvim_create_user_command("Promote", promote, { desc = "Promote current buffer into capture inbox" })

vim.keymap.set("n", "<leader>bh", function()
	copy_buffer_reference("home")
end, { desc = "[b]uffer [h]ome reference" })
vim.keymap.set("n", "<leader>ba", function()
	copy_buffer_reference("absolute")
end, { desc = "[b]uffer [a]bsolute reference" })
vim.keymap.set("n", "<leader>bb", function()
	copy_buffer_reference("filename")
end, { desc = "[b]uffer [b]ilename reference" })
vim.keymap.set("n", "<leader>bn", "<cmd>enew<cr>", { desc = "[b]uffer [n]ew" })
vim.keymap.set("n", "<leader>bc", "<cmd>Capture<cr>", { desc = "[b]uffer [c]apture" })
vim.keymap.set("x", "<leader>bc", ":Capture<cr>", { desc = "[b]uffer [c]apture selection" })
vim.keymap.set("n", "<leader>bw", "<cmd>write<cr>", { desc = "[b]uffer [w]rite" })
vim.keymap.set("n", "<leader>bp", "<cmd>Promote<cr>", { desc = "[b]uffer [p]romote to capture" })
vim.keymap.set("n", "<leader>bf", find_capture, { desc = "[b]uffer [f]ind captures" })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("n", "<Leader>vs", "<Cmd>normal! <C-v>$<CR>", { desc = "Visual block to end of line" })

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics [Q]uickfix list" })
vim.keymap.set("n", "gl", function()
	vim.diagnostic.open_float()
end, { desc = "Open diagnostics at cursor in floating window" })

vim.keymap.set("n", "DS", [[:%s/[ <Tab>]//g<CR>]], { desc = "Delete all spaces and tabs" })
vim.keymap.set("n", "DR", [[:g/^$/d<CR>]], { desc = "Delete empty lines" })
vim.keymap.set("n", "DE", [[:g/^[\t ]*$/d<CR>]], { desc = "Delete empty or whitespace-only lines" })
vim.keymap.set("n", "DW", [[:%s/^[\t ]*$//g<CR>]], { desc = "Clear lines with only whitespace" })

vim.keymap.set("n", "DT", [[o<C-R>=strftime("%a %m-%d-%Y:")<CR><Esc>]], { desc = "Insert current date" })
vim.keymap.set("n", "UT", [[o<C-R>=strftime("%a %b %d %T %Z %Y")<CR><Esc>]], { desc = "Insert current UTC time" })
vim.keymap.set("n", "CT", [[o<C-R>=strftime("%a %b %d @ %T %Z (%z) %Y")<CR><Esc>]], { desc = "Insert local time with UTC offset" })

-- j/k move by screen line (works correctly with soft-wrapped lines).
-- Operators like `dj` / visual `Vj` then also operate on screen lines,
-- which is the consistent end-state.
vim.keymap.set({ "n", "v", "o" }, "j", "gj")
vim.keymap.set({ "n", "v", "o" }, "k", "gk")

-- System clipboard (the + register) on a sane key, since clipboard="" keeps
-- normal y/p on the internal registers. <leader>p/P paste from Windows,
-- <leader>y yanks to Windows. So nobody ever types "+p again.
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "[p]aste from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { desc = "[P]aste before from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "[y]ank to system clipboard" })

-- Strip HTML/XML tags from the current visual selection in one shot.
-- `:` from visual mode auto-inserts the `'<,'>` range, so we just append
-- the substitution. inccommand shows the live preview while you type.
vim.keymap.set("x", "<leader>st", ":s/<[^>]*>//g<CR>", { desc = "[s]trip [t]ags from selection" })

-- Split selection by character
-- Usage: select text, press S, then the delimiter (e.g., 's' for space, ',' for comma)
-- Pressing Enter will prompt for a custom multi-character delimiter.
vim.keymap.set("x", "S", function()
	local char = vim.fn.getcharstr()
	local pattern = char
	if char == "s" or char == " " then
		pattern = [[\s\+]]
	elseif char == "c" then
		pattern = [[,]]
	elseif char == "." then
		pattern = [[\.]]
	elseif char == "\r" or char == "\n" then
		vim.ui.input({ prompt = "Split by: " }, function(input)
			if input == nil or input == "" then
				return
			end
			pcall(vim.cmd, string.format("'<,'>s/%s/\\r/g", input))
		end)
		return
	end
	pcall(vim.cmd, string.format("'<,'>s/%s/\\r/g", pattern))
	vim.cmd("nohlsearch")
end, { desc = "Split selection by character" })

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

-- Wispr Flow dictation into Neovim.
-- Wispr auto-pastes by sending Ctrl+V, which Neovim treats as insert-literal
-- (i_CTRL-V) -> a stray "^" and no text. Rebind INSERT-mode <C-v> to pull the
-- last transcript straight from Wispr's SQLite and insert it at the cursor.
-- The literal-insert you'd lose is still on <C-q> by default (:help i_CTRL-Q),
-- and normal-mode <C-v> (visual block) is untouched. Mirror of the zsh ^V fix.
vim.keymap.set("i", "<C-v>", function()
	local out = vim.fn.system({ vim.fn.expand("~/.zsh/bin/wispr-last"), "--no-copy", "--raw" })
	out = (out or ""):gsub("[\r\n]+$", "")
	if out == "" then
		return
	end
	-- suppress blink for this dictation insert (its `enabled` in blink-cmp.lua
	-- reads this flag) so the menu doesn't flicker. Clear after blink's debounce
	-- window would have elapsed; hide() is belt-and-suspenders.
	vim.g.wispr_dictating = true
	vim.api.nvim_paste(out, true, -1)
	vim.defer_fn(function()
		vim.g.wispr_dictating = false
		pcall(function()
			require("blink.cmp").hide()
		end)
	end, 300)
end, { desc = "Wispr: insert last transcript" })
