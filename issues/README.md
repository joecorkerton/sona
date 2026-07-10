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