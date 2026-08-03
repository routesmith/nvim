-- ~/.config/nvim/lua/config/capture_provenance.lua
-- Read-only, on-demand reconstruction of Git working-tree context from Capture.

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

local function compact(value, limit)
	value = trim((value or ""):gsub("[%s\t\r\n]+", " "))
	if limit and #value > limit then
		return value:sub(1, limit - 1) .. "…"
	end
	return value
end

local function list_contains(values, wanted)
	for _, value in ipairs(values) do
		if value == wanted then
			return true
		end
	end
	return false
end

local function append_unique(values, value)
	if value and value ~= "" and not list_contains(values, value) then
		values[#values + 1] = value
	end
end

local function run_git(root, args, allow_failure)
	local command = { "git", "-c", "color.ui=false" }
	vim.list_extend(command, args)
	local result = vim.system(command, { cwd = root, text = true }):wait()
	if result.code ~= 0 and not allow_failure then
		error(("git command failed in %s: %s\n%s"):format(root, table.concat(args, " "), trim(result.stderr)), 0)
	end
	return result.stdout or "", result.code, result.stderr or ""
end

local function repository_root(candidate)
	candidate = normalize(candidate)
	if not candidate then
		local buffer = vim.api.nvim_buf_get_name(0)
		candidate = buffer ~= "" and vim.fs.dirname(buffer) or vim.fn.getcwd()
	end
	if vim.fn.isdirectory(candidate) == 0 then
		candidate = vim.fs.dirname(candidate)
	end
	local stdout, code = run_git(candidate, { "rev-parse", "--show-toplevel" }, true)
	if code ~= 0 then
		error("no Git repository found from " .. tostring(candidate), 0)
	end
	return normalize(trim(stdout))
end

local function default_capture_root()
	return normalize(vim.fn.fnamemodify(vim.fn.stdpath("state"), ":h") .. "/capture")
end

local function read_lines(path)
	if vim.fn.filereadable(path) == 0 then
		return {}
	end
	return vim.fn.readfile(path, "b")
end

local function within(root, path)
	root, path = normalize(root), normalize(path)
	return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function safe_repo_lines(root, relative)
	local path = normalize(root .. "/" .. relative)
	if not within(root, path) then
		error("Git reported a path outside its repository: " .. tostring(relative), 0)
	end
	return read_lines(path)
end

local known_roles = {
	"investigation-brief",
	"investigation-report",
	"experiment-brief",
	"experiment-report",
	"experiment-closeout",
	"proposal-brief",
	"proposal-review",
	"proposal-amendment",
	"proposal",
	"rebuttal",
	"notes",
}

local function artifact_role(name)
	for _, role in ipairs(known_roles) do
		if name:sub(1, #role + 1) == role .. "-" then
			return role
		end
	end
	return "other"
end

local function artifact_subject(artifact)
	if artifact.role == "other" then
		return nil
	end
	local stem = artifact.basename:gsub("%.md$", "")
	local rest = stem:sub(#artifact.role + 1)
	rest = rest:gsub("^%-%-%d+%-%-", "", 1)
	rest = rest:gsub("^%-%d+%-%-", "", 1)
	rest = rest:gsub("^%-%-", "", 1)
	return rest ~= "" and rest or nil
end

local function artifact_title(lines, basename)
	for index, line in ipairs(lines) do
		if line:lower() == "## title" then
			for next_index = index + 1, #lines do
				if trim(lines[next_index]) ~= "" then
					return trim(lines[next_index]):gsub("^#+%s*", "")
				end
			end
		end
	end
	for _, line in ipairs(lines) do
		local title = line:match("^#%s+(.+)$")
		if title then
			return trim(title)
		end
	end
	return basename:gsub("%.md$", "")
end

local relationship_labels = {
	["responds to"] = "responds_to",
	["builds on"] = "builds_on",
	["supersedes"] = "supersedes",
	["retains from"] = "retains_from",
	["retained from"] = "retains_from",
	["proposed by"] = "proposed_by",
}

local function clean_artifact_target(raw)
	return trim(raw):gsub("^`", ""):gsub("`$", ""):gsub("^%[%[", ""):gsub("%]%]$", "")
end

local function parse_artifact(path)
	local lines = read_lines(path)
	local basename = vim.fs.basename(path)
	local relations = {}
	for index, line in ipairs(lines) do
		local label, target = line:match("^([%a ]+):%s*(.+)$")
		local edge_type = label and relationship_labels[label:lower()]
		if edge_type then
			target = clean_artifact_target(target)
			if target ~= "" then
				relations[#relations + 1] = { type = edge_type, target = target, line = index }
			end
		end
	end
	return {
		path = normalize(path),
		basename = basename,
		role = artifact_role(basename),
		title = artifact_title(lines, basename),
		lines = lines,
		body = table.concat(lines, "\n"),
		relations = relations,
		meta_reconstruction = list_contains(lines, "## Reconstruction summary"),
	}
end

local function capture_artifacts(root)
	if vim.fn.isdirectory(root) == 0 then
		error("Capture directory is unavailable: " .. tostring(root), 0)
	end
	local artifacts = {}
	for name, kind in vim.fs.dir(root) do
		if (kind == "file" or kind == "link") and name:lower():match("%.md$") then
			artifacts[#artifacts + 1] = parse_artifact(root .. "/" .. name)
		end
	end
	table.sort(artifacts, function(left, right)
		return left.basename < right.basename
	end)
	local by_basename = {}
	for _, artifact in ipairs(artifacts) do
		by_basename[artifact.basename] = artifact
	end
	return artifacts, by_basename
end

local function parse_status(raw)
	local paths = {}
	local records = vim.split(raw, "\0", { plain = true, trimempty = true })
	local index = 1
	while index <= #records do
		local record = records[index]
		local state = record:sub(1, 2)
		local path = record:sub(4)
		if path ~= "" then
			paths[#paths + 1] = {
				path = path,
				state = state,
				untracked = state == "??",
			}
		end
		if state:find("[RC]") then
			index = index + 1 -- porcelain -z follows a rename/copy destination with its source path
		end
		index = index + 1
	end
	table.sort(paths, function(left, right)
		return left.path < right.path
	end)
	return paths
end

local function changed_lines(diff)
	local added, removed = {}, {}
	local old_line, new_line
	local in_hunk = false
	for line in (diff .. "\n"):gmatch("(.-)\n") do
		local old_start, new_start = line:match("^@@ %-(%d+)[^ ]* %+(%d+)[^ ]* @@")
		if old_start then
			old_line, new_line = tonumber(old_start), tonumber(new_start)
			in_hunk = true
		elseif in_hunk then
			local prefix = line:sub(1, 1)
			local text = line:sub(2)
			if prefix == "+" then
				added[new_line] = text
				new_line = new_line + 1
			elseif prefix == "-" then
				removed[#removed + 1] = text
				old_line = old_line + 1
			elseif prefix == " " then
				old_line = old_line + 1
				new_line = new_line + 1
			end
		end
	end
	return added, removed
end

local function lua_regions(lines)
	local regions = {}
	for index, line in ipairs(lines) do
		local symbol = line:match("^local%s+function%s+([%w_%.:]+)%s*%(") or line:match("^function%s+([%w_%.:]+)%s*%(")
		if symbol then
			regions[#regions + 1] = { symbol = symbol, start_line = index }
		end
	end
	for index, region in ipairs(regions) do
		region.end_line = regions[index + 1] and (regions[index + 1].start_line - 1) or #lines
	end
	return regions
end

local function meaningful(line)
	line = trim(line)
	return line ~= "" and not line:match("^%-%-") and line ~= "end" and line ~= "{" and line ~= "}"
end

local function quoted_terms(lines)
	local terms = {}
	for _, line in ipairs(lines) do
		for _, quote in ipairs({ '"', "'" }) do
			local pattern = quote .. "([^" .. quote .. "]+)" .. quote
			for value in line:gmatch(pattern) do
				if #value >= 5 and #value <= 100 then
					append_unique(terms, value)
				end
			end
		end
	end
	return terms
end

local function make_unit(path, label, symbol, start_line, end_line, lines, removed)
	local content = {}
	for _, line in ipairs(lines or {}) do
		if meaningful(line) then
			content[#content + 1] = trim(line)
		end
	end
	for _, line in ipairs(removed or {}) do
		if meaningful(line) then
			content[#content + 1] = trim(line)
		end
	end
	return {
		path = path,
		label = label,
		symbol = symbol,
		start_line = start_line,
		end_line = end_line,
		lines = content,
		quoted = quoted_terms(content),
		removed = removed or {},
	}
end

local function units_for_path(root, entry)
	local lines = safe_repo_lines(root, entry.path)
	local units = {}
	if entry.untracked then
		if entry.path:lower():match("%.lua$") then
			local regions = lua_regions(lines)
			for _, region in ipairs(regions) do
				local body = vim.list_slice(lines, region.start_line, region.end_line)
				units[#units + 1] = make_unit(
					entry.path,
					region.symbol .. "()",
					region.symbol,
					region.start_line,
					region.end_line,
					body,
					{}
				)
			end
			if #units == 0 then
				units[#units + 1] = make_unit(entry.path, "untracked file", nil, 1, #lines, lines, {})
			end
		else
			units[#units + 1] = make_unit(entry.path, "untracked file", nil, 1, #lines, lines, {})
		end
		return units
	end

	local diff = run_git(root, { "diff", "HEAD", "--no-ext-diff", "--unified=0", "--", entry.path })
	local added, removed = changed_lines(diff)
	local covered = {}
	if entry.path:lower():match("%.lua$") then
		for _, region in ipairs(lua_regions(lines)) do
			local body, touched = {}, false
			for line_number = region.start_line, region.end_line do
				body[#body + 1] = lines[line_number]
				if added[line_number] then
					touched = true
					covered[line_number] = true
				end
			end
			if touched then
				units[#units + 1] = make_unit(
					entry.path,
					region.symbol .. "()",
					region.symbol,
					region.start_line,
					region.end_line,
					body,
					{}
				)
			end
		end
	end

	local loose_added = {}
	for line_number, text in pairs(added) do
		if not covered[line_number] then
			loose_added[#loose_added + 1] = { line = line_number, text = text }
		end
	end
	table.sort(loose_added, function(left, right)
		return left.line < right.line
	end)
	if #loose_added > 0 then
		local body = {}
		for _, item in ipairs(loose_added) do
			body[#body + 1] = item.text
		end
		units[#units + 1] = make_unit(
			entry.path,
			"changed lines",
			nil,
			loose_added[1].line,
			loose_added[#loose_added].line,
			body,
			#units == 0 and removed or {}
		)
	elseif #units == 0 and #removed > 0 then
		units[#units + 1] = make_unit(entry.path, "removed entries", nil, nil, nil, {}, removed)
	end

	return units
end

local function file_source_references(root, unit, artifacts)
	local body = table.concat(safe_repo_lines(root, unit.path), "\n")
	local refs = {}
	for _, artifact in ipairs(artifacts) do
		if body:find(artifact.basename, 1, true) then
			refs[#refs + 1] = artifact.basename
		end
	end
	return refs
end

local function evidence_for(unit, artifact, source_refs)
	local evidence, score = {}, 0
	if list_contains(source_refs, artifact.basename) then
		score = score + 9
		evidence[#evidence + 1] = "implementation cites `" .. artifact.basename .. "`"
	end
	if artifact.body:find(unit.path, 1, true) then
		score = score + 6
		evidence[#evidence + 1] = "artifact names exact Git path `" .. unit.path .. "`"
	end
	local short_symbol = unit.symbol and unit.symbol:match("([%w_]+)$")
	if
		unit.symbol
		and #unit.symbol >= 4
		and (artifact.body:find(unit.symbol, 1, true) or artifact.body:find(short_symbol, 1, true))
	then
		score = score + 5
		evidence[#evidence + 1] = "artifact names exact symbol `" .. short_symbol .. "`"
	end
	local quoted_matches = 0
	for _, value in ipairs(unit.quoted) do
		local distinctive = not value:match("^[%w_%.:/%-]+$")
		if distinctive and artifact.body:find(value, 1, true) then
			quoted_matches = quoted_matches + 1
			score = score + 3
			evidence[#evidence + 1] = "artifact matches implementation text `" .. compact(value, 72) .. "`"
			if quoted_matches == 2 then
				break
			end
		end
	end
	local removed_matches = 0
	for _, value in ipairs(unit.removed) do
		value = trim(value):gsub("[,;]+$", "")
		if #value >= 5 and artifact.body:find(value, 1, true) then
			removed_matches = removed_matches + 1
			score = score + 4
			evidence[#evidence + 1] = "artifact matches deleted entry `" .. compact(value, 72) .. "`"
			if removed_matches == 2 then
				break
			end
		end
	end

	local context_needles = {}
	if short_symbol then
		context_needles[#context_needles + 1] = short_symbol
	end
	for _, value in ipairs(unit.removed) do
		value = trim(value):gsub("[,;]+$", "")
		if #value >= 5 then
			context_needles[#context_needles + 1] = value
		end
	end
	local positive_context, negative_context = false, false
	for index, line in ipairs(artifact.lines) do
		local matched = false
		for _, needle in ipairs(context_needles) do
			if line:find(needle, 1, true) then
				matched = true
				break
			end
		end
		if matched then
			local nearby = {}
			for nearby_index = math.max(1, index - 2), math.min(#artifact.lines, index + 2) do
				nearby[#nearby + 1] = artifact.lines[nearby_index]:lower()
			end
			local context = table.concat(nearby, " ")
			if
				context:match("%f[%a]added%f[%A]")
				or context:match("%f[%a]removed%f[%A]")
				or context:find("implement", 1, true)
				or context:find("what was built", 1, true)
				or context:find("split into", 1, true)
				or context:find("execution completed", 1, true)
			then
				positive_context = true
			end
			if
				context:find("unchanged", 1, true)
				or context:find("unmodified", 1, true)
				or context:find("unaffected", 1, true)
			then
				negative_context = true
			end
		end
	end
	if positive_context then
		score = score + 4
		evidence[#evidence + 1] = "artifact records an implementation action at the matched seam"
	elseif negative_context then
		score = math.max(0, score - 2)
		evidence[#evidence + 1] = "artifact describes the matched seam as unchanged or unaffected"
	end
	return score, evidence
end

local function is_report(artifact)
	return artifact.role:find("report", 1, true) ~= nil or artifact.role:find("closeout", 1, true) ~= nil
end

local function responds_to(artifact, by_basename)
	for _, relation in ipairs(artifact.relations) do
		if relation.type == "responds_to" then
			return by_basename[vim.fs.basename(relation.target)], relation
		end
	end
	return nil
end

local function confidence(score)
	if score >= 10 then
		return "C4"
	end
	if score >= 9 then
		return "C3"
	end
	return "C0"
end

local function reconstruct_unit(root, unit, artifacts, by_basename)
	local source_refs = file_source_references(root, unit, artifacts)
	local source_subjects = {}
	for _, basename in ipairs(source_refs) do
		local referenced = by_basename[basename]
		if referenced then
			append_unique(source_subjects, artifact_subject(referenced))
		end
	end
	local candidates = {}
	for _, artifact in ipairs(artifacts) do
		local anchored = list_contains(source_refs, artifact.basename) or artifact.body:find(unit.path, 1, true) ~= nil
		local eligible = artifact.role ~= "other" and not artifact.meta_reconstruction and anchored
		if eligible and #source_subjects > 0 then
			eligible = list_contains(source_subjects, artifact_subject(artifact))
		end
		local score, evidence = evidence_for(unit, artifact, source_refs)
		if eligible and score > 0 then
			candidates[#candidates + 1] = { artifact = artifact, score = score, evidence = evidence }
		end
	end
	table.sort(candidates, function(left, right)
		if left.score ~= right.score then
			return left.score > right.score
		end
		return left.artifact.basename < right.artifact.basename
	end)

	local best = candidates[1]
	if not best or best.score < 9 then
		return {
			unit = unit,
			origin = nil,
			confidence = "C0",
			direct = false,
			edge_type = "unresolved",
			evidence = best and best.evidence or {},
			ambiguity = { "No candidate has enough exact evidence to establish an origin." },
		}
	end

	local best_origin = select(1, responds_to(best.artifact, by_basename)) or best.artifact
	local tied = candidates[2] and candidates[2].score == best.score
	local tied_origin = tied and (select(1, responds_to(candidates[2].artifact, by_basename)) or candidates[2].artifact)
	if tied and tied_origin.path ~= best_origin.path then
		return {
			unit = unit,
			origin = nil,
			confidence = "C0",
			direct = false,
			edge_type = "unresolved",
			evidence = best.evidence,
			ambiguity = {
				("Equal exact-source evidence points to `%s` and `%s`; no stronger seam distinguishes them."):format(
					best.artifact.basename,
					candidates[2].artifact.basename
				),
			},
		}
	end

	local origin = best.artifact
	local edge_type = is_report(origin) and "reported_by" or "implements"
	local direct = true
	local related, relation = responds_to(best.artifact, by_basename)
	if related then
		origin = related
		edge_type = "implements"
		best.evidence[#best.evidence + 1] = ("`%s` explicitly responds to `%s` (line %d)"):format(
			best.artifact.basename,
			related.basename,
			relation.line
		)
	end

	local edges = {
		{
			type = edge_type,
			artifact = origin,
			direct = direct,
			confidence = confidence(best.score),
			evidence = best.evidence,
		},
	}
	if best.artifact.path ~= origin.path then
		edges[#edges + 1] = {
			type = "reported_by",
			artifact = best.artifact,
			direct = true,
			confidence = confidence(best.score),
			evidence = best.evidence,
		}
	end

	local relation_sources = { origin }
	if best.artifact.path ~= origin.path then
		relation_sources[#relation_sources + 1] = best.artifact
	end
	for _, source in ipairs(relation_sources) do
		for _, explicit in ipairs(source.relations) do
			local target = by_basename[vim.fs.basename(explicit.target)]
			if explicit.type ~= "responds_to" and target then
				edges[#edges + 1] = {
					type = explicit.type,
					artifact = target,
					direct = true,
					confidence = "C4",
					evidence = {
						("`%s` declares `%s` to `%s` (line %d)"):format(
							source.basename,
							explicit.type,
							target.basename,
							explicit.line
						),
					},
				}
			end
		end
	end

	for _, candidate in ipairs(candidates) do
		if
			candidate.score >= 9
			and candidate.artifact.path ~= origin.path
			and candidate.artifact.path ~= best.artifact.path
		then
			edges[#edges + 1] = {
				type = is_report(candidate.artifact) and "reported_by" or "context_from",
				artifact = candidate.artifact,
				direct = candidate.score >= 11,
				confidence = confidence(candidate.score),
				evidence = candidate.evidence,
			}
		end
	end

	return {
		unit = unit,
		origin = origin,
		confidence = confidence(best.score),
		direct = direct,
		edge_type = edge_type,
		evidence = best.evidence,
		ambiguity = {},
		edges = edges,
	}
end

local function confidence_rank(value)
	return tonumber(value:match("%d")) or 0
end

local function merge_reconstructions(reconstructions)
	local changes, by_key = {}, {}
	for _, item in ipairs(reconstructions) do
		local key = item.origin and item.origin.path or ("unresolved:" .. item.unit.path)
		local change = by_key[key]
		if not change then
			change = {
				origin = item.origin,
				confidence = item.confidence,
				direct = item.direct,
				edge_type = item.edge_type,
				units = {},
				edges = {},
				evidence = {},
				ambiguity = {},
			}
			changes[#changes + 1] = change
			by_key[key] = change
		end
		change.units[#change.units + 1] = item.unit
		if confidence_rank(item.confidence) > confidence_rank(change.confidence) then
			change.confidence = item.confidence
		end
		change.direct = change.direct and item.direct
		for _, value in ipairs(item.evidence or {}) do
			append_unique(change.evidence, value)
		end
		for _, value in ipairs(item.ambiguity or {}) do
			append_unique(change.ambiguity, value)
		end
		for _, edge in ipairs(item.edges or {}) do
			local edge_key = edge.type .. "\0" .. edge.artifact.path
			local exists = false
			for _, existing in ipairs(change.edges) do
				if existing._key == edge_key then
					exists = true
					break
				end
			end
			if not exists then
				edge._key = edge_key
				change.edges[#change.edges + 1] = edge
			end
		end
	end
	table.sort(changes, function(left, right)
		if left.origin and not right.origin then
			return true
		end
		if right.origin and not left.origin then
			return false
		end
		local left_name = left.origin and left.origin.basename or left.units[1].path .. left.units[1].label
		local right_name = right.origin and right.origin.basename or right.units[1].path .. right.units[1].label
		return left_name < right_name
	end)
	return changes
end

function M.scan(opts)
	opts = opts or {}
	local root = repository_root(opts.repo)
	local capture_root = normalize(opts.capture_root or runtime.opts.capture_root or default_capture_root())
	local head = trim(run_git(root, { "rev-parse", "HEAD" }))
	local status = run_git(root, { "status", "--porcelain=v1", "-z", "--untracked-files=all" })
	local paths = parse_status(status)
	local artifacts, by_basename = capture_artifacts(capture_root)
	local units = {}
	for _, entry in ipairs(paths) do
		vim.list_extend(units, units_for_path(root, entry))
	end
	local reconstructed = {}
	for _, unit in ipairs(units) do
		reconstructed[#reconstructed + 1] = reconstruct_unit(root, unit, artifacts, by_basename)
	end
	local changes = merge_reconstructions(reconstructed)
	local negative_findings = {}
	local has_proposal = false
	for _, change in ipairs(changes) do
		if change.origin and change.origin.role:find("proposal", 1, true) then
			has_proposal = true
		end
		for _, edge in ipairs(change.edges) do
			if edge.artifact.role:find("proposal", 1, true) then
				has_proposal = true
			end
		end
	end
	if not has_proposal then
		negative_findings[#negative_findings + 1] = "No proposal lineage established for any reconstructed change."
	end
	for _, entry in ipairs(paths) do
		if entry.untracked then
			negative_findings[#negative_findings + 1] = ("Untracked `%s` has no prior Git snapshot; provenance can only be inferred from content."):format(
				entry.path
			)
		end
	end
	local unresolved = 0
	for _, change in ipairs(changes) do
		if not change.origin then
			unresolved = unresolved + 1
		end
	end
	if unresolved > 0 then
		negative_findings[#negative_findings + 1] = ("%d coherent change%s remain unresolved because evidence is insufficient."):format(
			unresolved,
			unresolved == 1 and "" or "s"
		)
	end
	local model = {
		root = root,
		head = head,
		capture_root = capture_root,
		paths = paths,
		units = units,
		changes = changes,
		artifacts = artifacts,
		negative_findings = negative_findings,
	}
	runtime.model = model
	return model
end

local function unit_surface(unit)
	if unit.start_line and unit.end_line then
		return ("`%s:%d-%d` — %s"):format(unit.path, unit.start_line, unit.end_line, unit.label)
	end
	if unit.start_line then
		return ("`%s:%d` — %s"):format(unit.path, unit.start_line, unit.label)
	end
	return ("`%s` — %s"):format(unit.path, unit.label)
end

function M.render(model)
	local lines = {
		"# Git → Capture Provenance",
		"",
		"> [!warning] READ-ONLY RECONSTRUCTION",
		"> Evidence precedes inference. This projection never modifies Git or Capture.",
		"",
		("Repository: `%s`"):format(model.root),
		("HEAD: `%s`"):format(model.head),
		("Working tree: %d path%s · %d coherent change%s"):format(
			#model.paths,
			#model.paths == 1 and "" or "s",
			#model.changes,
			#model.changes == 1 and "" or "s"
		),
		"Confidence: C4 exact corroborated · C3 exact single seam · C0 unresolved",
		"",
		"Keys: `<CR>` inspect Capture evidence · `r` reconstruct · `q` close",
		"",
	}
	local targets = {}
	lines[#lines + 1] = "Git snapshot:"
	lines[#lines + 1] = ""
	if #model.paths == 0 then
		lines[#lines + 1] = "- clean"
	else
		for _, entry in ipairs(model.paths) do
			lines[#lines + 1] = ("- `%s` · `%s`"):format(entry.state, entry.path)
		end
	end
	lines[#lines + 1] = ""
	if #model.changes == 0 then
		lines[#lines + 1] = "No uncommitted working-tree changes."
	end
	for index, change in ipairs(model.changes) do
		local title = change.origin and change.origin.title or change.units[1].label
		local relation = change.origin and (change.direct and "DIRECT" or "INFERRED") or "UNRESOLVED"
		lines[#lines + 1] = ("## CH-%02d — %s"):format(index, title)
		lines[#lines + 1] = ""
		lines[#lines + 1] = ("**%s · %s · %s**"):format(change.confidence, relation, change.edge_type)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Git surface:"
		lines[#lines + 1] = ""
		for _, unit in ipairs(change.units) do
			lines[#lines + 1] = "- " .. unit_surface(unit)
		end
		if change.origin then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Originating Capture artifact:"
			lines[#lines + 1] = ""
			local target_line = #lines + 1
			lines[#lines + 1] = ("- `%s` — %s"):format(change.origin.basename, change.origin.role)
			targets[target_line] = change.origin.path
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Supporting evidence:"
		lines[#lines + 1] = ""
		if #change.evidence == 0 then
			lines[#lines + 1] = "- None strong enough to establish an origin."
		else
			for _, evidence in ipairs(change.evidence) do
				lines[#lines + 1] = "- " .. evidence
			end
		end
		if #change.edges > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Typed relationships:"
			lines[#lines + 1] = ""
			for _, edge in ipairs(change.edges) do
				local target_line = #lines + 1
				lines[#lines + 1] = ("- `%s` · %s · %s · %s"):format(
					edge.type,
					edge.direct and "direct" or "inferred",
					edge.confidence,
					edge.artifact.basename
				)
				targets[target_line] = edge.artifact.path
				for _, evidence in ipairs(edge.evidence or {}) do
					lines[#lines + 1] = "  - evidence: " .. evidence
				end
			end
		end
		if #change.ambiguity > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Ambiguity / limits:"
			lines[#lines + 1] = ""
			for _, value in ipairs(change.ambiguity) do
				lines[#lines + 1] = "- " .. value
			end
		end
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = "## Negative findings"
	lines[#lines + 1] = ""
	if #model.negative_findings == 0 then
		lines[#lines + 1] = "- None."
	else
		for _, finding in ipairs(model.negative_findings) do
			lines[#lines + 1] = "- " .. finding
		end
	end
	return lines, targets
end

local function view_buffer(name, lines)
	local existing = vim.fn.bufnr(name)
	if existing ~= -1 then
		pcall(vim.api.nvim_buf_delete, existing, { force = true })
	end
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, name)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "markdown"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].readonly = true
	vim.api.nvim_set_current_buf(bufnr)
	return bufnr
end

local function close_buffer(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
end

function M.open_artifact(path)
	path = normalize(path)
	local model = runtime.model
	if not model or not path or not within(model.capture_root, path) or vim.fn.filereadable(path) == 0 then
		vim.notify("Capture evidence no longer resolves; reconstruct and retry", vim.log.levels.ERROR)
		return nil
	end
	local lines = {
		"> [!warning] READ-ONLY CAPTURE EVIDENCE",
		"> Source: `" .. path .. "`",
		"",
	}
	vim.list_extend(lines, read_lines(path))
	local bufnr = view_buffer("capture-provenance://" .. vim.fs.basename(path), lines)
	vim.keymap.set("n", "q", function()
		close_buffer(bufnr)
	end, { buffer = bufnr, desc = "Close Capture evidence" })
	return bufnr
end

function M.overview(opts)
	local model = M.scan(opts)
	local lines, targets = M.render(model)
	local bufnr = view_buffer("capture-provenance://overview", lines)
	vim.b[bufnr].capture_provenance_opts = opts or {}
	vim.keymap.set("n", "<CR>", function()
		local target = targets[vim.api.nvim_win_get_cursor(0)[1]]
		if target then
			M.open_artifact(target)
		end
	end, { buffer = bufnr, desc = "Inspect read-only Capture evidence" })
	vim.keymap.set("n", "r", function()
		M.overview(vim.b[bufnr].capture_provenance_opts)
	end, { buffer = bufnr, desc = "Reconstruct Git to Capture provenance" })
	vim.keymap.set("n", "q", function()
		close_buffer(bufnr)
	end, { buffer = bufnr, desc = "Close provenance reconstruction" })
	return bufnr
end

function M.model()
	return runtime.model
end

function M.setup(opts)
	runtime.opts = opts or {}
	vim.api.nvim_create_user_command("CaptureProvenance", function(args)
		M.overview({
			repo = args.args ~= "" and args.args or nil,
			capture_root = runtime.opts.capture_root,
		})
	end, {
		nargs = "?",
		complete = "dir",
		force = true,
		desc = "Reconstruct the current Git working tree from read-only Capture evidence",
	})
end

return M
