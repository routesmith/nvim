-- ~/.config/nvim/lua/config/artifact_thread.lua
-- Type: Config (experiment)
-- Purpose: Shared filename grammar for Capture artifacts and its consumers:
--          <leader>br  chooser over the current artifact's thread   (experiment 02)
--          promotion   candidate filenames for :Promote             (experiment 03)
--          intent      artifact kinds and thread candidates          (experiment 04)
-- Briefs: ~/.local/state/capture/experiment-brief--02--buffer-local-artifact-traversal.md
--         ~/.local/state/capture/experiment-brief--03--buffer-local-artifact-traversal.md
-- Remove: delete this file, revert the promote() block and the require() in
--         keymaps.lua. Nothing else refers to it.
--
-- Stateless by construction: the thread is recomputed from filenames in the
-- Capture directory at the moment the chooser is opened. Nothing is cached,
-- indexed, or written. A "thread" is just the set of files sharing a subject.

local M = {}

local root = vim.fn.fnamemodify(vim.fn.stdpath("state"), ":h") .. "/capture"

-- Current operational vocabulary. Classification remains permissive for
-- backward compatibility; this list ensures every accepted kind reaches the
-- intent-first consumer even before that kind has appeared in a thread.
local accepted_kinds = {
	"investigation-brief",
	"investigation-report",
	"experiment-brief",
	"experiment-report",
	"proposal-brief",
	"proposal-review",
	"proposal-disposition",
	"proposal-amendment",
	"human-disposition",
	"execution-request",
	"execution-report",
}
local accepted_kind = {}
for _, kind in ipairs(accepted_kinds) do
	accepted_kind[kind] = true
end

-- Filename grammar, all forms separated by `--`:
--   <kind>--<NN>--<subject>.md      investigation-brief--01--interaction-model
--   <kind>-<NN>--<subject>.md       proposal-review-01--external-context
--   <kind>--<subject>.md            proposal-brief--external-context
--   <kind>--<subject>-<NN>.md       overhaul--ai-review--rebuttal-03
-- Returns nil for anything else; unclassified files simply have no thread.
-- ponytail: timestamped captures (20260801T015230-workspace.md) are deliberately
-- not classified. Their subject is the cwd slug, so they would all collapse
-- into one meaningless 15-file thread.
function M.classify(filename)
	local body = filename:match("^(.+)%.md$")
	if not body then
		return nil
	end

	local parts = vim.split(body, "--", { plain = true })
	if #parts < 2 then
		return nil
	end

	local kind, sequence, subject
	if #parts >= 3 and parts[2]:match("^%d+$") then
		kind, sequence, subject = parts[1], tonumber(parts[2]), table.concat(parts, "--", 3)
	else
		kind, subject = parts[1], table.concat(parts, "--", 2)
	end

	-- The sequence can also ride on the tail of the kind or of the subject.
	if not sequence then
		local base, n = kind:match("^(.-)%-(%d+)$")
		if base then
			kind, sequence = base, tonumber(n)
		end
	end
	if not sequence then
		local base, n = subject:match("^(.-)%-(%d+)$")
		if base then
			subject, sequence = base, tonumber(n)
		end
	end

	return { kind = kind, sequence = sequence, subject = subject }
end

-- Thread order: unsequenced artifacts first (they start the thread), then by
-- sequence, ties broken on filename so the order is stable and derived only
-- from the grammar.
function M.order(a, b)
	local sa, sb = a.sequence or -1, b.sequence or -1
	if sa ~= sb then
		return sa < sb
	end
	return a.name < b.name
end

-- mtime is read, never written or stored. It is filesystem metadata that
-- already exists, which is what lets "the thread I was just working on" be
-- answered without a visit log or any other persistent state of our own.
function M.corpus()
	local uv = vim.uv or vim.loop
	local entries = {}
	for name, entry_type in vim.fs.dir(root) do
		if entry_type ~= "directory" then
			local info = M.classify(name)
			if info then
				local stat = uv.fs_stat(root .. "/" .. name)
				info.name = name
				info.mtime = stat and stat.mtime.sec or 0
				entries[#entries + 1] = info
			end
		end
	end
	return entries
end

local function thread(subject)
	local entries = vim.tbl_filter(function(entry)
		return entry.subject == subject
	end, M.corpus())
	table.sort(entries, M.order)
	return entries
end

-- Advisory ranking, pure so it can be checked without touching the filesystem.
-- Grammar rewards convention rather than defining one: the whole vocabulary is
-- whatever is already on disk. A kind is *applicable* if the operator has ever
-- put it in the same thread as the current kind — merely having used it
-- somewhere is not enough, or promotion offers combinations nobody writes.
-- Kinds already in this thread rank first, since continuing a thread is the
-- common move, then by how often the kind has been used.
-- ponytail: sequences are padded to two digits, which every artifact in the
-- corpus already uses. Widen if a thread ever reaches 100.
function M.candidates(entries, info, limit)
	local by_subject, frequency, in_thread, highest = {}, {}, {}, {}
	for _, entry in ipairs(entries) do
		by_subject[entry.subject] = by_subject[entry.subject] or {}
		by_subject[entry.subject][entry.kind] = true
		frequency[entry.kind] = (frequency[entry.kind] or 0) + 1
		if entry.subject == info.subject then
			in_thread[entry.kind] = true
			if entry.sequence then
				highest[entry.kind] = math.max(highest[entry.kind] or 0, entry.sequence)
			end
		end
	end

	-- How many distinct threads have paired each kind with the current one. A
	-- pairing the operator keeps repeating outranks one they made once, so a
	-- single thread containing every kind cannot flatten the ranking.
	local paired = { [info.kind] = 0 }
	for _, kinds_present in pairs(by_subject) do
		if kinds_present[info.kind] then
			for kind in pairs(kinds_present) do
				paired[kind] = (paired[kind] or 0) + 1
			end
		end
	end

	local kinds = {}
	for kind, pair_count in pairs(paired) do
		kinds[#kinds + 1] = {
			kind = kind,
			pair_count = pair_count,
			count = frequency[kind] or 0,
			in_thread = in_thread[kind] or false,
		}
	end
	table.sort(kinds, function(a, b)
		if a.in_thread ~= b.in_thread then
			return a.in_thread
		end
		if a.pair_count ~= b.pair_count then
			return a.pair_count > b.pair_count
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.kind < b.kind
	end)

	local out = {}
	for _, k in ipairs(kinds) do
		if #out >= (limit or 5) then
			break
		end
		out[#out + 1] = ("%s--%02d--%s.md"):format(k.kind, (highest[k.kind] or 0) + 1, info.subject)
	end
	return out
end

-- Candidate filenames for promoting the current buffer into its own thread.
-- Empty when the grammar recognizes nothing, which is the signal to ask what
-- the artifact is intended to become instead.
function M.promotion_candidates(filename)
	local info = M.classify(filename)
	if not info then
		return {}
	end
	return M.candidates(M.corpus(), info)
end

-- Intent-first: preserve the existing eight observed kinds, most-used first,
-- then append any accepted kinds the cap would otherwise hide. Explicit limits
-- retain their old meaning, and a legacy-only corpus keeps its old behavior.
function M.kinds(entries, limit)
	local frequency = {}
	local has_accepted = false
	for _, entry in ipairs(entries) do
		frequency[entry.kind] = (frequency[entry.kind] or 0) + 1
		has_accepted = has_accepted or accepted_kind[entry.kind] or false
	end

	local ranked = {}
	for kind, count in pairs(frequency) do
		ranked[#ranked + 1] = { kind = kind, count = count }
	end
	table.sort(ranked, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.kind < b.kind
	end)

	local out, included = {}, {}
	for _, entry in ipairs(ranked) do
		if #out >= (limit or 8) then
			break
		end
		out[#out + 1] = entry.kind
		included[entry.kind] = true
	end

	if limit == nil and has_accepted then
		for _, entry in ipairs(ranked) do
			if accepted_kind[entry.kind] and not included[entry.kind] then
				out[#out + 1] = entry.kind
				included[entry.kind] = true
			end
		end
		for _, kind in ipairs(accepted_kinds) do
			if not included[kind] then
				out[#out + 1] = kind
				included[kind] = true
			end
		end
	end

	return out
end

-- Once the kind is known, the remaining question is which thread it joins.
-- Threads are offered most-recently-touched first, because the thread you were
-- last working in is overwhelmingly the one you are still working in. A thread
-- that already contains this kind continues its sequence; the rest start at 01.
function M.thread_candidates(entries, kind, limit)
	local touched, highest = {}, {}
	for _, entry in ipairs(entries) do
		touched[entry.subject] = math.max(touched[entry.subject] or 0, entry.mtime or 0)
		if entry.kind == kind and entry.sequence then
			highest[entry.subject] = math.max(highest[entry.subject] or 0, entry.sequence)
		end
	end

	local subjects = {}
	for subject, mtime in pairs(touched) do
		subjects[#subjects + 1] = { subject = subject, mtime = mtime }
	end
	table.sort(subjects, function(a, b)
		if a.mtime ~= b.mtime then
			return a.mtime > b.mtime
		end
		return a.subject < b.subject
	end)

	local out = {}
	for _, entry in ipairs(subjects) do
		if #out >= (limit or 6) then
			break
		end
		out[#out + 1] = ("%s--%02d--%s.md"):format(kind, (highest[entry.subject] or 0) + 1, entry.subject)
	end
	return out
end

-- Every entry shares the subject, so the subject goes in the prompt and the
-- entries show only what distinguishes them. The current artifact is marked.
local function label(entry, current)
	return ("%s %s%s"):format(
		entry.name == current and "▸" or " ",
		entry.kind,
		entry.sequence and (" %02d"):format(entry.sequence) or ""
	)
end

function M.choose()
	local current = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
	local info = M.classify(current)
	if not info then
		return vim.notify("no thread: filename is not a recognized artifact", vim.log.levels.WARN)
	end

	local entries = thread(info.subject)
	if #entries < 2 then
		return vim.notify("no related artifacts in this thread")
	end

	vim.ui.select(entries, {
		prompt = "Thread: " .. info.subject,
		format_item = function(entry)
			return label(entry, current)
		end,
	}, function(choice)
		if choice and choice.name ~= current then
			vim.cmd.edit(vim.fn.fnameescape(root .. "/" .. choice.name))
		end
	end)
end

function M.setup()
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = vim.api.nvim_create_augroup("ArtifactThread", { clear = true }),
		pattern = root .. "/*.md",
		desc = "Artifact thread chooser",
		callback = function(args)
			vim.keymap.set("n", "<leader>br", M.choose, {
				buffer = args.buf,
				desc = "[b]uffer [r]elated artifacts",
			})
		end,
	})
end

-- Self-check:
--   nvim --headless +'lua require("config.artifact_thread").check()' +qa
function M.check()
	-- Accepted operational vocabulary. The runtime parser deliberately remains
	-- vocabulary-agnostic so older and manually named artifacts keep working;
	-- these cases synchronize the shared regression contract with the current
	-- protocol without turning the vocabulary into a rejecting taxonomy.
	local cases = {
		["proposal-review-01--external-context.md"] = { "proposal-review", 1, "external-context" },
		["proposal-brief--external-context.md"] = { "proposal-brief", nil, "external-context" },
		["overhaul--ai-review-consumed--rebuttal-03.md"] = { "overhaul", 3, "ai-review-consumed--rebuttal" },
	}
	for _, kind in ipairs(accepted_kinds) do
		cases[("%s--01--shared-artifact-grammar.md"):format(kind)] = { kind, 1, "shared-artifact-grammar" }
	end
	for name, want in pairs(cases) do
		local got = M.classify(name) or {}
		assert(got.kind == want[1], name .. ": kind = " .. tostring(got.kind))
		assert(got.sequence == want[2], name .. ": sequence = " .. tostring(got.sequence))
		assert(got.subject == want[3], name .. ": subject = " .. tostring(got.subject))
	end
	local embedded = M.classify("execution-report--02--shared--artifact-grammar.md")
	assert(embedded.subject == "shared--artifact-grammar", "double separators inside subject must be preserved")
	assert(M.classify("20260801T015230-workspace.md") == nil, "timestamped capture must not thread")
	assert(M.classify("notes.txt") == nil, "non-markdown must not classify")

	local entries = {
		{ name = "b-2.md", sequence = 2 },
		{ name = "a-1.md", sequence = 1 },
		{ name = "z.md" },
		{ name = "c-1.md", sequence = 1 },
	}
	table.sort(entries, M.order)
	local got = {}
	for i, entry in ipairs(entries) do
		got[i] = entry.name
	end
	assert(table.concat(got, " ") == "z.md a-1.md c-1.md b-2.md", table.concat(got, " "))

	assert(label({ name = "x.md", kind = "proposal-review", sequence = 1 }, "x.md") == "▸ proposal-review 01")
	assert(label({ name = "y.md", kind = "proposal-brief" }, "x.md") == "  proposal-brief")
	for _, kind in ipairs(accepted_kinds) do
		local rendered = label({ name = kind .. ".md", kind = kind, sequence = 1 }, "other.md")
		assert(rendered == ("  %s 01"):format(kind), kind .. ": display label = " .. rendered)
	end

	-- Promotion candidates: thread kinds first, each carrying the next free
	-- sequence *within this thread*. `note` is used in the corpus but has never
	-- shared a thread with `brief`, so it must not be offered. `review` is
	-- paired with `brief` in two threads and `aside` in only one, so a repeated
	-- pairing must outrank a one-off even though both have equal frequency.
	local fake = {
		{ kind = "brief", sequence = 1, subject = "here" },
		{ kind = "brief", sequence = 2, subject = "here" },
		{ kind = "brief", sequence = 1, subject = "other" },
		{ kind = "review", sequence = 1, subject = "other" },
		{ kind = "brief", sequence = 1, subject = "third" },
		{ kind = "review", sequence = 1, subject = "third" },
		{ kind = "aside", sequence = 1, subject = "third" },
		{ kind = "note", sequence = 9, subject = "elsewhere" },
	}
	local current = { kind = "brief", subject = "here" }
	local got_candidates = M.candidates(fake, current)
	assert(got_candidates[1] == "brief--03--here.md", got_candidates[1])
	assert(got_candidates[2] == "review--01--here.md", got_candidates[2])
	assert(got_candidates[3] == "aside--01--here.md", got_candidates[3])
	assert(#got_candidates == 3, "unpaired kinds must not be offered")
	assert(#M.candidates(fake, current, 1) == 1, "limit must cap candidates")

	-- Intent-first. Kinds rank by use across the whole corpus.
	local intent = {
		{ kind = "brief", sequence = 1, subject = "old", mtime = 100 },
		{ kind = "brief", sequence = 2, subject = "old", mtime = 200 },
		{ kind = "brief", sequence = 1, subject = "fresh", mtime = 900 },
		{ kind = "review", sequence = 3, subject = "old", mtime = 300 },
	}
	assert(table.concat(M.kinds(intent), " ") == "brief review", table.concat(M.kinds(intent), " "))
	assert(#M.kinds(intent, 1) == 1, "limit must cap kinds")
	local accepted_entries = {
		{ kind = "legacy", subject = "accepted" },
		{ kind = "legacy", subject = "accepted-2" },
	}
	for _, kind in ipairs(accepted_kinds) do
		accepted_entries[#accepted_entries + 1] = { kind = kind, subject = "accepted" }
	end
	local accepted_default = M.kinds(accepted_entries)
	local old_cap = M.kinds(accepted_entries, 8)
	assert(
		#accepted_default == #accepted_kinds + 1,
		"default must include accepted kinds without dropping the old prefix"
	)
	for i, kind in ipairs(old_cap) do
		assert(accepted_default[i] == kind, "accepted synchronization must preserve the old capped prefix")
	end
	for _, required in ipairs(accepted_kinds) do
		local found = false
		for _, kind in ipairs(accepted_default) do
			found = found or kind == required
		end
		assert(found, required .. " missing from default kinds")
	end

	-- Threads rank newest-touched first; one already holding the kind continues
	-- its sequence, one that does not starts at 01.
	local threads = M.thread_candidates(intent, "brief")
	assert(threads[1] == "brief--02--fresh.md", threads[1])
	assert(threads[2] == "brief--03--old.md", threads[2])
	assert(#threads == 2, "one candidate per known thread")
	assert(M.thread_candidates(intent, "closeout")[1] == "closeout--01--fresh.md", "absent kind starts at 01")

	print("artifact_thread: ok")
end

return M
