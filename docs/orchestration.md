# Larger changes: plan, delegate, review, report

Use this workflow for work spanning several PRs or requiring several design decisions. For a small
change, follow `CLAUDE.md` and the checks in `.github/workflows/ci.yml`. This guide adapts evo's
orchestration workflow to FPC's Rails, React, Sidekiq, and RubyLLM application.

## Roles

- **Owner:** decides scope, product trade-offs, and defaults; approves the plan and says when to merge.
- **Orchestrator:** Claude Code in the owner conversation. It writes and is the only editor of the
  execution plan, briefs agents, watches their progress, records decisions and learnings, and reports.
- **Step agent:** a fresh Claude Code subagent for one step. It implements, checks, commits without
  pushing, and reports. It does not edit the execution plan.
- **Reviewer:** a fresh subagent with no implementation context. It reviews the plan, commit, or whole
  branch and reports findings without modifying the implementation.

Work in one checkout and run one agent at a time: token use matters more than speed on this side
project. Finish a step and its review before starting the next dependent step.

## The run

### 1. Agree the work

Read `CLAUDE.md`, the relevant code, and any existing design documents in `docs/`. Ask about unresolved
scope, product trade-offs, and defaults before implementation. Record owner decisions with the date
and the owner's words, including any authorization already given; do not ask for it again.

For FPC, identify which user data must remain unchanged, what aggregation may change, who may use the
feature, and whether it affects jobs, API clients, or stored agent transcripts. The collection and
aggregation goals in `README.md` matter when changing clustering or normalizing names. Decide routine
implementation details yourself and explain them in the plan and PR descriptions.

### 2. Write the execution plan

Write `plans/NAME.md` in the repository checkout. `/plans/` is gitignored: the plan survives an interrupted session
without entering history. Keep lasting design decisions and runbooks in the existing `docs/` files;
do not replace or delete those tracked plans. Give every subagent the execution-plan path.

The plan holds:

- The goal, acceptance criteria, and behavior that must remain unchanged.
- Owner decisions and any approval given in advance. Give requests outside the implementation scope
  a destination, such as a documentation change in a named PR.
- Design premises, each checked in the code that implements it and cited as `file:line`. Reading a
  config or an older plan alone is insufficient.
- Your design decisions, including the exact destination and ordering of moved code or checks.
- A checklist grouped by PR, in dependency order. Each step fits one agent and one or two commits,
  names its acceptance checks, and identifies dependencies. Each PR must work when merged on its own.
- Migration, rollout, and rollback requirements where relevant, including compatibility between
  deployed code, queued jobs, and stored data. Mark actions that need separate owner authorization.
- Measurements that inform defaults or documented claims, marked **[quiet]** for machine timings or
  **[paid]** for live provider calls, with the workload, data source, and spending limit.
- Earlier review findings and their disposition, including declined findings and reasons.
- A learnings log, updated as work happens: what worked, tool quirks, mistakes, and process changes.
- Out-of-scope items raised by agents or reviewers, with who raised them, the step, the location or
  command, and why fixing them would help. Include tooling and documentation problems as well as code.

Finish the last code PR with an application smoke check. Then schedule a review of the process and
its documentation, and finally cleanup after all PRs merge. Update docs in the PR that makes them
stale. Repository docs, comments, and commits cite commit IDs and GitHub PR numbers rather than
temporary step labels that disappear with the execution plan.

### 3. Review the plan

Have a fresh subagent review the whole plan before implementation. Give it the owner decisions,
declined findings, relevant design documents, and the [review rules](#review-rules). Ask it to check
missing cases, migration and deployment order, stale docs, and the measurement methods themselves.

Verify assumptions where the application actually uses them: request authorization, worker retries,
transaction boundaries, PostgreSQL constraints, frontend response shapes, and RubyLLM tool names and
transcript restoration. Run a small isolated check when reading alone cannot settle an assumption.
Check performance designs with representative data sizes. Live provider calls follow the same
authorization and budget rules as later measurements.

Fold findings into the plan. If a finding changes the design, have another fresh reviewer review the
whole plan. Continue until a round has no blocker or important finding. Include the plan-specific
severity rule in every brief so implementation details that the planned tests will settle do not
cause unnecessary rounds.

### 4. Get the owner's approval

Show the plan in plain language, explaining mechanisms with examples where useful. Wait for approval
before implementation unless the owner already authorized starting after review. Record that
approval. A later change to the approved scope, approach, or invariants needs another whole-plan
review and owner approval before dependent code is written. Routine implementation choices stay with
the orchestrator.

### 5. Build the PRs in order

Finish each PR's steps, whole-branch review, and CI before branching the next dependent PR from it.
Create each branch from its intended base in the current checkout. For dependent PRs, follow
[Stacked PRs](#stacked-prs).

**Steps.** Give each step to a fresh agent with the [step brief](#step-brief). When it reports, check
the result against every plan clause that names the step, including design decisions. Record commit
IDs, check results, decisions, what later steps need to know, learnings, and out-of-scope items. Tick
the step only when its acceptance criteria hold. If it must stop for your choice halfway through,
record the choice and resume the same agent; use a fresh brief if that agent is unavailable.

**Per-commit review.** Before later steps depend on a code commit, have a fresh reviewer check it.
Fix blockers and important findings first, preferably with the agent that wrote the step once no
other agent is writing to its tree. Use a new commit when another branch depends on the old one.
Docs-only commits and a PR's last independent commit need only the whole-branch review. Put a nit
about lines a later step will rewrite into that step's brief.

**Whole-branch review and PR.** Bring the branch up to date with its intended base (`master` or the
previous PR's branch). Search the repository for stale names, docs, callers, and readers of any data
being removed. Review the entire change against that base, including uncommitted changes. Repeat the
[review loop](#review-rules) after fixes. Run the full checks in `CLAUDE.md`, commit the intended
files, inspect the final diff, then push and open the PR when authorized by the owner's request.

Use `gh pr checks PR --watch` to wait for CI. Verify that the checks belong to the pushed commit, that
all required checks passed (a skipped or pending check is not a pass), and that the PR has no base
conflict. FPC CI checks RSpec, Vitest and lint, and the production Docker build; read the current
workflow rather than copying evo's mise tasks or assuming additional reviewers are installed. After
a later change, repeat the whole-branch review and the affected checks, then verify CI again.

**Application smoke checks.** At the end of the last code PR, exercise the changed path in an
isolated development environment: a request or browser flow through the backend and React UI, or a
job through its worker and persistence layer. Check access rules and failure behavior as appropriate.
For migrations, test the planned upgrade and rollback strategy on disposable data. For agent changes,
check tool execution, transcript restoration, usage recording, and error handling. Use replay or
stubbed provider responses by default; live evaluations require the agreed data and spending limit.
Report results that argue against the design as well as those that support it.

**Process review.** Give a fresh step agent the learnings log. Have it review this guide and
`CLAUDE.md` as a whole, keeping general rules with their reasons and putting repository facts in the
relevant reference docs. If useful changes result, open a final docs PR with review and CI. Do not
create a PR just to record one-off events.

### 6. Report

Report when all authorized PRs, including any final docs PR, are open and green. Explain what each
does, findings and their resolution, decisions you made, smoke checks and measurements, rollout
requirements, and anything still open. If opening PRs is not authorized or a check is blocked, report
the concrete prepared result and remaining requirement accurately. Do not merge without authorization:
merging into `master` triggers FPC's production deployment.

Before reporting, give the out-of-scope list to a fresh reviewer to triage against current `master`,
open and merged PRs, and existing plans. Drop resolved items and duplicates. Report the remaining
items in plain language with their location and benefit, and ask which should become follow-up work.
Record approved follow-ups in the relevant existing design doc or an owner-requested issue. FPC does
not use evo's `PROJECT_NOTES.md`; do not invent a parallel backlog by default.

### 7. Clean up

After all PRs merge, remove the ignored execution plan and unused branches. Preserve tracked design
docs and any uncommitted files that need keeping. Cleanup is the plan's last checklist item.

## When to ask the owner

Ask for unresolved product decisions, plan approval, changes to approved scope or invariants,
and merging. Ask before production operations, data exports, paid evaluations,
or other external actions unless the owner already authorized the specific action and its limits.
Ask before a **[quiet]** timing that requires pausing other work. Do not stop for sign-off between
ordinary steps or because review has taken several rounds.

The owner can authorize unattended work in advance, with explicit scope, budget, and whether merging
or rollout is included. Record that authorization and each decision made under it. If an unresolved
owner decision blocks one step, continue independent approved work while waiting.

## Watching running agents

Use Claude Code's task status and output tools to check agents regularly. Inspect the expected
commits, `git status`, and running checks when progress is unclear. Brief agents to keep checks in
the foreground with a suitable deadline and report as soon as they finish. If an agent shows no
progress over two checks, ask for status; if it remains unresponsive, stop it before a replacement
continues the work. Reconcile its edits and commits with the plan first. Cancel any monitoring
task when its agent reports so stale notifications do not interrupt later work.

## Step brief

Give each agent the repository and execution-plan paths, branch and base commit, its step,
every plan clause applying to that step, owner decisions, acceptance criteria, and exact check
commands. Include `CLAUDE.md` and this guide. The agent:

- Writes behavior tests for code changes; for a defect, first confirms the test fails before the fix.
- Follows existing FPC conventions and keeps migrations and `db/structure.sql` consistent.
- Runs focused checks while implementing and both full test suites before declaring the task done,
  as `CLAUDE.md` requires; checks output for new warnings and runs the named extra checks.
- Runs commands through the development environment described in `CLAUDE.md` and keeps scratch
  files out of tracked directories.
- Checks `git status` and ignored files so required fixtures are committed and generated files stay
  out. Lets the pre-commit hook format staged files and inspects the result.
- Leaves **[quiet]** measurements and unauthorized external actions to the orchestrator. It prepares
  exact commands and records provisional values where needed.
- Commits without pushing and does not edit the execution plan or expand its step's scope.
- Reports commits, files, checks and results, unsettled decisions, dependencies for later steps, and
  out-of-scope items. Reviewers receive the same request for out-of-scope items.

## Review rules

A finding cites a `file:line`, the defect, a realistic input or application state, the resulting
failure, and evidence from code, a test, or a command. Review access control, collection ownership,
data integrity, retries and duplicate jobs, migration compatibility, API/UI integration, and agent
behavior where the change touches them. Style preferences, hypothetical states the application
cannot produce, and unchanged bugs outside the change belong outside the findings list.

- **Blocker:** wrong results or unsafe behavior in normal use, such as lost collection data,
  unauthorized access, corrupt clustering, a broken build, or a failed check reported as passing.
- **Important:** a real defect users or maintainers encounter in normal use. Missing tests for changed
  application behavior count when a regression would otherwise pass unnoticed.
- **Nit:** a smaller issue still worth mentioning. In a plan review, an issue is important only if it
  would plausibly cause incorrect implementation or break an invariant and the step's planned tests
  would not settle it; other implementation edge cases are nits.

Fix blockers and important findings, then have a fresh reviewer review the entire plan or branch
again. Give it previous findings and their dispositions so fixed or declined findings are not raised
again. The loop ends when a round has no blocker or important finding; it has no arbitrary round
limit. Nits do not start another round. Fix small nits on already touched lines or report them.

A reviewer receives the base, diff command, goal, owner decisions, earlier findings, relevant plan
clauses, and required checks. It does not change branches, stash, format, or edit implementation
files. The step agent makes fixes after the reviewer reports. Docs-only reviews check accuracy,
links, commands, and consistency with repository instructions.

## Checks and measurements

| Check                   | When                                                          | Purpose                                                      |
| ----------------------- | ------------------------------------------------------------- | ------------------------------------------------------------ |
| Whole-plan review       | Before code; again after a design change                      | Find gaps before implementation.                             |
| Focused RSpec/Vitest    | During each code step                                         | Pin the behavior the step changes.                           |
| Per-commit review       | Before another step depends on a code commit                  | Catch defects before later work builds on them.              |
| Full RSpec and Vitest   | Before a task is declared done and before opening its PR      | Check backend and frontend regressions.                      |
| `yarn lint`             | Before opening a PR                                           | Match CI formatting and ESLint checks.                       |
| Whole-branch review     | Before pushing and after fixes                                | Check how the complete change fits together.                 |
| Application smoke check | End of the last code PR; earlier where stubs hide integration | Exercise the application path beyond isolated tests.         |
| GitHub CI               | Each PR and subsequent push                                   | Verify the submitted commit, including the production image. |

Use the commands in `CLAUDE.md`. When a test might pass despite broken behavior, ask the step agent
to temporarily break that behavior, confirm the test fails, and restore the implementation before
committing. Avoid wall-clock assertions for ordinary correctness tests.

For **[quiet]** timings, first prepare the command and representative workload. The orchestrator
coordinates a pause with the owner unless already authorized, records load and available disk,
runs only the measurement, and says when other work can resume. Record the exact command, commit,
data size, concurrency, and results. Correctness checks need no quiet machine. Reconsider conditional
steps if measurements show a cheaper approach or an earlier change alters their benefit.

For **[paid]** evaluations, agree the provider, model, dataset, and spending cap. Separate quality,
latency, and cost results; keep private collection data and secrets out of commits and reports. Live
calls do not replace repeatable stubbed or replay tests.

## Stacked PRs

**Stacking.** Open and verify the base PR before beginning a dependent one. Independent PRs can target
`master`. If a base branch is rebased, move its unpublished descendants with
`git rebase --onto NEW_BASE OLD_BASE`; avoid rewriting a base already used by other work without
coordination.

**Merging.** Once authorized, merge the bottom PR without deleting its branch. Retarget the next PR
to `master` with `gh pr edit PR --base master` and verify its base before deleting the old remote
branch: deleting a branch still targeted by a PR can close that PR. Bring the next branch up to date,
review conflict resolutions, rerun checks and CI, then merge it. Repeat up the stack. Check for
uncommitted work before switching branches or deleting unused local branches.
