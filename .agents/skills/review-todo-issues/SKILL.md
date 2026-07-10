---
name: review-todo-issues
description: Use when the user wants to review a specific planned issue in issues/ against the existing code as a reference point — phrases like "review issue 003", "check this issue for bugs", "lint this issue", "is this issue consistent with the code", "review this planned work", "check this issue against the codebase". The user gives one issue (by id, filename, or path); the skill reviews just that issue, traversing its depends_on chain to verify dependency compatibility, and reports stale code references, dependency bugs, conflicts with dependencies, convention violations, and unverifiable criteria. Read-only: never edits files or issues.
---

# Review a specific issue against the existing code

Review **one** user-specified issue against the existing codebase, and report
inconsistencies, bugs, and conflicts. The existing code is the reference
point (ground truth); the issue is what's being reviewed. This skill is
**read-only**: never edit files, issues, or code. Surface findings; the
user decides what to do.

This is the complement of the `review` skill. `review` inspects uncommitted
*code* against the active in-progress *issue*. This skill inspects a
*planned issue* against the *existing code* — it reviews the plan, not a
diff. Do not confuse the two: if the user says "review my changes/diff", use
`review`. If they name a specific issue (by id or file) and want it sanity-
checked, use this skill.

## Step 1 — Identify the target issue

The repo tracks work as one markdown file per issue in `issues/` (see the
`plan-to-issues` skill for the full convention).

1. The user gives you one issue: by numeric id (`003`, `3`), by filename
   (`003-slug.md`), or by path (`issues/003-slug.md`). Resolve it to exactly
   one file.
   - If `issues/` is empty or missing: say so and stop. Do not create issues
     or run `plan-to-issues` — that's the user's call.
   - If the id/filename matches no file: tell the user what you looked for,
     list the issue files present, and stop.
   - If the id is ambiguous (shouldn't happen with NNN prefixing, but guard
     anyway): list the matches and ask which.
2. Read the target issue file in full. You need:
   - frontmatter: `id`, `title`, `status`, `created`, `depends_on`
   - `## Goal` — the intended outcome,
   - `## Context` — links to the source plan and any prior work,
   - `## Acceptance criteria` — the `- [ ]` checklist (and `- [x]` done),
   - `## Notes` — running context that may clarify intent.

The target is typically a `todo` issue (planned, not started), but the skill
accepts any status — you're reviewing the *plan*, not an implementation.
Notes below assume `todo`; adjust if it's `blocked` or `done`.

## Step 1b — Traverse the dependency chain

`depends_on` lists issue ids that must be `done` before the target starts.
You need each dependency's plan to verify the target's assumptions about what
those deps will create.

1. Read the target's `depends_on` list (default to `[]` if absent). For each
   dep id, find and read the dep issue file in full — from `issues/` **or**
   `issues/archive/` (done deps get archived). Recurse transitively: each dep
   may itself have `depends_on`. Build the full closure of deps for the target.
2. Record each dep's `id`, `title`, and `status` (`todo`, `in-progress`,
   `blocked`, `done`).
3. If a dep id in the closure matches no issue file anywhere (`issues/` or
   `issues/archive/`): that's a finding (bucket B) — a dangling reference.
   Note it but continue; treat the missing dep's "created entities" as empty.
4. Do not review the deps themselves as targets. You read them only to know
   what they create/own and what conventions they imply, so you can judge
   whether the target is compatible with them.

If the target has no `depends_on` and no transitive deps, skip the rest of
this step — there's no chain to check.

## Step 2 — Build a map of what the existing code actually has

The code is the reference point. Establish ground truth. Read and scan:

- `mix.exs` — dependencies, aliases (esp. `precommit`).
- `lib/sona/*.ex` — contexts and schemas (what domain entities exist, their
  fields, associations, the public functions each context exposes).
- `priv/repo/migrations/*.exs` — what tables/columns exist in the DB.
- `lib/sona_web/router.ex` — routes and `live_session`s defined.
- `lib/sona_web/*_live.ex` and `*.html.heex` — LiveViews and templates that
  exist.
- `lib/sona_web/components/*.ex` — shared components.
- `test/` — what's covered and what conventions the tests follow.
- `AGENTS.md` — the codebase's conventions (the style/source-of-truth the
  issue should respect). Read it in full.

You don't need a full inventory — only enough to resolve every entity the
target issue (and its deps) reference. Use Grep to confirm existence of
specific modules/functions/routes rather than reading every file.

Track these "existing entities" (the set the code actually has right now):
module names, context names + their public functions, schema names + their
fields, route paths, migration table names, LiveView modules, configured
PubSub topics, supervisors/registries, and any dep from `mix.exs`.

## Step 3 — Extract references from the target (and its deps)

Parse the target issue's body for references to code-level entities:

- Module/context names, e.g. `Sona.Messages`, `Sona.Messaging`, `Sona.Accounts`.
- Schema names, e.g. `Sona.Messages.Message`, `%Message{}`.
- Public functions, e.g. `Sona.Messages.list_messages/0`, `create_message/1`.
- File paths, e.g. `lib/sona/events/message.ex`, `lib/sona_web/live/chat_live.ex`.
- Route paths, e.g. `/chat`, `/messages`, `/admin/users`.
- LiveView modules, e.g. `SonaWeb.ChatLive`.
- DB tables/columns/migrations implied by criteria ("a `messages` table",
  "an `inserted_at` column", "a migration adding `read_at`").
- Dependencies/deps, e.g. "use Req to fetch", "add `phoenix_pubsub`" (check
  `mix.exs`).

Also parse each dependency issue's body for the entities its criteria
*create* or *own* (modules, schemas, routes, migrations, context functions).
This is the "dep creates X" set you'll match the target's assumptions against.

For each reference in the target, classify it as one of:

1. **Created by this issue** — the target's own acceptance criteria explicitly
   create it (e.g. criterion says "Add a `Sona.Messages` context with
   `list_messages/0`"). Fine.
2. **Created by a dependency** — a `depends_on` issue's (or a transitive
   dep's) criteria create it. Fine *if* the dep really does create it
   (verify against the dep's criteria from Step 1b).
3. **Assumed to already exist** — the target uses it as if the codebase already
   has it, without any criterion (the target's own or a dep's) creating it.
   This is the case to scrutinize: verify it against the existing-entities map.

Don't over-parse prose. If a reference is ambiguous, note it as "assumed to
exist" rather than inventing a module.

## Step 4 — Review the target issue

Go criterion by criterion through the target issue, and identify findings in
six buckets:

### A. Stale code references

The target assumes an entity the existing code does not have, and no criterion
(the target's own or a dependency's) creates it. Examples: the target says
"extend `Sona.Messages`" but no `Sona.Messages` context exists yet; the
criteria use `Sona.Accounts.User` but there's no `Accounts` context and no
dep creates one; the target references a route `/chat` that doesn't exist in
the router and isn't going to be added by the target or a dep.

Distinguish "stale" from "forward-looking": if the target's own criteria or a
dep's criteria create the entity, it's forward-looking and fine. If the
entity is claimed to exist *now* and doesn't, it's stale.

### B. Dependency bugs (compatibility along the chain)

Check `depends_on` and the transitive chain for the target:

- A dep id that no issue file has anywhere (`issues/` or `issues/archive/`) →
  dangling reference, bug.
- A dep that is still `todo`, `in-progress`, or `blocked` → ordering risk:
  the target can't start until it's `done`. Flag the dep's id and current
  status. Note: a dep being `done` is the expected precondition; a dep still
  in flight is a "not yet" finding, not a hard bug.
- A dep marked `done` but whose created entity is **missing** from the code →
  real bug. The dep claims to be complete, the code doesn't have what it was
  supposed to create. Either the dep was mis-marked done, or the work
  regressed. Cite the dep issue id and the missing entity.
- Circular dependency (the chain leads back to the target: target → dep →
  ... → target) → bug.
- The target that `depends_on` itself → bug.
- **Compatibility mismatch** — the target assumes a dep creates entity X with
  shape Y, but the dep's criteria actually create X with a different shape,
  or create something near-but-not X, or don't create X at all (only claim
  to). Verify each entity the target imports from a dep against the dep's
  actual criteria. Examples: target uses `Sona.Messages.list_messages/0` but
  the dep only defines `list_messages/1` with a room arg; target expects a
  `Message` schema with `:room_id` but the dep's schema has `:room` (an assoc
  rather than an fk); target expects `:inserted_at` on a table the dep's
  migration doesn't add. Each mismatch is a finding.
- Missing dependency: the target assumes an entity only another issue creates,
  but doesn't list that issue in `depends_on` → flag (the dep graph is wrong).

### C. Conflicts with dependencies

Between the target and its deps (the set of issues whose plans intersect the
target's):

- The target and a dep both claim to create/own the same module, context,
  schema, route, migration, or `live_session` → ownership conflict.
- Contradictory criteria between target and a dep (e.g. target says "messages
  belong to a single room" but a dep's schema says `has_many :messages` on
  `Room`) → contradiction.
- Overlapping scope where the boundary between the target and a dep is unclear
  (both add message persistence, both define the chat LiveView) → flag for the
  user to split/clarify.

### D. Convention violations

The target's described approach conflicts with `AGENTS.md` conventions.
Examples: planning LiveView collections as lists instead of streams; forms
from raw changesets instead of `to_form/2`; `String.to_atom/1` on user
input; predicate functions named `is_*`; adding `httpoison`/`tesla` instead
of `Req`; adding a date/time dep the stdlib covers; nesting modules in one
file; a `scope` route with a redundant `alias`; a `live_redirect`/`live_patch`
mentioned instead of `push_navigate`/`push_patch`; planning
`phx-update="append"` on a stream; `Phoenix.View` mentioned as if it exists.

Only flag conventions `AGENTS.md` actually states. Do not invent style rules.

### E. Unverifiable or ambiguous criteria

Acceptance criteria should be concrete and checkable (per `plan-to-issues`).
Flag:

- Criteria that describe investigation, not outcome ("explore X",
  "look into Y") — these belong in `## Notes` or `## Context`, not as
  acceptance criteria.
- Criteria that describe *how* not *what* in a way that locks implementation
  unnecessarily — note, don't insist.
- Criteria so vague they can't be checked ("make it nice", "good UX").
- An issue with no acceptance criteria at all, or only one trivial criterion.
- Criteria that duplicate each other or the `## Goal` verbatim.

### F. Goal/Context/Notes inconsistencies

- `## Goal` says one thing; the acceptance criteria ask for another.
- `## Context` links to a plan section that doesn't match the criteria's
  direction.
- `## Notes` contradicts the criteria or goal (e.g. a note says "we decided
  against X" but a criterion still asks for X).
- frontmatter `title` doesn't match the actual work described.
- `id` in frontmatter doesn't match the filename prefix; slug renamed
  (filename slug should be stable per `plan-to-issues`).

Be precise. Cite the target issue id and the specific criterion / note, and
the code reference (file path or "grep for X found no matches") so the user
can jump to the spot. For bucket B/C findings, also cite the dep issue id
and the dep criterion you're comparing against. Do not speculate about code
that the issue doesn't reference or that isn't going to be written.

## Step 5 — Report

Report back in this exact structure, in plain text (no code edits, no files
written):

1. **Issue reviewed** — the target issue's `id — title`, its `status`, and a
   one-line summary of the goal, so the user knows what was reviewed. Then a
   one-line summary of the dependency chain: the list of dep ids/titles and
   their statuses (or "no dependencies" if none).
2. **Code reference summary** — 2–4 lines on what the codebase currently has
   relevant to this issue (e.g. "no domain contexts yet; only the Phoenix
   scaffold"). No code dumps.
3. **Findings** — a single numbered list, each item prefixed with its bucket
   letter (A–F), the specific criterion or reference (e.g. `criterion "Add
   list_rooms/0"` or `reference to Sona.Messages`), and a one-sentence
   description. For B/C findings, name the dep issue id involved. If the
   issue has no findings, say "Clean."
4. **Verdict** — one of:
   - `Issue is consistent with the codebase` (no findings, or only minor
     E/F notes).
   - `Fix stale code references first` (bucket A dominates).
   - `Dependency compatibility needs work` (bucket B dominates).
   - `Resolve conflicts with dependencies` (bucket C dominates).
   - `Tighten acceptance criteria` (bucket E dominates).
   - `Convention drift — align issue with AGENTS.md` (bucket D dominates).
   Pick the single most important one; don't hedge. If two are equally
   severe, pick the one that would block starting work.

Keep the whole report tight. Prefer specific criterion + one sentence over
paragraphs. If you found nothing wrong, say so plainly — do not manufacture
findings.

## What this skill does NOT do

- It does not edit files, issues, criteria, or code. Read-only.
- It does not create, delete, or refile issues, update `TODO.md`, check off
  criteria, or move files to `archive/`. That's the `plan-to-issues` skill's
  job.
- It does not review an uncommitted diff against an issue — that's the
  `review` skill's job.
- It does not review more than one issue. The user gives one issue; if they
  want several reviewed, they invoke the skill once per issue. Do not
  silently expand scope.
- It does not deeply review the dependency issues themselves — it reads them
  only to verify the target's assumptions about what they create/own.
- It does not run tests, `mix precommit`, or the compiler. You may
  *suggest* running them.
- It does not implement the planned work or generate scaffolding.
- It does not invent conventions beyond what `AGENTS.md` states for bucket D.
- It does not edit the source plan docs referenced under `## Context`.