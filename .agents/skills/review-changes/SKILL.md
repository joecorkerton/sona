---
name: review-changes
description: Use when the user wants a review of uncommitted code changes — phrases like "review my changes", "review the diff", "review uncommitted work", "what's wrong with my diff", "check my work". Reviews the git diff of uncommitted changes, cross-references the in-progress issue in issues/, and reports bugs, technical issues, and discrepancies from the issue's acceptance criteria. Read-only: never edits files or commits.
---

# Review uncommitted diff

Review the code in the git diff of uncommitted changes against the active
in-progress issue, and report bugs, technical issues, and discrepancies
from the issue's acceptance criteria. This skill is **read-only**: never edit
files, stage, or commit. Surface findings; the user decides what to do.

## Step 1 — Find the active in-progress issue

The repo tracks work as one markdown file per issue in `issues/` (see the
`plan-to-issues` skill for the full convention). The current work is the
issue whose frontmatter has `status: in-progress`.

1. Glob `issues/*.md` (do NOT recurse into `issues/archive/` — archived
   issues are done and out of scope).
2. Read each candidate's frontmatter and pick the file(s) where
   `status: in-progress`. If there is exactly one, that's the active issue.
   - If zero are in-progress: tell the user there's no active in-progress
     issue and stop. Do not fall back to guessing or to `todo` issues.
   - If more than one is in-progress: tell the user which ones, ask which to
     review against, and stop until they answer. Do not review against all.
3. Read the active issue file in full. You need:
   - `## Goal` — the intended outcome,
   - `## Acceptance criteria` — the `- [ ]` checklist (and any `- [x]`
     already done),
   - `## Notes` — running context that may clarify intent,
   - `## Context` — links to the source plan, if you need to resolve
     ambiguity.

Do **not** read the source plan doc unless the issue's `## Context` is
insufficient to judge a discrepancy. The issue is the contract; the plan
is background.

## Step 2 — Capture the uncommitted diff

Run `git diff` in the repo root from a single Bash call. Use the form that
covers both unstaged and staged work without assuming either is empty:

```
git diff HEAD
```

- If that returns empty, try `git diff` and `git diff --staged` separately
  before concluding there is nothing to review — a fresh repo with no HEAD
  commits will make `git diff HEAD` fail. In that fallback, use
  `git diff --no-index -- /dev/null <new files>` is overkill; just use
  `git status` + `git diff` to show what's there.
- If there are untracked files relevant to the issue, `git status` will list
  them; mention that they're untracked and read them with the Read tool
  directly (do not try to diff untracked files — just read them).

Capture the full diff. If it's too large to read in one shot, read it in
file-by-file chunks by passing paths to `git diff -- <path>`. Do not skim;
the review is only as good as the diff you actually read.

## Step 3 — Read the changed code in context

A diff alone is misleading — you need to see the surrounding code. For each
file in the diff, Read the file (not just the hunk) so you can judge:

- whether the change fits the surrounding patterns and conventions,
- whether a removed line left a dangling reference,
- whether a new function is called anywhere, or dead on arrival,
- whether types/structs referenced still exist.

Follow the project's `AGENTS.md` conventions while reviewing — that file is
the source of truth for this codebase's style and gotchas. Do not flag
"violations" of conventions that `AGENTS.md` doesn't actually state.

## Step 4 — Review

Go through the diff line by line and identify, in three buckets:

### A. Bugs
Logic that is wrong or will fail at runtime. Examples: nil access where a
struct field is required, `if` blocks whose result isn't rebound (per
`AGENTS.md`), missing preloads on associations accessed in templates, forms
built from a raw changeset instead of `to_form/2`, LiveView streams used as
lists, `String.to_atom/1` on user input, pattern matches that can't succeed,
off-by-one or wrong-direction stream insertion, missing `phx-update` /
DOM id on a stream parent, forgotten `push_navigate`/`push_patch` where a
redirect is needed.

### B. Technical issues
Correctness-adjacent problems that won't necessarily crash but degrade the
result: missing `reset: true` on a stream re-render, missing
`stream_delete` on removal, an unused assign, a `case` that doesn't handle
a clause the code can reach, a test that asserts on raw HTML instead of
`has_element?/3`, a `Task.async_stream` without `timeout: :infinity` when
the work can exceed the default, N+1 queries from accessing un-preloaded
associations in a loop, shadowing an existing module name, leaving dead
code from the old version of a replaced function.

### C. Discrepancies from the issue
Work that the issue asked for and the diff does NOT do, or work the diff
does that the issue did NOT ask for. Map each open acceptance criterion
(`- [ ]`) to concrete diff hunks: which ones does this diff satisfy, which
are still untouched, which are partially done. If the diff adds scope
beyond the issue, call that out too — it's a discrepancy in the other
direction.

Be precise. Cite file paths and line numbers from the diff (e.g.
`lib/sona_web/foo_live.ex:42`) so the user can jump to the spot. Do not
speculate about code the diff didn't touch.

## Step 5 — Report

Report back in this exact structure, in plain text (no code edits, no
files written):

1. **Active issue** — the id, title, and a one-line summary of the goal,
   so the user knows what you reviewed against.
2. **Diff summary** — what changed, in 2–4 lines (files touched, rough
   scope). No code dumps.
3. **Bugs** — numbered list, each with file:line and a one-sentence
   description of the failure mode. If none, say "None found."
4. **Technical issues** — numbered list, same format. If none, say so.
5. **Discrepancies from the issue**:
   - **Satisfied by this diff** — list the acceptance criteria (by their
     text) that the diff appears to land.
   - **Partially done** — criteria where the diff moves toward but does
     not complete the goal, and what's missing.
   - **Not addressed** — criteria the diff doesn't touch at all.
   - **Out of scope** — diff changes not asked for by the issue.
6. **Verdict** — one of `Looks good to commit`, `Fix bugs first`,
   `Issue incomplete — finish the missing criteria`, or
   `Scope drift — reconcile with the issue`. Pick the single most
   important one; don't hedge.

Keep the whole report tight. Prefer specific file:line + one sentence over
paragraphs. If you found nothing wrong and the issue is fully satisfied,
say so — do not manufacture findings.

## What this skill does NOT do

- It does not edit files, run formatters, stage, or commit. Read-only.
- It does not run tests, `mix precommit`, or the compiler — those are the
  user's job after addressing findings. You may *suggest* running them.
- It does not create or update issues, check off criteria, or move files
  to `archive/`. That's the `plan-to-issues` skill's job.
- It does not review committed history or other branches — only the
  uncommitted diff against `HEAD`.
- It does not pick an issue when multiple are in-progress; it asks the
  user.
- It does not fall back to a `todo` issue or guess the active work from
  branch name, commit message, or recent file edits. The `status:
  in-progress` frontmatter is the only signal.
