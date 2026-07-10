---
name: plan
description: Use when the user wants to create, write, or draft a project plan as a markdown document in plans/ — phrases like "create a plan", "write a plan", "plan this feature", "draft a plan for X", or when they describe work to be planned and ask for a plan doc. Writes a durable plan file under plans/ that can later be converted into tracked issues with plan-to-issues.
---

# Create a plan

Write a durable project plan as a markdown file under `plans/` in the repo
root. A plan is a design/spec document that captures intent, scope,
architecture, and implementation notes before work is broken into issues.
Plans are inputs to the `plan-to-issues` skill; they are not issue trackers
themselves.

## Directory layout

```
plans/
  README.md            # convention doc (write once, update rarely)
  <slug>.md            # one plan per file, kebab-case slug
  <another-slug>.md
```

- Filenames are `<kebab-case-slug>.md`. The slug is stable; do not rename
  when the plan title changes — update the title inside the file instead.
- Plans are long-lived documents. Prefer updating an existing plan over
  creating a duplicate unless the topic is genuinely new.

## Per-plan file format

```markdown
# Plan: <Title>

**In-repo copy:** [`plans/<slug>.md`](<slug>.md) (canonical for the project;
keep in sync when revising).

## Context

Why this plan exists, what problem it solves, links to relevant docs,
research, or prior plans. Keep it self-contained: anyone reading the plan
in six months should understand the backdrop.

## Goals

What the plan intends to achieve. Use bullet lists or tables. Distinguish
in-scope from out-of-scope if the boundary matters.

## Product / user flows (when applicable)

Step through the user-visible flows or major behaviors. Concrete examples
beat abstract descriptions.

## Architecture / design

Schemas, contexts, LiveViews, PubSub topics, supervisors, external APIs —
whatever the implementation shape looks like. Include diagrams (ASCII is
fine) if they help.

## Implementation notes

Migrations, naming conventions, edge cases, performance considerations,
security notes, deferred work. Anything that will matter when the plan is
converted to issues.

## Acceptance criteria / definition of done

Concrete, verifiable outcomes. These become the raw material for issue
acceptance criteria when the plan is converted.

## Open questions

Any ambiguities, decisions pending user input, or risks to resolve before
implementation starts.
```

## Step 1 — Resolve the plan topic and filename

The user gives a topic by any of:

- a direct description: "plan the group DM flows";
- a requested filename: `plans/ onboarding.md`;
- a path, repo-relative or absolute: `plans/basic-chat-poc.md`.

1. Read the request carefully. If the user gave a filename or path, use its
   slug. Otherwise, derive a concise kebab-case slug from the topic (e.g.
   "Group DM flows" → `group-dm-flows`).
2. Check whether `plans/<slug>.md` already exists:
   - If it exists and the user is asking to *revise* or *update* it, read it
     first and edit in place. Do not overwrite blindly.
   - If it exists and the user is asking for a *new* plan on the same topic,
     tell them the file exists and ask whether to update it or pick a new
     slug. Do not silently create `group-dm-flows-2.md`.
   - If it does not exist, create it.
3. If the slug would collide with `README.md` or `TODO.md`, pick a different
   slug.

## Step 2 — Gather context

Before writing, read enough of the codebase to ground the plan in reality:

1. Read `AGENTS.md` in full — it is the project's style and rules source of
   truth.
2. Read `README.md` and any docs in `docs/` that relate to the topic.
3. Read existing `plans/*.md` files that overlap the topic to avoid
   contradictions or duplication. Reference them in `## Context`.
4. If the plan touches existing code, skim relevant modules, schemas,
   migrations, routes, and tests to know the conventions in practice.
5. If the request is ambiguous or the scope is unclear, ask the user
   clarifying questions before writing — do not invent major product
   decisions.

## Step 3 — Draft the plan

Write the plan file using the format above. Guidelines:

- **Be concrete.** Prefer "user enters username and company name" over
  "implement onboarding".
- **Separate in-scope from out-of-scope.** This protects against scope creep
  when the plan becomes issues.
- **Capture architecture decisions** with enough detail that an implementer
  can reproduce the intent (module names, context boundaries, PubSub topics,
  unique indexes, etc.).
- **List acceptance criteria** as checkable bullets. These will be copied or
  refined into issue files later.
- **Note open questions** honestly. It is better to flag ambiguity than to
  invent an answer.
- **Link to source docs** using repo-relative paths so links stay valid.

Do not write code, migrations, or tests in this step. The plan is a design
artifact, not an implementation.

## Step 4 — Write or update the plans/ convention file

If `plans/README.md` does not exist, create it with the convention summary.
If it exists, leave it alone unless the convention itself is changing.

```markdown
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
```

## Step 5 — Report back

Report concisely:

1. **File written** — `plans/<slug>.md`.
2. **Topic / title** — one-line summary.
3. **What the plan covers** — 2–4 bullets: scope, key decisions, open
   questions.
4. **Next steps** — point the user at the file and mention that it can be
   converted into issues with `plan-to-issues` when ready.

## What this skill does NOT do

- It does not convert the plan into issues — that's `plan-to-issues`.
- It does not implement code, migrations, or tests.
- It does not touch `issues/`, `TODO.md`, or git.
- It does not silently overwrite an existing plan; it asks first.
- It does not invent product decisions the user needs to make — it flags
  them as open questions.
