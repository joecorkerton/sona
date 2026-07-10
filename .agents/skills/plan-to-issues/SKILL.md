---
name: plan-to-issues
description: Use when the user wants to turn a plan, spec, or design document into a set of tracked work issues stored as markdown files under issues/. Trigger on phrases like "convert this plan into issues", "break this spec into issues", "make issues from this doc", or when the user references a plan file and asks for issues. Creates one markdown file per issue plus a TODO.md index and a README.md convention file.
---

# Plan → Issues

Convert a plan/spec/design document into a set of durable, greppable issue
files under `issues/` in the repo root. Each issue is one markdown file with
YAML frontmatter, an acceptance-criteria checklist, and a running notes log.
A `TODO.md` index gives a one-shot view of open work, and a `README.md`
documents the convention so any fresh agent session can bootstrap itself.

## Directory layout

```
issues/
  README.md            # convention doc (write once, update rarely)
  TODO.md              # index: one line per open issue, grouped by status
  001-slug.md          # one file per issue, NNN-slug.md naming
  002-slug.md
  ...
  archive/             # completed issues moved here (preserve filename)
    003-done-thing.md
```

- Issue IDs are zero-padded 3-digit (`001`, `002`, ...) and never reused.
- Filenames are `<id>-<kebab-case-slug>.md`. The slug is stable; do not rename
  when the title changes — update the `title:` frontmatter field instead.
- When an issue is completed, move the file into `issues/archive/` and remove
  its line from `TODO.md`. Keep the filename identical so commit messages and
  cross-references stay valid.

## Per-issue file format

```markdown
---
id: 001
title: Build Seatbelt wrapper for OpenCode
status: todo
created: 2026-07-10
depends_on: []
---

## Goal
One or two sentences on the intended outcome.

## Context
Why this issue exists, what's been tried, links to the source plan section.
Reference the plan doc by relative path, e.g. `docs/plan-sandbox.md#seatbelt`.

## Acceptance criteria
- [ ] Concrete, verifiable outcome #1
- [ ] Concrete, verifiable outcome #2
- [ ] Fails closed when X

## Notes
- 2026-07-10: started investigation
- (append-only running log; newest entries at the bottom)
```

Frontmatter rules:

- `id`: required, integer, matches the filename prefix.
- `title`: required, short human-readable summary.
- `status`: required, one of `todo`, `in-progress`, `blocked`, `done`.
  Set to `done` only when *all* acceptance criteria are checked.
- `created`: required, `YYYY-MM-DD` (use `Date.utc_today()` semantics —
  the current date is already in the session env).
- `depends_on`: optional, list of integer IDs. Omit the field or use `[]` if
  there are no dependencies. An issue should not start until all deps are
  `done`.
- Keep frontmatter minimal. Do not add custom fields unless the user asks;
  the model and any tooling should be able to rely on this exact shape.

Body rules:

- `## Goal`, `## Context`, `## Acceptance criteria`, `## Notes` — always in
  this order, always these exact headings.
- Acceptance criteria are `- [ ]` checkboxes. Check them off (`- [x]`) as work
  progresses; this is the in-place state the agent edits.
- `## Notes` is append-only. Prefix each entry with `- YYYY-MM-DD:`. Never
  delete prior notes — cross out with `~~...~~` if superseded.

## TODO.md index format

```markdown
# Issues

Open work, one line per issue. See `README.md` for the convention and
individual issue files for detail.

## In progress
- [001](001-seatbelt-wrapper.md) Build Seatbelt wrapper for OpenCode

## Todo
- [002](002-elixir-toolchain-access.md) Elixir toolchain read access in sandbox

## Blocked
- (none)

## Done
- (see archive/)
```

- One bullet per open issue, grouped under `## In progress`, `## Todo`,
  `## Blocked`. Completed issues are removed from the index and their files
  moved to `archive/`; a `(see archive/)` placeholder keeps the `## Done`
  section visible.
- Link text is the `[id]`, link target is the relative filename. Keep the
  one-line title after the link so the index is scannable without opening
  files.
- Rebuild the whole index when statuses change — don't try to surgically edit
  one line; rewrite `TODO.md` from the current set of issue files.

## README.md convention file

Write this once on first issue creation. Keep it short — its job is to let a
fresh agent session understand the system from a single file.

```markdown
# issues/

Local, file-based issue tracking. One markdown file per issue, indexed in
`TODO.md`. Issues live in version control alongside the code.

## Layout
- `TODO.md` — index of open issues (one line each, grouped by status)
- `NNN-slug.md` — one issue per file, `NNN` is a zero-padded stable id
- `archive/` — completed issues moved here, filename preserved

## Issue frontmatter
- `id` (int, matches filename prefix)
- `title` (string)
- `status` (one of: todo, in-progress, blocked, done)
- `created` (YYYY-MM-DD)
- `depends_on` (optional list of ids)

## Body sections (in order)
1. `## Goal` — intended outcome
2. `## Context` — why, links to source plan
3. `## Acceptance criteria` — `- [ ]` checkboxes, check off as work lands
4. `## Notes` — append-only dated log

## Workflow
- Start work: set `status: in-progress`, add a dated note.
- Finish: check all acceptance criteria, set `status: done`, move file to
  `archive/`, remove from `TODO.md`.
- Blocked: set `status: blocked`, note the blocker in `## Notes`.
- New issue: next free id, add file, add line to `TODO.md` under `## Todo`.
- Respect `depends_on`: don't start until all deps are `done`.
```

## Conversion procedure

When converting a plan document into issues:

1. **Read the source plan in full.** If the user gave a path, read it. If they
   pasted text, use that. Do not start writing issues until you understand
   the whole plan.
2. **Identify issue boundaries.** An issue is a unit of work that:
   - has a clear, verifiable acceptance criterion (not "investigate X"),
   - can be completed independently of unrelated issues (modulo `depends_on`),
   - is small enough to land in one PR/commit cluster.
   Split coarse plan sections into multiple issues. Merge trivially-tiny
   sections into a single issue rather than creating noise. Aim for the
   smallest set of issues that still lets each one be verified on its own.
3. **Assign IDs and slugs.** Start at `001`, zero-padded. Slugs are
   kebab-case, short, stable. Never reuse an id — if `issues/` already has
   files, continue from the highest existing id + 1. Check `issues/archive/`
   too.
4. **Derive dependencies.** If issue B can't be verified until issue A
   lands, set `depends_on: [A]` on B. Keep the graph shallow; if you find a
   long chain, reconsider whether intermediate issues are real.
5. **Write each issue file** using the format above. Acceptance criteria
   must be concrete and checkable — prefer "network access limited to these
   endpoints" over "sandbox the network". Pull context straight from the
   plan; cite the plan doc path so the issue is self-sufficient but
   traceable.
6. **Write `TODO.md`** from the full set of newly-created issues, grouped by
   status (all new issues start as `todo` unless they're already in
   progress). If `TODO.md` already exists, merge — preserve existing entries,
   append new ones, and rebuild the grouping from the merged set.
7. **Write `issues/README.md`** only if it does not already exist. If it
   exists, leave it alone unless the convention itself is changing.
8. **Report back** with: number of issues created, the id range, the
   dependency edges, and any plan sections you deliberately merged or
   skipped and why. Do not summarize each issue's content — point the user
   at `TODO.md`.

## Edge cases

- **Plan references external docs/links:** copy the relevant snippet into
  `## Context` rather than relying on the link staying live. Cite the source.
- **Plan is ambiguous:** do not invent acceptance criteria. Create the issue
  with the unclear part noted under `## Context` and an acceptance criterion
  of `- [ ] Resolve ambiguity in <topic>`, flagged in your report-back.
- **Existing `issues/` with a different convention:** do not overwrite. Ask
  the user which convention to follow before writing anything.
- **User asks for a single big issue:** push back in the report-back if the
  work clearly spans multiple independent verifiable units, but honor the
  explicit request — create one issue and note the suggested splits in
  `## Notes`.

## What this skill does NOT do

- It does not create a database, install tooling, or add dependencies.
- It does not touch git (no commits, no branches) — that's the user's call.
- It does not edit the source plan document. The plan is an input only.
- It does not track time, estimates, or assignees. If the user wants those,
  add them as optional frontmatter fields by explicit request only.
