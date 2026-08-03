-- ~/.config/nvim/lua/config/forge_projection.lua
-- Read-only, transient projection of the governed Forge corpus.

local M = {}
local runtime = { opts = {}, model = nil }

local function trim(value)
	return vim.trim(value or "")
end

local function normalize(path)
	if not path or path == "" then
		return nil
	end
	return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", "")
end

local function strip_quotes(value)
	value = trim(value)
	local first, last = value:sub(1, 1), value:sub(-1)
	if #value >= 2 and ((first == '"' and last == '"') or (first == "'" and last == "'")) then
		return value:sub(2, -2)
	end
	return value
end

local function parse_value(raw)
	raw = trim(raw)
	if raw == "" then
		return nil
	end
	local inside = raw:match("^%[(.*)%]$")
	if inside then
		local values = {}
		for value in inside:gmatch("[^,]+") do
			values[#values + 1] = strip_quotes(value)
		end
		return values
	end
	return strip_quotes(raw)
end

local function parse_frontmatter(lines)
	local fields = {}
	if lines[1] ~= "---" then
		return fields, 1
	end

	local current_key
	for index = 2, #lines do
		local line = lines[index]
		if line == "---" then
			return fields, index + 1
		end

		local key, raw = line:match("^([%w_]+):%s*(.*)$")
		if key then
			fields[key] = parse_value(raw)
			current_key = key
		else
			local item = line:match("^%s+%-%s+(.+)$")
			if item and current_key then
				if type(fields[current_key]) ~= "table" then
					fields[current_key] = {}
				end
				fields[current_key][#fields[current_key] + 1] = strip_quotes(item)
			end
		end
	end
	return fields, 1
end

local function as_list(value)
	if type(value) == "table" then
		return value
	end
	if value == nil or value == "" or value == "none" then
		return {}
	end
	return { value }
end

local function first_paragraph(lines, start_index)
	local paragraph = {}
	for index = start_index, #lines do
		local line = lines[index]
		if line:match("^##%s+") then
			if #paragraph > 0 then
				break
			end
		elseif trim(line) == "" then
			if #paragraph > 0 then
				break
			end
		elseif not line:match("^#") and not line:match("^>") then
			paragraph[#paragraph + 1] = trim(line)
		end
	end
	return table.concat(paragraph, " ")
end

local function section_excerpt(lines, heading)
	for index, line in ipairs(lines) do
		if line:lower() == "## " .. heading:lower() then
			return first_paragraph(lines, index + 1)
		end
	end
	return ""
end

local function compact(value, limit)
	value = trim((value or ""):gsub("[%s\t\r\n]+", " "))
	if limit and #value > limit then
		return value:sub(1, limit - 1) .. "…"
	end
	return value
end

local function location_for(semantic)
	local relative = semantic:gsub("^Forge/", "")
	if relative:match("^archive/") then
		return "archive"
	end
	if relative:match("^reference/") then
		return "reference"
	end
	return "workbench"
end

local function expected_location(workflow_status)
	if workflow_status == "live" or workflow_status == "active" or workflow_status == "blocked" then
		return "workbench"
	end
	if workflow_status == "reference" then
		return "reference"
	end
	if workflow_status == "complete" or workflow_status == "superseded" then
		return "archive"
	end
	return nil
end

local function parse_note(root, relative)
	local path = normalize(root .. "/" .. relative)
	local lines = vim.fn.readfile(path)
	local fields, body_start = parse_frontmatter(lines)
	local title
	local headings = {}
	for index = body_start, #lines do
		local line = lines[index]
		if not title then
			title = line:match("^#%s+(.+)$")
		end
		local heading = line:match("^##%s+(.+)$")
		if heading then
			headings[#headings + 1] = heading
		end
	end

	local semantic = "Forge/" .. relative:gsub("\\", "/")
	local summary = section_excerpt(lines, "Summary")
	local status_excerpt = section_excerpt(lines, "Status")
	if summary == "" then
		summary = first_paragraph(lines, body_start)
	end

	return {
		path = path,
		semantic = semantic,
		basename = vim.fs.basename(path),
		location = location_for(semantic),
		fields = fields,
		lines = lines,
		body_start = body_start,
		body = table.concat(lines, "\n"),
		title = title or vim.fs.basename(path):gsub("%.md$", ""),
		summary = summary,
		status_excerpt = status_excerpt,
		headings = headings,
		legacy = not fields.workflow_status or not fields.doc_type,
		state_issues = {},
		state_memberships = {},
		outgoing = {},
	}
end

local function markdown_files(root)
	local files = {}
	if vim.fn.isdirectory(root) == 0 then
		return files
	end
	for name, kind in vim.fs.dir(root, { depth = math.huge }) do
		if (kind == "file" or kind == "link") and name:lower():match("%.md$") then
			files[#files + 1] = name:gsub("\\", "/")
		end
	end
	table.sort(files)
	return files
end

local function clean_target(target)
	target = trim(target):gsub("^`", ""):gsub("`$", "")
	target = target:gsub("^%[%[", ""):gsub("%]%]$", "")
	target = target:match("^([^|]+)") or target
	target = target:match("^([^#]+)") or target
	target = trim(target):gsub("^%./", "")
	return target
end

local function is_cross_surface(target)
	return target:match("^wiki/")
		or target:match("^AI/")
		or target:match("^Self/")
		or target:match("^lab/")
		or target:match("^git/")
		or target:match("^~[/\\]")
		or target:match("^%a:[/\\]")
		or target:match("^/")
end

function M.resolve(model, raw_target)
	local target = clean_target(raw_target)
	local result = { source = target }
	if target == "" then
		result.state = "missing"
		return result
	end

	if is_cross_surface(target) then
		result.state = "cross-surface"
		return result
	end

	local had_forge_prefix = target:match("^Forge/") ~= nil
	local semantic = target
	if semantic:match("^archive/") or semantic:match("^reference/") then
		semantic = "Forge/" .. semantic
	elseif not had_forge_prefix and semantic:find("/", 1, true) then
		result.state = "cross-surface"
		return result
	end
	if not semantic:lower():match("%.md$") then
		semantic = semantic .. ".md"
	end

	local exact = model.by_semantic[semantic]
	if exact then
		result.state = "exact"
		result.path = exact.path
		result.semantic = exact.semantic
		result.note = exact
		return result
	end

	local basename = vim.fs.basename(semantic)
	local candidates = model.by_basename[basename] or {}
	if #candidates == 1 then
		local candidate = candidates[1]
		result.state = had_forge_prefix and "relocated" or "exact"
		result.path = candidate.path
		result.semantic = candidate.semantic
		result.note = candidate
		return result
	end
	if #candidates > 1 then
		result.state = "ambiguous"
		result.candidates = vim.tbl_map(function(note)
			return note.semantic
		end, candidates)
		table.sort(result.candidates)
		return result
	end

	result.state = "missing"
	return result
end

local function add_edge(note, seen, kind, target, group)
	target = clean_target(target)
	if target == "" then
		return
	end
	local signature = kind .. "\0" .. target
	if seen[signature] then
		return
	end
	seen[signature] = true
	note.outgoing[#note.outgoing + 1] = {
		kind = kind,
		target = target,
		group = group,
		source_note = note.semantic,
	}
end

local function valid_wikilink_target(target)
	target = clean_target(target)
	if target == "" or target:match("^<.*>$") then
		return false
	end
	if target:find("$", 1, true) or target:find('"', 1, true) then
		return false
	end
	if target:match("^%-%a+%s") then
		return false
	end
	for _, operator in ipairs({ "==", "!=", "=~" }) do
		if target:find(operator, 1, true) then
			return false
		end
	end
	return true
end

local function strip_inline_code(line)
	local parts = {}
	local cursor = 1
	while cursor <= #line do
		local open_start, open_end = line:find("`+", cursor)
		if not open_start then
			parts[#parts + 1] = line:sub(cursor)
			break
		end
		parts[#parts + 1] = line:sub(cursor, open_start - 1)
		local delimiter = line:sub(open_start, open_end)
		local search_from = open_end + 1
		local close_start, close_end
		while search_from <= #line do
			local candidate_start, candidate_end = line:find(delimiter, search_from, true)
			if not candidate_start then
				break
			end
			local before = line:sub(candidate_start - 1, candidate_start - 1)
			local after = line:sub(candidate_end + 1, candidate_end + 1)
			if before ~= "`" and after ~= "`" then
				close_start, close_end = candidate_start, candidate_end
				break
			end
			search_from = candidate_start + 1
		end
		if not close_start then
			parts[#parts + 1] = line:sub(open_start)
			break
		end
		parts[#parts + 1] = " "
		cursor = close_end + 1
	end
	return table.concat(parts)
end

local function collect_edges(note)
	local seen = {}
	local frontmatter_fields = {
		superseded_by = "Lifecycle",
		supersedes = "Lifecycle",
		related = "Declared related",
		promoted = "Durable projections",
	}
	for field, group in pairs(frontmatter_fields) do
		for _, target in ipairs(as_list(note.fields[field])) do
			add_edge(note, seen, field, target, group)
		end
	end

	local fence_char, fence_length
	for index = note.body_start, #note.lines do
		local line = note.lines[index]
		local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
		local closing = line:match("^%s*(`+)%s*$") or line:match("^%s*(~+)%s*$")
		if not fence_char and marker then
			fence_char, fence_length = marker:sub(1, 1), #marker
		elseif fence_char then
			if closing and closing:sub(1, 1) == fence_char and #closing >= fence_length then
				fence_char, fence_length = nil, nil
			end
		elseif not line:match("^    ") and not line:match("^	") then
			local prose = strip_inline_code(line)
			for target in prose:gmatch("%[%[([^%]]+)%]%]") do
				if valid_wikilink_target(target) then
					local kind = clean_target(target):match("^wiki/") and "wiki_link" or "wikilink"
					local group = kind == "wiki_link" and "Durable projections" or "Body links and citations"
					add_edge(note, seen, kind, target, group)
				end
			end
			local citations = prose:gsub("%[%[[^%]]+%]%]", " ")
			for target in citations:gmatch("Forge/[^%s%]%)>,;\"'`]+%.md") do
				add_edge(note, seen, "citation", target, "Body links and citations")
			end
		end
	end
end

local function parse_state(model)
	local state_note = model.by_semantic["Forge/STATE.md"]
	if not state_note then
		model.state_issues[#model.state_issues + 1] = "Forge/STATE.md is missing"
		return
	end

	local section, cluster
	for _, line in ipairs(state_note.lines) do
		local h2 = line:match("^##%s+(.+)$")
		if h2 then
			if h2 == "Live work" or h2:match("^Active") or h2 == "Blocked" then
				section, cluster = h2, nil
			else
				section, cluster = nil, nil
			end
		end
		local h3 = line:match("^###%s+(.+)$")
		if h3 and section then
			cluster = h3
		end
		local target = section and line:match("^%- %[%[([^%]]+)%]%]")
		if target then
			local resolution = M.resolve(model, target)
			local item = {
				section = section,
				cluster = cluster or section,
				target = clean_target(target),
				resolution = resolution,
				note = resolution.note,
				state_summary = line:match("%]%]%s+—%s+(.+)$") or "",
				issues = {},
			}
			model.current[#model.current + 1] = item
			if resolution.note then
				resolution.note.state_memberships[#resolution.note.state_memberships + 1] = item
			else
				item.issues[#item.issues + 1] = ("STATE target is %s"):format(resolution.state)
			end
			if resolution.state ~= "exact" then
				item.issues[#item.issues + 1] = ("STATE reference resolved as %s"):format(resolution.state)
			end
		end
	end
end

local function validate_state(model)
	for _, note in ipairs(model.notes) do
		local workflow = note.fields.workflow_status
		local expected = expected_location(workflow)
		if expected and note.location ~= expected then
			note.state_issues[#note.state_issues + 1] = ("workflow_status=%s expects %s, found %s"):format(
				workflow,
				expected,
				note.location
			)
		end

		if #note.state_memberships > 0 then
			if workflow ~= "live" and workflow ~= "active" and workflow ~= "blocked" then
				note.state_issues[#note.state_issues + 1] =
					"listed in STATE but workflow_status is not live/active/blocked"
			end
			if note.location ~= "workbench" then
				note.state_issues[#note.state_issues + 1] = "listed in STATE outside the Forge workbench"
			end
		elseif
			note.semantic ~= "Forge/STATE.md"
			and note.semantic ~= "Forge/CONVENTIONS.md"
			and note.location == "workbench"
			and (workflow == "live" or workflow == "active" or workflow == "blocked")
		then
			note.state_issues[#note.state_issues + 1] = "workbench note is not listed in STATE"
		end
	end
end

function M.scan(root)
	root = normalize(root)
	if not root or vim.fn.isdirectory(root) == 0 then
		error(
			"configured Forge root is unavailable: "
				.. tostring(root)
				.. "; set FORGE_ROOT or create lua/config/forge_projection.local.lua",
			0
		)
	end

	local model = {
		root = root,
		notes = {},
		by_semantic = {},
		by_basename = {},
		by_path = {},
		current = {},
		backlinks = {},
		state_issues = {},
	}

	for _, relative in ipairs(markdown_files(root)) do
		local note = parse_note(root, relative)
		model.notes[#model.notes + 1] = note
		model.by_semantic[note.semantic] = note
		model.by_path[note.path] = note
		model.by_basename[note.basename] = model.by_basename[note.basename] or {}
		model.by_basename[note.basename][#model.by_basename[note.basename] + 1] = note
	end

	parse_state(model)
	validate_state(model)
	for _, note in ipairs(model.notes) do
		collect_edges(note)
		for _, edge in ipairs(note.outgoing) do
			local resolution = M.resolve(model, edge.target)
			if resolution.note then
				model.backlinks[resolution.semantic] = model.backlinks[resolution.semantic] or {}
				model.backlinks[resolution.semantic][#model.backlinks[resolution.semantic] + 1] = edge
			end
		end
	end
	return model
end

function M.warning(note)
	local warnings = {}
	if #note.state_issues > 0 then
		warnings[#warnings + 1] = "INVALID STATE — " .. table.concat(note.state_issues, "; ")
	end
	local workflow = note.fields.workflow_status
	if workflow == "superseded" then
		warnings[#warnings + 1] = "SUPERSEDED — historical commands are not current authority"
	elseif note.location == "archive" or workflow == "complete" then
		warnings[#warnings + 1] = "HISTORICAL — provenance only; do not treat commands as executable"
	elseif note.location == "reference" or workflow == "reference" then
		warnings[#warnings + 1] = "REFERENCE — supporting material, not live work"
	else
		warnings[#warnings + 1] = "OBSERVATION ONLY — revalidate authority before action"
	end
	if note.legacy then
		warnings[#warnings + 1] = "LEGACY — current schema fields are incomplete"
	end
	return table.concat(warnings, " | ")
end

local group_rank = {
	["Lifecycle"] = 1,
	["Declared related"] = 2,
	["Durable projections"] = 3,
	["Body links and citations"] = 4,
	["Backlinks"] = 5,
	["Control surfaces"] = 6,
}

function M.relations(model, note)
	local relations = {}
	for _, edge in ipairs(note.outgoing) do
		local relation = vim.deepcopy(edge)
		relation.resolution = M.resolve(model, relation.target)
		relations[#relations + 1] = relation
	end

	for _, edge in ipairs(model.backlinks[note.semantic] or {}) do
		relations[#relations + 1] = {
			kind = "backlink:" .. edge.kind,
			target = edge.source_note,
			group = "Backlinks",
			source_note = edge.source_note,
			resolution = M.resolve(model, edge.source_note),
		}
	end

	if #note.state_memberships > 0 and note.semantic ~= "Forge/STATE.md" then
		relations[#relations + 1] = {
			kind = "state_membership",
			target = "Forge/STATE.md",
			group = "Lifecycle",
			source_note = note.semantic,
			resolution = M.resolve(model, "Forge/STATE.md"),
		}
	end
	if note.semantic ~= "Forge/CONVENTIONS.md" then
		relations[#relations + 1] = {
			kind = "governing_conventions",
			target = "Forge/CONVENTIONS.md",
			group = "Control surfaces",
			source_note = note.semantic,
			resolution = M.resolve(model, "Forge/CONVENTIONS.md"),
		}
	end

	table.sort(relations, function(a, b)
		local ar, br = group_rank[a.group] or 99, group_rank[b.group] or 99
		if ar ~= br then
			return ar < br
		end
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		return a.target < b.target
	end)
	return relations
end

local function ensure_model(refresh)
	if refresh or not runtime.model then
		local ok, model = pcall(M.scan, runtime.opts.root)
		if not ok then
			vim.notify(model, vim.log.levels.ERROR)
			return nil
		end
		runtime.model = model
	end
	return runtime.model
end

local function view_buffer(name, lines)
	local bufnr = vim.fn.bufnr(name)
	if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(bufnr, name)
	end

	vim.bo[bufnr].readonly = false
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].readonly = true
	vim.api.nvim_win_set_buf(0, bufnr)
	return bufnr
end

local function close_buffer(bufnr)
	pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

local function relation_label(relation)
	local resolution = relation.resolution
	local target_note = resolution.note
	local detail = target_note
			and compact(target_note.summary ~= "" and target_note.summary or target_note.status_excerpt, 70)
		or ""
	local lifecycle = target_note and (target_note.fields.workflow_status or target_note.location or "legacy") or ""
	return ("[%s] %-20s → %s [%s%s]%s"):format(
		relation.group,
		relation.kind,
		relation.target,
		resolution.state,
		lifecycle ~= "" and "/" .. lifecycle or "",
		detail ~= "" and " — " .. detail or ""
	)
end

function M.choose_relations(note)
	local model = ensure_model(false)
	if not model then
		return
	end
	note = model.by_semantic[note.semantic] or note
	local relations = M.relations(model, note)
	if #relations == 0 then
		vim.notify("no explicit or derived Forge relationships")
		return
	end

	vim.ui.select(relations, {
		prompt = "Forge relationships: " .. note.title,
		format_item = relation_label,
	}, function(relation)
		if not relation then
			return
		end
		local resolution = relation.resolution
		if resolution.note then
			if resolution.state == "relocated" then
				vim.notify(("relocated: %s → %s"):format(resolution.source, resolution.semantic), vim.log.levels.WARN)
			end
			M.open(resolution.note)
			return
		end
		if resolution.state == "ambiguous" then
			vim.notify("ambiguous Forge reference: " .. table.concat(resolution.candidates, ", "), vim.log.levels.ERROR)
		elseif resolution.state == "cross-surface" then
			vim.notify(
				"cross-surface target is visible but not opened in milestone 1: " .. relation.target,
				vim.log.levels.WARN
			)
		else
			vim.notify("missing Forge reference: " .. relation.target, vim.log.levels.ERROR)
		end
	end)
end

function M.open(note)
	local model = ensure_model(false)
	if not model then
		return nil
	end
	if type(note) == "string" then
		note = model.by_semantic[note]
	end
	if not note then
		vim.notify("Forge note is unavailable", vim.log.levels.ERROR)
		return nil
	end

	local lines = {
		"> [!warning] READ-ONLY FORGE PROJECTION",
		"> " .. M.warning(note),
		"> Source: `" .. note.semantic .. "`",
		"",
	}
	vim.list_extend(lines, note.lines)
	local bufnr = view_buffer("forge://" .. note.semantic, lines)
	vim.b[bufnr].forge_projection_kind = "note"
	vim.b[bufnr].forge_projection_semantic = note.semantic

	vim.keymap.set("n", "<leader>br", function()
		M.choose_relations(note)
	end, { buffer = bufnr, desc = "[b]uffer Forge [r]elationships" })
	vim.keymap.set("n", "r", M.refresh, { buffer = bufnr, desc = "Refresh Forge projection" })
	vim.keymap.set("n", "q", function()
		close_buffer(bufnr)
	end, { buffer = bufnr, desc = "Close Forge projection" })
	return bufnr
end

local function overview_lines(model)
	local lines = {
		"# Forge — Current Work",
		"",
		("> [!warning] READ-ONLY FORGE PROJECTION — %d operational item%s from `Forge/STATE.md`"):format(
			#model.current,
			#model.current == 1 and "" or "s"
		),
		"> Observation only. This surface never edits, governs, transitions, repairs, or executes Forge.",
		"",
		"Keys: `<CR>` open · `f` whole corpus · `r` refresh · `s` STATE · `c` CONVENTIONS · `q` close",
		"",
		"## Control surfaces",
		"",
		"- STATE — curated current-work routing",
		"- CONVENTIONS — governing Forge rules",
	}
	local targets = {
		[10] = "Forge/STATE.md",
		[11] = "Forge/CONVENTIONS.md",
	}
	for _, issue in ipairs(model.state_issues) do
		lines[#lines + 1] = ""
		lines[#lines + 1] = "> [!danger] INVALID FORGE SOURCE — " .. issue
	end
	local last_group
	for _, item in ipairs(model.current) do
		local group = item.cluster or item.section
		if group ~= last_group then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## " .. group
			last_group = group
		end
		lines[#lines + 1] = ""
		local target_line = #lines + 1
		if item.note then
			local note = item.note
			local workflow = note.fields.workflow_status or "legacy"
			local doc_type = note.fields.doc_type or "unclassified"
			lines[#lines + 1] = ("- **[%s/%s] %s** — `%s`"):format(workflow, doc_type, note.title, note.semantic)
			local summary = note.summary ~= "" and note.summary or item.state_summary
			if summary ~= "" then
				lines[#lines + 1] = "  " .. compact(summary, 180)
			end
			local next_action = trim(note.fields.next_action)
			local decision = trim(note.fields.human_decision_needed)
			if next_action ~= "" and next_action ~= "none" then
				lines[#lines + 1] = "  Next: " .. compact(next_action, 180)
			end
			if decision ~= "" and decision ~= "none" then
				lines[#lines + 1] = "  Decision: " .. compact(decision, 180)
			end
			if #item.issues > 0 then
				lines[#lines + 1] = "  ⚠ INVALID STATE — " .. table.concat(item.issues, "; ")
			end
			if #note.state_issues > 0 then
				lines[#lines + 1] = "  ⚠ " .. M.warning(note)
			end
			targets[target_line] = note.semantic
		else
			lines[#lines + 1] = ("- **[%s] %s** — %s"):format(
				item.resolution.state,
				item.target,
				table.concat(item.issues, "; ")
			)
		end
	end
	return lines, targets
end

function M.overview()
	local model = ensure_model(true)
	if not model then
		return nil
	end
	local lines, targets = overview_lines(model)
	local bufnr = view_buffer("forge://current-work", lines)
	vim.b[bufnr].forge_projection_kind = "overview"

	vim.keymap.set("n", "<CR>", function()
		local semantic = targets[vim.api.nvim_win_get_cursor(0)[1]]
		if semantic then
			M.open(semantic)
		end
	end, { buffer = bufnr, desc = "Open read-only Forge view" })
	vim.keymap.set("n", "f", M.find, { buffer = bufnr, desc = "Find whole Forge corpus" })
	vim.keymap.set("n", "r", M.refresh, { buffer = bufnr, desc = "Refresh Forge projection" })
	vim.keymap.set("n", "s", function()
		M.open("Forge/STATE.md")
	end, { buffer = bufnr, desc = "Open Forge STATE" })
	vim.keymap.set("n", "c", function()
		M.open("Forge/CONVENTIONS.md")
	end, { buffer = bufnr, desc = "Open Forge CONVENTIONS" })
	vim.keymap.set("n", "q", function()
		close_buffer(bufnr)
	end, { buffer = bufnr, desc = "Close Forge projection" })
	return bufnr
end

local function require_fzf()
	local ok, fzf = pcall(require, "fzf-lua")
	if ok then
		return fzf
	end
	local lazy_ok, lazy = pcall(require, "lazy")
	if lazy_ok then
		lazy.load({ plugins = { "fzf-lua" } })
		ok, fzf = pcall(require, "fzf-lua")
	end
	if not ok then
		vim.notify("Forge discovery requires the configured fzf-lua plugin", vim.log.levels.ERROR)
		return nil
	end
	return fzf
end

function M.find(query)
	local model = ensure_model(true)
	local fzf = model and require_fzf() or nil
	if not fzf then
		return
	end

	local entries = {}
	-- fzf cannot search fields hidden by --with-nth. Keep the searchable
	-- metadata one viewport beyond the concise row and disable horizontal
	-- scrolling so matches never expose the hidden tail.
	local search_padding = string.rep(" ", math.max(vim.o.columns, 120))
	for _, note in ipairs(model.notes) do
		local workflow = note.fields.workflow_status or "legacy"
		local doc_type = note.fields.doc_type or "unclassified"
		local display = ("[%s/%s/%s] %s — %s"):format(
			note.location,
			workflow,
			doc_type,
			note.title,
			compact(note.summary ~= "" and note.summary or note.status_excerpt, 120)
		)
		local heading_text = table.concat(note.headings, " ")
		local search = compact(
			("location:%s workflow:%s doc:%s source:%s %s %s %s %s"):format(
				note.location,
				workflow,
				doc_type,
				note.fields.source or "unknown",
				note.semantic,
				note.title,
				heading_text,
				note.body
			)
		)
		entries[#entries + 1] =
			table.concat({ display .. search_padding, search, note.path, M.warning(note) }, string.char(9))
	end

	fzf.fzf_exec(entries, {
		prompt = "Forge> ",
		query = query or "",
		preview = "printf '%s\\n\\n' {4}; sed -n '1,240p' {3}",
		fzf_opts = {
			["--delimiter"] = string.char(9),
			["--no-hscroll"] = true,
			["--no-multi"] = true,
			["--header"] = "query title/body or tags: location:archive workflow:live doc:proposal source:collab",
		},
		actions = {
			enter = function(selected)
				if not selected or not selected[1] then
					return
				end
				local fields = vim.split(selected[1], "\t", { plain = true })
				local note = model.by_path[normalize(fields[3])]
				if note then
					M.open(note)
				else
					vim.notify("selected Forge entry no longer resolves; refresh and retry", vim.log.levels.ERROR)
				end
			end,
		},
	})
end

function M.refresh()
	local model = ensure_model(true)
	if not model then
		return nil
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local kind = vim.b[bufnr].forge_projection_kind
	if kind == "overview" then
		M.overview()
	elseif kind == "note" then
		local semantic = vim.b[bufnr].forge_projection_semantic
		local note = model.by_semantic[semantic]
		if note then
			M.open(note)
		else
			vim.notify("refreshed Forge source no longer contains " .. tostring(semantic), vim.log.levels.ERROR)
		end
	else
		vim.notify(("Forge projection refreshed: %d Markdown files"):format(#model.notes))
	end
	return model
end

function M.model()
	return runtime.model
end

function M.setup(opts)
	opts = opts or {}
	runtime.opts.root = normalize(opts.root)
	vim.api.nvim_create_user_command("Forge", M.overview, {
		desc = "Open the read-only Forge current-work projection",
		force = true,
	})
	vim.api.nvim_create_user_command("ForgeFind", function(args)
		M.find(args.args)
	end, {
		nargs = "*",
		desc = "Query the whole read-only Forge corpus",
		force = true,
	})
	vim.api.nvim_create_user_command("ForgeRefresh", M.refresh, {
		desc = "Explicitly rebuild the transient Forge projection",
		force = true,
	})
end

return M
