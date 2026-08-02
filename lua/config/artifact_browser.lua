-- ~/.config/nvim/lua/config/artifact_browser.lua
-- Stateless FZF convenience layer over Markdown files in Capture.

local M = {}
local uv = vim.uv or vim.loop
local proposal_kinds = { "proposal-amendment", "proposal-review", "proposal-brief", "proposal" }

local function normalize(path)
	return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", "")
end

local function basename(path)
	return vim.fn.fnamemodify(path, ":t")
end

local function dirname(path)
	return vim.fn.fnamemodify(path, ":h")
end

function M.root()
	return vim.fn.fnamemodify(vim.fn.stdpath("state"), ":h") .. "/capture"
end

local function in_capture(path)
	local root = normalize(M.root()) .. "/"
	return normalize(path):sub(1, #root) == root
end

local function markdown_files()
	local files = {}
	if vim.fn.isdirectory(M.root()) == 0 then
		return files
	end
	for name, kind in vim.fs.dir(M.root(), { depth = math.huge }) do
		if (kind == "file" or kind == "link") and name:lower():match("%.md$") then
			files[#files + 1] = normalize(M.root() .. "/" .. name)
		end
	end
	return files
end

function M.classify(path)
	local name = basename(path)
	if not name:lower():match("%.md$") then
		return nil
	end
	local body = name:sub(1, -4)
	for _, kind in ipairs(proposal_kinds) do
		local pattern_kind = kind:gsub("(%W)", "%%%1")
		local patterns = {
			"^" .. pattern_kind .. "%-%-(%d+)%-%-(.+)$",
			"^" .. pattern_kind .. "%-(%d+)%-%-(.+)$",
		}
		for _, pattern in ipairs(patterns) do
			local sequence, subject = body:match(pattern)
			if sequence then
				return { kind = kind, sequence = tonumber(sequence), width = #sequence, subject = subject }
			end
		end
		local subject = body:match("^" .. pattern_kind .. "%-%-(.+)$")
		if subject then
			return { kind = kind, subject = subject }
		end
	end
	local timestamp, subject = body:match("^(%d%d%d%d%d%d%d%dT%d%d%d%d%d%d)%-(.+)$")
	if timestamp then
		return { kind = "capture", timestamp = timestamp, subject = subject }
	end
	return nil
end

local function relatives(source, kind)
	local source_info = M.classify(source)
	if not source_info or not source_info.subject then
		return {}
	end
	local matches = {}
	for _, path in ipairs(markdown_files()) do
		local info = M.classify(path)
		if info and info.kind == kind and info.subject == source_info.subject then
			matches[#matches + 1] = { path = path, info = info }
		end
	end
	table.sort(matches, function(a, b)
		return (a.info.sequence or -1) > (b.info.sequence or -1)
	end)
	return matches
end

function M.related_path(source, relation)
	source = normalize(source)
	local info = M.classify(source)
	if not info then
		return nil, "filename is not a recognized artifact"
	end

	if relation == "brief" or relation == "proposal" then
		local candidates = relatives(source, relation == "brief" and "proposal-brief" or "proposal")
		for _, candidate in ipairs(candidates) do
			if info.sequence and candidate.info.sequence == info.sequence then
				return candidate.path
			end
		end
		if candidates[1] then
			return candidates[1].path
		end
		return nil, "no related " .. relation .. " found"
	end

	if info.kind ~= "proposal-review" or not info.sequence then
		return nil, "select a numbered proposal review"
	end
	local best
	for _, candidate in ipairs(relatives(source, "proposal-review")) do
		local sequence = candidate.info.sequence
		if relation == "previous-review" and sequence and sequence < info.sequence then
			if not best or sequence > best.info.sequence then
				best = candidate
			end
		elseif relation == "next-review" and sequence and sequence > info.sequence then
			if not best or sequence < best.info.sequence then
				best = candidate
			end
		end
	end
	if best then
		return best.path
	end
	return nil, "no " .. relation:gsub("%-", " ") .. " found"
end

function M.next_review_name(source)
	source = normalize(source)
	local info = M.classify(source)
	if not info or not info.subject or not info.kind:find("proposal", 1, true) then
		return nil, "select a recognized proposal artifact"
	end
	local highest, width = 0, 2
	for _, candidate in ipairs(relatives(source, "proposal-review")) do
		if candidate.info.sequence then
			highest = math.max(highest, candidate.info.sequence)
			width = math.max(width, candidate.info.width or 0)
		end
	end
	return ("proposal-review--%0" .. width .. "d--%s.md"):format(highest + 1, info.subject)
end

local function valid_name(name)
	name = vim.trim(name or "")
	if name == "" then
		return nil, "filename is empty"
	end
	if name == "." or name == ".." or name:find("[/\\]") then
		return nil, "use a filename without path separators"
	end
	if vim.fn.fnamemodify(name, ":e") == "" then
		name = name .. ".md"
	end
	if not name:lower():match("%.md$") then
		return nil, "Capture artifacts must remain Markdown (.md)"
	end
	return name
end

function M.rename(source, requested_name)
	source = normalize(source)
	if not in_capture(source) or not uv.fs_lstat(source) then
		return nil, "source does not exist in Capture"
	end
	local name, err = valid_name(requested_name)
	if not name then
		return nil, err
	end
	local destination = normalize(dirname(source) .. "/" .. name)
	if destination == source then
		return source
	end
	if uv.fs_lstat(destination) then
		return nil, "destination already exists"
	end
	local ok, rename_err = uv.fs_rename(source, destination)
	if not ok then
		return nil, rename_err
	end
	local bufnr = vim.fn.bufnr(source)
	if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
		pcall(vim.api.nvim_buf_set_name, bufnr, destination)
	end
	return destination
end

function M.delete(source)
	source = normalize(source)
	if not in_capture(source) or not uv.fs_lstat(source) then
		return nil, "source does not exist in Capture"
	end
	local bufnr = vim.fn.bufnr(source)
	if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified then
		return nil, "loaded buffer has unsaved changes"
	end
	local ok, err = uv.fs_unlink(source)
	if not ok then
		return nil, err
	end
	if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end
	return true
end

function M.reference(source)
	source = normalize(source)
	if not in_capture(source) then
		return nil, "source is outside Capture"
	end
	return vim.fn.fnamemodify(source, ":~")
end

function M.copy_reference(source)
	local reference, err = M.reference(source)
	if not reference then
		return nil, err
	end
	vim.fn.setreg("+", reference, "c")
	return reference
end

function M.duplicate_next_review(source)
	source = normalize(source)
	local stat = uv.fs_lstat(source)
	if not in_capture(source) or not stat or stat.type ~= "file" then
		return nil, "source must be an ordinary Markdown file in Capture"
	end
	local name, err = M.next_review_name(source)
	if not name then
		return nil, err
	end
	local destination = normalize(dirname(source) .. "/" .. name)
	if uv.fs_lstat(destination) then
		return nil, "destination already exists"
	end
	local ok, copy_err = uv.fs_copyfile(source, destination)
	return ok and destination or nil, copy_err
end

local function selected_path(selected, opts)
	if not selected or not selected[1] then
		return nil, "no artifact selected"
	end
	local entry = require("fzf-lua.path").entry_to_file(selected[1], opts)
	local path = entry.path or entry.bufname
	if not path then
		return nil, "could not resolve selected artifact"
	end
	if not vim.startswith(path, "/") then
		path = (opts.cwd or M.root()) .. "/" .. path
	end
	path = normalize(path)
	return in_capture(path) and path or nil, "selected path is outside Capture"
end

local function with_selected(selected, opts, callback)
	local path, err = selected_path(selected, opts)
	if path then
		callback(path)
	else
		vim.notify(err, vim.log.levels.ERROR)
	end
end

local function open_related(path, relation)
	local related, err = M.related_path(path, relation)
	if related then
		vim.cmd.edit(vim.fn.fnameescape(related))
	else
		vim.notify(err, vim.log.levels.ERROR)
	end
end

local function relation_action(relation)
	return function(selected, opts)
		with_selected(selected, opts, function(path)
			open_related(path, relation)
		end)
	end
end

local function rename_action(selected, opts)
	with_selected(selected, opts, function(path)
		vim.ui.input({ prompt = "Rename artifact: ", default = basename(path) }, function(name)
			if name == nil then
				return
			end
			local destination, err = M.rename(path, name)
			if not destination then
				return vim.notify("rename refused: " .. err, vim.log.levels.ERROR)
			end
			vim.notify("renamed → " .. destination)
			M.open()
		end)
	end)
end

local function delete_action(selected, opts)
	with_selected(selected, opts, function(path)
		vim.ui.select({ "Delete", "Cancel" }, { prompt = "Delete " .. basename(path) .. "?" }, function(choice)
			if choice ~= "Delete" then
				return
			end
			local deleted, err = M.delete(path)
			if not deleted then
				return vim.notify("delete refused: " .. err, vim.log.levels.ERROR)
			end
			vim.notify("deleted → " .. path)
			M.open()
		end)
	end)
end

local function copy_action(selected, opts)
	with_selected(selected, opts, function(path)
		local reference, err = M.copy_reference(path)
		if reference then
			vim.notify("copied reference → " .. reference)
		else
			vim.notify(err, vim.log.levels.ERROR)
		end
	end)
end

local function duplicate_action(selected, opts)
	with_selected(selected, opts, function(path)
		local destination, err = M.duplicate_next_review(path)
		if not destination then
			return vim.notify("duplicate refused: " .. err, vim.log.levels.ERROR)
		end
		vim.cmd.edit(vim.fn.fnameescape(destination))
		vim.notify("duplicated → " .. destination)
	end)
end

local function suggest_action(selected, opts)
	with_selected(selected, opts, function(path)
		local name, err = M.next_review_name(path)
		if not name then
			return vim.notify(err, vim.log.levels.ERROR)
		end
		vim.fn.setreg("+", name, "c")
		vim.notify("copied next review filename → " .. name)
	end)
end

function M.open()
	local root = M.root()
	if vim.fn.isdirectory(root) == 0 then
		return vim.notify("no captures: directory does not exist")
	end
	if #markdown_files() == 0 then
		return vim.notify("no captures: no Markdown files")
	end
	local fzf, actions = require("fzf-lua"), require("fzf-lua.actions")
	fzf.files({
		cwd = root,
		cmd = "rg --files --hidden --glob '*.md'",
		file_icons = false,
		prompt = "Artifacts> ",
		fzf_opts = {
			["--no-multi"] = true,
			["--header"] = "enter open │ ctrl-/ preview │ ctrl-r rename │ alt-d delete │ ctrl-y copy ref │ alt-b/o brief/proposal │ alt-k/j prev/next review │ alt-n duplicate │ alt-g next name",
		},
		actions = {
			["enter"] = actions.file_edit,
			["ctrl-r"] = rename_action,
			["alt-d"] = delete_action,
			["ctrl-y"] = { fn = copy_action, reload = true },
			["alt-b"] = relation_action("brief"),
			["alt-o"] = relation_action("proposal"),
			["alt-k"] = relation_action("previous-review"),
			["alt-j"] = relation_action("next-review"),
			["alt-n"] = duplicate_action,
			["alt-g"] = { fn = suggest_action, reload = true },
		},
	})
end

function M.setup()
	vim.api.nvim_create_user_command("ArtifactBrowser", M.open, {
		desc = "Browse Capture Markdown artifacts",
		force = true,
	})
end

return M
