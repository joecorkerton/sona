---
name: work-on-issue
description: Use when the user wants to pick up a planned issue and start implementing it — phrases like "work on issue 004", "start 003", "pick up the home liveview issue", "implement the join issue", "begin this issue", "do issue 006", or when they reference an issue by id, filename, or path and ask you to implement it. Resolves one issue, verifies its dependencies are done, flips it to in-progress, implements the work against the acceptance criteria as a contract, checks off criteria as they land, keeps notes appended, and mirrors every status change in both the issue file frontmatter and the issues/TODO.md index. Edits code and issue files; does not commit.
---

# Work on an issue

Pick up **one** user-specified issue and implement it. The issue file is the
contract: `## Acceptance criteria` is a checklist the implementation must
land, and `## Goal` / `## Context` hold the intent. As work progresses, this
skill keeps the issue file itself (frontmatter `status`, the `- [ ]`
checkboxes, the append-only `## Notes`) and the `issues/TODO.md` index in
sync with reality.

This is the counterpart of `review` and `review-todo-issues` (both read-only)
and the active phase of `plan-to-issues` (which only creates the plan). Where
`plan-to-issues` writes issues, this skill *executes* them.

## Step 1 — Resolve the target issue

The repo tracks work as one markdown file per issue in `issues/` (see the
`plan-to-issues` skill for the full convention). The user gives you one issue
by any of:

- numeric id, with or without zero-padding: `4`, `004`;
- filename or filename stem: `004-home-liveview.md`, `004-home-liveview`;
- path, repo-relative or absolute: `issues/004-home-liveview.md`;
- name/slug keywords: `home`, `home liveview`, `home-liveview`, `create company`.

Resolve to exactly one file:

1. Glob `issues/*.md` (do NOT recurse into `issues/archive/` for candidates to
   start — archived issues are done). Build the candidate set of filenames
   plus their frontmatter `id` and `title`.
2. Match in this priority order, first hit wins:
   - exact filename match (with or without `.md`);
   - id match (strip leading zeros; compare against the frontmatter `id`);
   - repo-relative or absolute path match;
   - slug/keyword match: the query (kebab-cased, lowercased) is a substring of
     the filename slug OR of the lowercased `title`. Match generously here —
     "join" should hit `005-join-liveview`.
3. On resolution:
   - exactly one match → that's the target.
   - zero matches → tell the user what you looked for, list the issue files
     present with their ids/titles, and stop. Do not pick one for them.
   - more than one match → list the matches and ask which to work on. Do not
     start until they answer. Do not pick a default.

If the resolved file lives under `issues/archive/`, do not start work: its
frontmatter `status` is `done` and the work is already complete. Tell the
user, cite the file, and stop. If they want to reopen it, that's their call —
ask them to move it out of `archive/` and set `status: todo` first.

## Step 2 — Read the issue and validate preconditions

Read the target issue file in full. You need:

- frontmatter: `id`, `title`, `status`, `created`, `depends_on` (default `[]`).
- `## Goal` — the intended outcome,
- `## Context` — links to the source plan and prior work; read the referenced
  plan sections only if the issue itself is ambiguous. The issue is the
  contract, the plan is background,
- `## Acceptance criteria` — the `- [ ]` checklist (and any `- [x]` already
  done; you'll check off more as you land them),
- `## Notes` — running context that may clarify intent or record prior
  attempts you should not repeat.

Then validate preconditions before touching anything:

### 2a. Status check

- `status: todo` → good to start. This is the normal entry point.
- `status: in-progress` → someone (you, an earlier session, or the user) is
  already mid-implementation. Read `## Notes` to recover context. Tell the
  user the issue is already in-progress and you'll resume it, then proceed.
  Don't silently restart; resume.
- `status: blocked` → read `## Notes` for the blocker. If the blocker is
  resolved now, you will flip it to `in-progress` in Step 3 and proceed. If
  it's still blocked, tell the user the blocker, cite the note, and stop —
  don't start work you can't finish.
- `status: done` → the file should be in `archive/`. If it's not, flag the
  inconsistency and stop. Do not reopen a done issue without explicit user
  instruction.

### 2b. Dependency check

For each id in `depends_on` (default `[]`):

1. Find its issue file in `issues/` **or** `issues/archive/` (done deps live
   in the archive).
2. If no file matches the dep id anywhere → dangling dependency. Tell the
   user, cite the dep id, and stop. Do not start.
3. Read the dep's frontmatter `status`:
   - `done` → fine, this dep is satisfied.
   - `in-progress` or `blocked` → ordering risk. The target can't be
     verified until the dep lands. Tell the user which dep is still in flight,
     its status, and stop. Do not start.
   - `todo` → the dep hasn't started. Same as above: stop and surface it. An
     issue with unfinished deps cannot be verified against its acceptance
     criteria, so starting it produces unverifiable work.

Only proceed to Step 3 when `status` allows (todo, in-progress, or a
resolved blocked) **and** every dep is `done`. If you stopped, do not edit
the issue file — leave state as you found it.

### 2c. Dependency entity map (only if deps exist)

For each `done` dep, skim its `## Acceptance criteria` to know what entities
it created (modules, context functions, schemas, routes, migrations,
`live_session`s, PubSub topics, supervisors/registries). You will be writing
code against those APIs; you need to know the actual shape, not just that
the dep is "done". If the criteria are unclear, Read the relevant code
directly — the code is ground truth for what the dep produced. Do not review
the dep (that's `review-todo-issues`'s job); just learn what it created.

## Step 3 — Flip to in-progress (state transition)

Before writing any code, transition the issue to in-progress. This is the
"start work" step from the `issues/README.md` workflow: *set `status:
in-progress`, add a dated note*.

Edit the issue file:

1. In the YAML frontmatter, set `status: in-progress`. Do not touch `id`,
   `title`, `created`, or `depends_on`.
2. Under `## Notes` (append-only, newest at the bottom), add a new line:
   `- YYYY-MM-DD: started implementation — <one-line synopsis of what you're
   doing first>`. Use today's date from the session env. If resuming an
   in-progress issue, phrase it as a resume, e.g. `resumed — <next step>`.
3. Do **not** check off any acceptance criteria yet. Criteria are checked off
   in Step 5 only after the corresponding work actually lands and is
   verified.

Then update `issues/TODO.md` to mirror the new status. Rebuild the whole
index from the current set of issue files — don't surgically move one line
(per `plan-to-issues`: rebuild on status change). The target moves from
`## Todo` (or `## Blocked`) to `## In progress`. Keep all other entries as
they are.

State invariant from this point forward: **the issue file's `status` field
and the issue's line/section in `TODO.md` must always agree.** Every time
you change one, change the other in the same step.

## Step 4 — Implement

Read `AGENTS.md` in full before writing code — it is the codebase's style
and gotchas source of truth and the implementation must respect it. Then
work the acceptance criteria, treating the checklist as the contract.

Order of work:

1. **Skim the relevant existing code** to know the conventions in practice,
   not just as stated in `AGENTS.md`: how nearby LiveViews are structured,
   how contexts expose public functions, how migrations are named, how tests
   are written. Mimic what's there. Do not invent module names or route
   paths the issue doesn't ask for.
2. **Plan the change set** that will satisfy the criteria. Group criteria
   that land together (e.g. a migration + schema + context function often go
   together; a LiveView + its template + its test go together). You don't
   need to write the plan down — just hold it.
3. **Implement, criterion by criterion.** Use the project's tools: `mix
   ecto.gen.migration name_with_underscores` for migrations (per
   `AGENTS.md`), `to_form/2` for forms, LiveView streams (not lists) for
   collections, `push_navigate`/`push_patch` (never `live_redirect`), Req
   for HTTP, stdlib for date/time, predicate names ending in `?`, etc. Do
   not add deps the project doesn't already have unless an acceptance
   criterion explicitly requires it and `AGENTS.md` permits it.
4. **Write tests for public functions** (per the `AGENTS.md` rule that
   public functions are tested). Use `Phoenix.LiveViewTest` + `LazyHTML`
   for LiveViews, assert on element presence by id (never raw HTML), and
   drive forms with `render_submit/2` / `render_change/2` against the form
   ids you put in templates. Reference the IDs from templates.
5. **Preload associations** you access in templates (e.g. `message.user.email`).
   Missing preloads is a bug, not a style nit.
6. **Front end is mobile-first** (per `AGENTS.md`): usable at ~390px width,
   centered max-width on desktop. Don't desktop-first and retrofit.

As you land each unit of work, go to Step 5 to record progress before moving
to the next unit. Keep the issue file and the code in lockstep — never
accumulate a big untracked pile of code and then update the issue at the end.

## Step 5 — Record progress (per unit of work)

Each time a unit of work lands and you've verified it (test written and
passing, or — for non-testable work — manually confirmed), update the issue
file:

1. **Check off** the corresponding `- [ ]` criteria → `- [x]`. Only check off
   a criterion after the work for it is actually done and verified, not
   "should be done soon". Honesty here is what keeps the issue trustworthy.
2. **Append a dated note** under `## Notes` describing what landed: the
   files added/changed, the public functions introduced, and any decision or
   gotcha worth recording for the next session. One or two lines per unit.
   Never delete prior notes; cross out with `~~...~~` if superseded (per
   `plan-to-issues`).

You usually do **not** need to touch `TODO.md` here — the issue stays
`in-progress` and its line under `## In progress` doesn't change. Only
rebuild `TODO.md` when the `status` frontmatter changes (start → progress,
progress → blocked, progress → done, blocked → progress).

### Going blocked mid-work

If you hit a blocker you can't resolve (an unmet dep surfaces, an external
API changes, a criterion turns out to depend on work no issue covers):

1. Set `status: blocked` in the frontmatter.
2. Append a dated note describing the blocker precisely — what you tried,
   what's missing, what needs to happen to unblock. Future-you needs this.
3. Rebuild `TODO.md`: move the issue from `## In progress` to `## Blocked`.
4. Tell the user the blocker and stop. Do not leave the issue marked
   `in-progress` while you're not actively working it.

### Unblocking

When the blocker resolves (the dep landed, the API came back, the user
clarified), flip `status` back to `in-progress`, append a dated note
("unblocked — <what changed>"), rebuild `TODO.md` back to `## In progress`,
and resume Step 4.

## Step 6 — Finish

When every acceptance criterion is `- [x]`:

1. **Run `mix precommit`** (per `AGENTS.md`: use the `precommit` alias when
   done with all changes). Fix any issues it raises — formatter, credo,
   compile warnings, test failures. Re-run until clean. Do not skip this.
2. **Verify criteria once more** against the final code. A checked box that
   the code doesn't actually satisfy is worse than an unchecked one — go
   back and finish it.
3. **Set `status: done`** in the issue frontmatter.
4. **Append a final dated note**: `- YYYY-MM-DD: completed — all acceptance
   criteria met; mix precommit clean`.
5. **Move the issue file to `issues/archive/`**, preserving the filename
   exactly (per `plan-to-issues`: archive preserves the filename so
   cross-references in commit messages and other issues stay valid). Create
   `issues/archive/` if it doesn't exist.
6. **Rebuild `issues/TODO.md`**: remove the issue's line entirely (it's no
   longer open work). Keep the `(see archive/)` placeholder under `## Done`.
   Re-group the remaining issues under `## In progress` / `## Todo` / `##
   Blocked` from the current set of non-archived issue files.
7. **Report back** (see Step 7).

If `mix precommit` can't get clean and you can't justify the failure, do
**not** mark the issue done. Either fix it, or go blocked with a note, or
ask the user. A done issue implies clean precommit.

## Step 7 — Report

Report back concisely, in plain text:

1. **Issue** — `id — title`, final `status`, one-line goal summary.
2. **What landed** — 2–4 lines: files added/changed, public functions
   introduced, tests written. No code dumps.
3. **Acceptance criteria** — which are now checked, and confirm all are
   checked (the issue is done) or name any still open (it's not done).
4. **Precommit** — `mix precommit` result (clean, or what's pending).
5. **Issue tracking** — confirm the issue file is archived (if done) and
   `TODO.md` reflects the new state. Point the user at `TODO.md` for the
   next pick.

Keep it tight. Prefer specifics over prose. If you went blocked or stopped
early, say so plainly and say why.

## What this skill does NOT do

- It does not commit, branch, push, or open PRs. Edits files only; git is
  the user's call. (Matches the global opencode rule: never commit unless
  explicitly asked.)
- It does not pick an issue when the user's reference is ambiguous — it
  lists matches and asks. Never silently expand scope to a second issue.
- It does not start an issue whose `depends_on` are not all `done`, nor one
  that is `blocked` with an unresolved blocker. It surfaces and stops.
- It does not edit the source plan docs referenced under `## Context` —
  they're input only. (Same boundary as `plan-to-issues`.)
- It does not review a diff for bugs — that's `review`'s job. It implements;
  correctness self-checks via tests + `mix precommit`, not a diff review.
- It does not create new issues, split issues, or renumber. If the work
  exposes a missing issue, append a `## Notes` line suggesting it and let
  the user invoke `plan-to-issues` (or ask you to).
- It does not check off a criterion the code doesn't satisfy, and it does
  not mark an issue `done` while any criterion is still `- [ ]`.
- It does not skip `mix precommit` on the way to `done`.
- It does not reopen an archived/done issue without explicit user
  instruction to do so.