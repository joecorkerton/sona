---
name: review-plan
description: >-
  Use when the user wants to review a specific plan in plans/ against the existing repo and its context — phrases like "review this plan", "check the plan for flaws", "lint the plan", "is this plan sound", "sanity-check the plan", "does this plan make sense", or when they reference a plan file (by name or path) and ask for a review. Reviews just that plan, cross-references its architecture/entities/routes/migrations/conventions against the actual code, the other plans, docs, and AGENTS.md, and reports flaws, omissions, internal inconsistencies, and design bugs. Read-only: never edits the plan, code, or issues.
---

# Review a specific plan against the existing repo

Review **one** user-specified plan against the existing codebase and the
repo's other context (`AGENTS.md`, other `plans/*.md`, `docs/`,
`README.md`, and any already-converted `issues/`), and report flaws,
omissions, internal inconsistencies, and design bugs. The existing code
and repo conventions are the reference point (ground truth); the plan is
what's being reviewed. This skill is **read-only**: never edit the plan,
code, or issues. Surface findings; the user decides what to do.

This is the plan-level complement of the `review-todo-issues` skill.
`review-todo-issues` inspects a planned **issue** against the code;
`review-plan` inspects a **plan** (a design doc in `plans/`) against the
code and wider repo context, **before** it's broken into issues. Do not
confuse them: if the user names an issue (by id or file), use
`review-todo-issues`. If they name a plan file (in `plans/`), use this
skill. If they say "review my changes/diff", use `review-changes`.

## Step 1 — Identify the target plan

The repo stores plans as one markdown file per plan in `plans/` (see the
`plan` skill for the full convention).

1. The user gives you one plan: by slug (`basic-chat-poc`), by filename
   (`basic-chat-poc.md`), or by path (`plans/basic-chat-poc.md`, repo-
   relative or absolute). Resolve it to exactly one file.
   - If `plans/` is empty or missing: say so and stop. Do not create a
     plan or run the `plan` skill — that's the user's call.
   - If the slug/filename matches no file: tell the user what you looked
     for, list the plan files present (`ls plans/*.md`, excluding
     `README.md`), and stop.
   - If the id is ambiguous (two files share a prefix, or the path points
     at a directory): list the matches and ask which.
   - The convention doc `plans/README.md` is **not** a plan; never review
     it as one. If the user points at it, tell them it's the convention
     file and stop.
2. Read the target plan file in **full** (all of it, not just the top).
   You need every section the plan is expected to have (see the `plan`
   skill), though the plan may omit some:
   - `## Context` — backdrop and links to docs/other plans,
   - `## Goals` (or `## Product goals`) — intended outcomes, in-scope vs
     out-of-scope,
   - `## Product / user flows` — user-visible behavior,
   - `## Architecture / design` — schemas, contexts, LiveViews, PubSub,
     supervisors, external APIs,
   - `## Implementation notes` — migrations, edge cases, deferred work,
   - `## Acceptance criteria / definition of done` — the `- [ ]` list,
   - `## Open questions` — ambiguities and risks (may be combined with
     `## Risks & deliberate non-goals`),
   - any `## Work chunks` / dependency-graph / "critical files" tables.

The target is a design doc, not an implementation; it is forward-looking
by definition. Review it as such.

## Step 2 — Read the repo context that grounds the plan

Before judging the plan, establish ground truth from the repo. Read and
scan:

- `AGENTS.md` — the codebase's conventions (the style/rules source of
  truth the plan should respect). Read it in **full**.
- `README.md` and any `docs/*.md` referenced by the plan's `## Context`
  (e.g. `docs/task-info.md`, `docs/market-research.md`). Verify each
  referenced doc actually exists; a dangling doc link is a finding.
- Other `plans/*.md` that overlap the target's topic. A new plan should
  not silently contradict a prior plan without acknowledging it; and a
  plan should not re-introduce a design a sibling plan already rules
  out. Only read enough of each sibling to judge overlap.
- `issues/` and `issues/TODO.md` — if the plan has already been (fully or
  partially) converted to issues by `plan-to-issues`, skim the issued
  list to see whether the plan's chunks already exist as tracked work.
  This is secondary context; only dig in if the plan claims an issue
  dependency or you spot a drift between plan and issues.

You don't need a full inventory — only enough to resolve every entity
the plan references. Use Grep to confirm existence of specific modules,
functions, routes, migrations, or PubSub topics rather than reading
every file.

## Step 3 — Build a map of what the existing code actually has

The code is the reference point for "already exists" claims. Scan:

- `mix.exs` — dependencies, aliases (esp. `precommit`).
- `lib/sona/*.ex` — contexts and schemas (what domain entities exist,
  their fields, associations, the public functions each context exposes).
- `priv/repo/migrations/*.exs` — what tables/columns exist in the DB.
- `lib/sona_web/router.ex` — routes and `live_session`s defined.
- `lib/sona_web/*_live.ex` and `*.html.heex` — LiveViews and templates
  that exist.
- `lib/sona_web/controllers/*.ex` — controllers that exist.
- `lib/sona_web/components/*.ex` — shared components.
- `lib/sona/application.ex` — supervisors, PubSub name, registries.
- `test/` — what's covered and what conventions the tests follow.

Track these "existing entities": module names, context names + their
public functions, schema names + their fields, route paths,
migration table names, LiveView modules, configured PubSub topics,
supervisors/registries, and any dep from `mix.exs`.

Distinguish three cases for every entity the plan references (this is the
heart of the review):

1. **The plan creates it** — the plan's own architecture/chunks/criteria
   introduce it. Fine; this is forward-looking and expected.
2. **A sibling/dependency plan creates it** — another `plans/*.md` (or,
   if already converted, an issue) introduces it. Fine *if* that sibling
   really does create it (verify against the sibling's architecture).
   Note the dependency if the plan doesn't mention it.
3. **The plan assumes it already exists** — the plan uses it as if the
   codebase already has it, without any part of the plan (or a sibling)
   creating it. This is the case to scrutinize: verify it against the
   existing-entities map. If it's not there and nothing creates it, it's
   a stale reference (bucket A) or an omission (bucket C) depending on
   severity.

Don't over-parse prose. If a reference is ambiguous, mark it "assumed to
exist" rather than inventing a module.

## Step 4 — Review the target plan

Work through the plan section by section (and cross-check across
sections), identifying findings in six buckets. **Forward-looking
references are fine** — a plan is allowed to describe code that doesn't
exist yet, as long as the plan itself (or a sibling) creates it. Only
flag when the plan either treats something as already-present that
isn't, or describes building something in a way that's internally
inconsistent, convention-violating, or technically broken.

### A. Stale repo references

The plan assumes an entity the existing code does not have, and no part
of the plan (or a cited sibling plan) creates it. Examples: the plan
says "extend `Sona.Messages`" but no `Sona.Messages` context exists and
the plan never introduces one; the architecture references a route
`/chat` that doesn't exist in the router and isn't going to be added;
the plan reuses `SonaWeb.CoreComponents.<thing>` that doesn't exist;
`## Context` links to `docs/foo.md` that doesn't exist in the repo.

Distinguish "stale" from "forward-looking": if the plan's own
architecture/chunks create the entity (or a sibling plan does), it's
forward-looking and fine. If the entity is claimed to exist *now* and
doesn't, it's stale.

### B. Design bugs (technical flaws baked into the plan)

Logic that will be wrong or race-prone once implemented, as written in
the plan. The plan is design-level, so this is about *directions* that
are doomed, not code typos. Examples: a single-insert-per-receiver
realtime rule that secretly inserts twice; a uniqueness scheme for
direct rooms that still allows the self-join / swapped-pair race the
plan claims to have eliminated; a unique index named in the schema that
can't actually enforce the invariant the plan states; a session rule
("set the cookie from the LiveView") that `AGENTS.md` / Phoenix makes
impossible (LiveView sockets are session read-only over the WebSocket);
a "unique per company" uniqueness made case-sensitive when the plan
also says normalize lowercase (so duplicate `Alex`/`alex` slip through);
a broadcast that happens before the write is committed (subscribers may
not see the row); a `find_or_create` that inserts without a uniqueness
constraint-backed rescue, so concurrent calls raise; sticking a
`base64` token in a `unique` column without making the column long
enough for its index; cross-context calls that the plan's own
architecture diagram forbids.

Only flag bugs the plan's own design implies. Don't invent code the
plan doesn't describe. Where the plan is ambiguous, say so (bucket E)
rather than asserting a bug.

### C. Omissions

Things the plan's **own goals/criteria/flows** imply but the plan never
addresses. The plan sets a contract with itself; gaps in that contract
are omissions. Examples: the acceptance criteria list "self-DMs are
rejected" but no flow/context function/architecture describes the
rejection; the schema table is drawn without a column a later flow
relies on; the data model has no index a stated query path needs; the
"critical files" table omits a file the architecture section calls out
by name; the work chunks leave a criterion uncovered by any chunk; the
dependency graph has a chunk depending on a deliverable no earlier chunk
produces; the plan mentions `list_company_users/1` is "required" for the
DM picker but no chunk's deliverables list it; a flow describes a
controller action but no route row exists in the route table, and no
chunk adds it.

Distinguish omission from out-of-scope: if the plan **explicitly** defers
something (in `## Risks & deliberate non-goals` or `## Open questions`),
it is not an omission — it's a deliberate cut. Only flag things the plan
implies it will deliver but doesn't.

### D. Convention violations

The plan's described approach conflicts with `AGENTS.md` conventions.
Examples: planning LiveView collections as lists instead of streams;
forms from raw changesets instead of `to_form/2`; `String.to_atom/1` on
user input; predicate functions named `is_*`; adding `httpoison`/`tesla`
instead of `Req`; adding a date/time dep the stdlib covers; nesting
modules in one file; a `scope` route with a redundant `alias`;
`live_redirect`/`live_patch` mentioned instead of `push_navigate`/
`push_patch` or `<.link navigate>`; planning `phx-update="append"` on a
stream; `Phoenix.View` mentioned as if it exists; starting a
supervisor/registry in `application.ex` without a name; raw `<script>`
in HEEx instead of a colocated hook; a `<.flash_group>` placed outside
`Layouts`.

Only flag conventions `AGENTS.md` actually states. Do not invent style
rules. Where the plan is silent (neither follows nor violates), don't
flag.

### E. Internal inconsistencies & unverifiable / vague criteria

The plan must agree with itself and across its sections.

Inconsistencies:
- `## Goals` says one thing; the architecture or acceptance criteria ask
  for another (e.g. goals list DMs in-scope but no flow/chunk delivers
  DMs).
- The architecture diagram shows one layering but the implementation
  notes violate it (e.g. diagram says "LiveViews never touch Repo" but
  a chunk's deliverable calls `Repo` from a LiveView).
- The acceptance criteria demand a behavior the flows don't show, or vice
  versa (flows show a path the criteria don't cover).
- Cross-context coordination claims that don't hold (plan says "no
  context calls the other" but a chunk's deliverable has one context
  call the other).
- The dependency graph contradicts the chunks' stated `Depends on:`
  lines, or a "parallel" claim is actually serial.
- The plan reuses an existing entity under a name that already means
  something else in the code (module shadowing).
- Schema invariants the plan states (e.g. "direct rooms have exactly two
  memberships") aren't enforced by any migration/constraint/context
  rule the plan describes — a stated invariant with no enforcement is a
  soft inconsistency; flag it, don't insist it be a DB constraint if the
  plan says app-enforced.
- Acceptance criteria duplicate each other or the `## Goals` verbatim.

Vague / unverifiable:
- Acceptance criteria that aren't checkable ("make it nice", "good UX",
  "works on phone" without a width or behavior).
- `## Open questions` that are actually decisions the user needs to make
  **now** for the plan to be implementable (a plan blocking on a "later"
  decision that gates a whole chunk).
- Goals/flows so abstract an implementer can't reproduce the intent.
- `## Risks & deliberate non-goals` that contradict an in-scope goal.

Be precise. Cite the section heading (or the criterion text) and the
conflicting section so the user can jump to the spot. Where two sections
genuinely say the same thing two ways (not a conflict), don't flag.

### F. Cross-plan / cross-issue drift (when the plan has siblings)

If the plan overlaps other `plans/*.md` (compare `## Context` references
and `## Architecture`):

- The plan silently contradicts a sibling plan's stated direction (e.g.
  sibling says "no sessions, token-only"; target assumes session
  cookies) without noting the shift.
- The plan re-creates an entity a sibling already owns (two plans both
  define `Sona.Chat.send_message/3` with different signatures) →
  ownership conflict for when both convert to issues.
- If the plan has already been converted to `issues/`: flag any drift
  between the plan's chunks/criteria and the issues that came out of it
  (missing issue for a chunk, criterion lost in translation, dependency
  edge in the plan that the issues' `depends_on` don't carry). This is
  secondary — only report what you can verify from a quick scan.

If the plan has no siblings and isn't yet converted to issues, skip
this bucket.

## Step 5 — Report

Report back in this exact structure, in plain text (no code edits, no
files written):

1. **Plan reviewed** — the plan's title (from the `# Plan:` heading) and
   filename, plus a one-line summary of the goal, so the user knows what
   was reviewed. Then a one-line summary of repo context used: which
   sibling plans / docs / issues (if any) were cross-referenced, or
   "no sibling plans; reviewed against code + AGENTS.md".
2. **Code reference summary** — 2–4 lines on what the codebase currently
   has relevant to this plan (e.g. "stock Phoenix scaffold; no domain
   contexts; no migrations; PubSub started as `Sona.PubSub`"). No code
   dumps.
3. **Findings** — a single numbered list, each item prefixed with its
   bucket letter (A–F), the specific section/criterion/reference (e.g.
   `architecture "Data model"` or `acceptance criterion "Self-DMs are
   rejected"` or `reference to Sona.Messages`), and a one-sentence
   description. For F findings, name the sibling plan / issue id
   involved. If the plan has no findings, say "Clean."
4. **Verdict** — one of:
   - `Plan is sound` (no findings, or only minor E/F notes).
   - `Fix stale repo references first` (bucket A dominates).
   - `Rework design bugs` (bucket B dominates).
   - `Fill the omissions` (bucket C dominates).
   - `Align plan with AGENTS.md` (bucket D dominates).
   - `Reconcile internal inconsistencies / tighten criteria` (bucket E
     dominates).
   - `Reconcile with sibling plans / converted issues` (bucket F
     dominates).
   Pick the single most important one; don't hedge. If two are equally
   severe, pick the one that would block implementation starting.

Keep the whole report tight. Prefer specific section + one sentence over
paragraphs. If you found nothing wrong, say so plainly — do not
manufacture findings. A plan that's forward-looking and self-consistent
should come back "Clean."

## What this skill does NOT do

- It does not edit the plan, code, issues, or `TODO.md`. Read-only.
- It does not create, delete, or refile plans; it does not run
  `plan-to-issues`. That's the user's call.
- It does not implement the plan, scaffold code, or write migrations.
- It does not review an uncommitted diff — that's `review-changes`.
- It does not review a planned **issue** deeply — that's
  `review-todo-issues`. It only scans `issues/` for drift when a plan has
  already been converted.
- It does not review more than one plan. The user gives one plan; if they
  want several reviewed, they invoke the skill once per plan. Do not
  silently expand scope.
- It does not run tests, `mix precommit`, or the compiler. You may
  *suggest* running them.
- It does not invent conventions beyond what `AGENTS.md` states for
  bucket D.
- It does not flag forward-looking references (entities the plan creates
  that don't exist yet); that's the whole point of a plan.