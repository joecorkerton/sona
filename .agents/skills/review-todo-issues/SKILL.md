---
name: review-todo-issues
description: >-
  Use when the user wants to review all planned (open) todo issues in issues/ against the existing code as a reference point — phrases like "review the todo issues", "lint the open issues", "are the planned issues consistent with the code", "check all open issues against the codebase", "review the backlog". Reviews every issue whose status is not yet `done`, traverses the combined dependency graph, and reports stale code references, dependency bugs, conflicts between sibling issues, convention violations, and unverifiable criteria. Read-only: never edits files, issues, or code.
---

# Review all open (todo) issues against the existing code

Review the full set of not-yet-done planned issues against the existing
codebase, and report inconsistencies, bugs, and conflicts — both within each
issue and *across* the open set (who owns what, who collides with whom). The
existing code is the reference point (ground truth); the issues are what's
being reviewed. This skill is **read-only**: never edit files, issues, or
code. Surface findings; the user decides what to do.

This is the complement of the `review` skill. `review` inspects uncommitted
*code* against the active in-progress *issue*. This skill inspects the
*planned issues* against the *existing code* — it reviews the backlog, not a
diff. Do not confuse the two: if the user says "review my changes/diff", use
`review`. If they want the open backlog sanity-checked against the codebase,
use this skill.

## Step 1 — Collect the open issue set

The repo tracks work as one markdown file per issue in `issues/` (see the
`plan-to-issues` skill for the full convention).

1. Scan `issues/` (top level) for every `NNN-slug.md` file whose frontmatter
   `status` is **not** `done`. The default review set is every issue whose
   status is `todo`, plus any reached-but-not-done issues you'd otherwise
   need (`in-progress`, `blocked`) since their plans are still live and may
   collide with the `todo` set — include them too, but in your report clearly
   mark each issue's status. Ignore `archive/` for the *target* set: archived
   issues are `done` and are read only as dependencies (Step 2).
   - If `issues/` is empty or missing: say so and stop. Do not create issues
     or run `plan-to-issues` — that's the user's call.
   - If `legacy` exists: skip it.
   - If every non-archived issue is already `done` (so the open set is empty):
     say so and stop — there's nothing planned to review.
   - If the user narrowed the request (e.g. "review just the styling
     issues"): open that subset instead of the whole set, and say so
     explicitly.
2. Read every target issue file in full. For each you need:
   - frontmatter: `id`, `title`, `status`, `created`, `depends_on`
   - `## Goal` — the intended outcome,
   - `## Context` — links to the source plan and any prior work,
   - `## Acceptance criteria` — the `- [ ]` checklist (and `- [x]` done),
   - `## Notes` — running context that may clarify intent.
3. Build a working table of the set: `id`, `title`, `status`, direct
   `depends_on`. This table drives the rest of the review.

The targets are by definition not-started (`todo`) or in-flight, so Notes
below assume `todo`; adjust wording for `in-progress`/`blocked` cases.

## Step 2 — Traverse the combined dependency graph

Across the whole open set, resolve `depends_on` transitively so you know what
each issue's plan *assumes* its dependencies will have created. You need each
dependency's plan to verify those assumptions.

1. Take the union of every target issue's `depends_on` (default to `[]` if
   absent). For each dep id, find and read the dep issue file — from
   `issues/` **or** `issues/archive/` (done deps get archived). Recurse
   transitively: each dep may itself have `depends_on`. Build the full closure
   of deps for the whole set.
2. Record each dep's `id`, `title`, and `status` (`todo`, `in-progress`,
   `blocked`, `done`).
3. If a dep id in the closure matches no issue file anywhere (`issues/` or
   `issues/archive/`): that's a finding (bucket B) — a dangling reference.
   Note it but continue; treat the missing dep's "created entities" as empty.
4. Do not review the deps themselves as targets (deps that are already `done`
   are out of scope by Step 1). You read them only to know what they
   create/own and what conventions they imply, so you can judge whether the
   open set's assumptions about them are compatible.
   - Exception: a dep that is itself in the open set (a `todo`/`in-progress`/
     `blocked` issue that another open issue depends on) *is* one of your
     targets — but when checking a dependent's assumptions against it, compare
     only against that dep's own criteria, not a full review of it (which
     you'll do separately in Step 5).

If the whole set has no transitive deps, skip the rest of this step — there's
no chain to check.

## Step 3 — Build a map of what the existing code actually has

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
- `issues/TODO.md` and `issues/README.md` — the index and convention docs
  (check the index agrees with the actual file set / statuses).
- `AGENTS.md` — the codebase's conventions (the style/source-of-truth the
  issues should respect). Read it in full.

You don't need a full inventory — only enough to resolve every entity that
any target issue (or its deps) reference. Use Grep to confirm existence of
specific modules/functions/routes rather than reading every file.

Track these "existing entities" (the set the code actually has right now):
module names, context names + their public functions, schema names + their
fields, route paths, migration table names, LiveView modules, configured
PubSub topics, supervisors/registries, and any dep from `mix.exs`.

## Step 4 — Extract references from each target (and its deps)

For each target issue, parse its body for references to code-level entities:

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
This is the "dep creates X" set you'll match each target's assumptions against.

For each reference in a target, classify it as one of:

1. **Created by this issue** — the target's own acceptance criteria explicitly
   create it (e.g. criterion says "Add a `Sona.Messages` context with
   `list_messages/0`"). Fine.
2. **Created by a dependency** — a `depends_on` issue's (or a transitive
   dep's) criteria create it. Fine *if* the dep really does create it
   (verify against the dep's criteria from Step 2).
3. **Assumed to already exist** — the target uses it as if the codebase already
   has it, without any criterion (the target's own or a dep's) creating it.
   This is the case to scrutinize: verify it against the existing-entities map.

Don't over-parse prose. If a reference is ambiguous, note it as "assumed to
exist" rather than inventing a module.

## Step 5 — Review each target issue, then cross-check the set

Go criterion by criterion through each target issue, and identify findings in
six buckets. Then do a second pass across the *whole* open set for conflicts
between siblings (bucket C).

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

Check each target's `depends_on` and the transitive chain:

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
- A target that `depends_on` itself → bug.
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

### C. Conflicts with dependencies *and with sibling open issues

Check between each target and its deps **and** between the open issues
themselves (the set of issues whose plans intersect):

- A target and a dep, or two open targets, both claim to create/own the same
  module, context, schema, route, migration, or `live_session` → ownership
  conflict.
- Contradictory criteria between target and a dep, or between two open
  targets (e.g. one says "messages belong to a single room" but another's
  schema says `has_many :messages` on `Room`) → contradiction.
- Overlapping scope where the boundary between two issues is unclear (both
  add message persistence, both define the chat LiveView) → flag for the
  user to split/clarify. Assign explicit ownership or add a `depends_on` edge.
- A `depends_on` edge that runs the wrong way, or is missing where one is
  needed to prevent two issues from racing on the same entity → flag.

### D. Convention violations

A target's described approach conflicts with `AGENTS.md` conventions.
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
can jump to the spot. For B/C findings, also cite the dep issue id and the
dep criterion (or the sibling issue id) you're comparing against. Do not
speculate about code that no issue references or that isn't going to be
written.

## Step 6 — Report

Report back in this exact structure, in plain text (no code edits, no files
written):

1. **Issues reviewed** — the full set as a short table: each issue's
   `id — title` and `status` (one line each), so the user knows what was
   in scope. Then a one-line summary of the combined dependency graph: the
   deps touched (ids/titles + statuses) and any dangling ones (or "no
   dependencies" if the set has none).
2. **Code reference summary** — 2–4 lines on what the codebase currently has
   relevant to this set (e.g. "no domain contexts yet; only the Phoenix
   scaffold"). No code dumps.
3. **Findings per issue** — group by issue. For each issue, a header line
   `### 003 — <title> (status)`, then a numbered list of that issue's
   findings, each prefixed with its bucket letter (A–F), the specific
   criterion or reference (e.g. `criterion "Add list_rooms/0"` or `reference
   to Sona.Messages`), and a one-sentence description. For B/C findings, name
   the dep issue id or sibling issue id involved. If an issue has no findings,
   say "Clean." under its header.
4. **Cross-set findings** — a single numbered list of findings that span
   more than one issue (bucket C: ownership conflicts, contradictions, or
   unclear boundaries between open issues). Each entry names the issue ids
   involved. If there are none, say "No cross-set conflicts."
5. **Index health** — one or two lines noting whether `issues/TODO.md` agrees
   with the actual file set and statuses (missing/outdated entries, issues
   listed under the wrong status bucket, archived issues still listed, etc.).
   If the index is accurate, say "TODO.md is in sync."
6. **Verdict** — a per-issue verdict from the list below, then one overall
   verdict for the open set in a single final line. Per-issue verdict options:
   - `Issue is consistent with the codebase` (no findings, or only minor
     E/F notes).
   - `Fix stale code references first` (bucket A dominates).
   - `Dependency compatibility needs work` (bucket B dominates).
   - `Resolve conflicts with dependencies` (bucket C dominates).
   - `Tighten acceptance criteria` (bucket E dominates).
   - `Convention drift — align issue with AGENTS.md` (bucket D dominates).
   Pick the single most important one per issue; don't hedge. If two are
   equally severe, pick the one that would block starting work. The overall
   verdict summarizes the set (e.g. "Open set is broadly consistent; issues
   003 and 007 need a dependency edge added before work starts.").
7. **Suggested ordering** — an optional one-line ordering of the open issues
   that respects `depends_on` and lowers cross-set collision risk. Only
   include if the graph admits a clear linear order; otherwise say "No clean
   linear order — review the C findings."

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
- It does not review `done`/archived issues as targets. They are read only as
  dependencies, to verify open issues' assumptions about what they own.
- It does not deeply review the dependency issues themselves — it reads them
  only to verify the open issues' assumptions about what they create/own.
- It does not run tests, `mix precommit`, or the compiler. You may
  *suggest* running them.
- It does not implement the planned work or generate scaffolding.
- It does not invent conventions beyond what `AGENTS.md` states for bucket D.
- It does not edit the source plan docs referenced under `## Context`.