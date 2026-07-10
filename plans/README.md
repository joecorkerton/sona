# plans/

Project planning documents. One markdown file per plan. Plans are design
inputs to the `plan-to-issues` skill, which converts them into tracked work
in `issues/`.

## Layout
- `<kebab-case-slug>.md` — one plan per file
- `README.md` — this convention doc

## Plan sections (in order)
1. `## Context` — backdrop and links
2. `## Goals` — intended outcomes
3. `## Product / user flows` — user-visible behavior
4. `## Architecture / design` — implementation shape
5. `## Implementation notes` — migrations, edge cases, deferred work
6. `## Acceptance criteria / definition of done` — verifiable outcomes
7. `## Open questions` — ambiguities and risks

## Workflow
- Create a new plan: write `<slug>.md`, update `README.md` if missing.
- Revise a plan: edit the file in place; keep the `## Notes` section
  append-only if you add one.
- Convert to work: pass the plan file to `plan-to-issues`.
