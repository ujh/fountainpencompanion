# Required review checks

Required review checks. Each check is independent and runs
as its own subagent. The "Repository review rules" section
may add to, replace, or remove items
from this list; if that section defines its own check list,
follow it instead. Otherwise run every applicable check
below.

Some checks are **gated** — they self-skip when the diff is
too small or otherwise not a candidate. The main thread
reads `.pr-context/meta.json` in Phase 1 specifically so it
can apply these gates before fan-out. A gated-out check is
**not dispatched at all** in Phase 2 (no Agent block, no
wasted turn). Each gated check states its skip condition in
its own definition below.

1. test-coverage — Verify every behavioral change in the diff
   is covered by a new or updated test. Walk each non-test
   file in the diff and check that the corresponding test
   file (per the repo's test layout conventions — Ruby specs
   under `spec/` mirroring `app/`, Vitest specs as `*.spec.js(x)`
   under `spec/javascript/` mirroring `app/javascript/src/`)
   exercises the new code path. Pure refactors with no
   behavior change are exempt. Report each uncovered change as
   one finding pinned to the production file:line that lacks
   coverage.
   Also read each new or changed test for assumptions that
   hold today only by luck, and report them pinned to the
   test line: ids or counts from different tables compared
   or matched against each other (separate sequences can
   produce the same id), expected order without an explicit
   `order`, dates and times near day or year boundaries,
   unseeded randomness, and JS tests that assert before an
   effect, timer or promise has settled.

2. consistency — **Gated: skip when `additions + deletions ≤
100`.** Small diffs rarely introduce genuinely novel
   patterns and consistency findings on them are mostly
   noise. File count is irrelevant — a 50-LOC change spread
   across 10 files is still too small to warrant a consistency
   sweep. When the gate passes, reject novel
   patterns where an existing pattern in the repo already
   solves the same problem. For each new abstraction, helper,
   service/operation object, query style, error-handling
   shape, React hook, or naming choice introduced by the diff,
   grep the codebase for prior art and flag any divergence.
   Report each as a finding on the new code with a pointer to
   the existing pattern (file:line) to follow instead.

3. clean-code — Enforce SOLID principles and top-down
   readability. Each new or modified function/method should
   read as a short sequence of well-named steps at one level
   of abstraction, with complexity hidden behind those names.
   Flag: functions doing more than one thing (SRP), modules
   that can't be extended without modification (OCP), leaky
   abstractions or wrong-level mixing (LSP/ISP), hard-wired
   dependencies that should be injected (DIP), and any top-
   level function where a reader has to hold low-level detail
   in their head to follow the flow. Report each as a finding
   pinned to the offending file:line with a concrete
   refactor: which steps to extract, what to name them, or
   which dependency to invert. Note: this repo's CLAUDE.md
   states existing code quality varies — judge new/changed
   code on its own merits, do not excuse it because nearby
   legacy code is worse.

4. correctness — Hunt for bugs that would break production.
   Walk every changed line and ask: does this match the
   author's intent and the surrounding contract? Flag nil /
   null / undefined access on paths that weren't there before,
   off-by-one and boundary errors, inverted conditions,
   missing or wrong error handling (the repo convention is to
   rescue specific errors only, never bare `rescue`), race
   conditions and concurrent-mutation hazards, missing
   transaction or lock scope, N+1-induced incorrectness,
   regressions against the pre-PR behavior at the same call
   sites, contract violations (callers expect X, the new code
   returns Y), broken invariants on data the rest of the
   system already relies on, and security issues (SQL/HTML
   injection, unscoped queries, mass-assignment, secrets in
   logs, auth bypass). Report each as one finding pinned to
   the file:line with a short description of the failure mode
   and a minimal reproducer or counter-example when possible.
   Bugs often sit outside the diff, so for each changed
   method, constant, scope, prompt rule or data shape, `grep`
   its callers and the code that consumes its output, and
   check the contract still holds there. For new polling,
   timers, queues and locks, ask what happens when one round
   takes longer than the interval. When the PR body or
   `docs/` records a decision (an approved setting, a
   documented rule), flag code that silently diverges from
   it. When a PR changes an AI agent's prompt or the data fed
   into it, look for realistic inputs the new wording or data
   mishandles (for example values keyed on user-typed text).
   Mark severity `important` for behavior-breaking bugs, `nit`
   for narrow edge cases that are unlikely to fire, and
   `pre-existing` for bugs the diff did not introduce but
   exposed.

5. simplification — Flag unnecessary complexity the diff
   adds. Look for: redundant or derivable state (values
   recomputed or stored that could be derived from existing
   ones), copy-paste with slight variation (extract a
   parameterized helper), deep nesting that could be
   flattened with early returns or guard clauses, dead code
   left behind by the change (unused vars, unreachable
   branches, commented-out blocks), redundant conditionals,
   and abstractions introduced for a single caller. For each
   finding, name the simpler form that does the same job and
   pin it to file:line. Before reporting, confirm the simpler
   form behaves the same on every path: nil inputs, rescue
   paths, and React effects that re-run (StrictMode mounts,
   unmounts and mounts again). If you cannot show it is
   equivalent, drop the finding. This check is distinct from
   clean-code (SOLID): it targets local mechanical
   simplifications, not architectural shape.

6. efficiency — Flag wasted work the diff introduces.
   Look for: redundant computation inside loops (hoist
   invariants), repeated I/O that could be batched or
   cached, N+1 query patterns (a recurring Rails hazard —
   check for missing `includes`/`preload`), independent
   operations run sequentially that could run in parallel,
   blocking work added to request/hot paths that belongs in
   a background job (Sidekiq), eager loading of data the
   caller does not use, and unnecessary re-renders in React
   (missing memoization on hot paths, new object/array
   literals passed as props each render). For each finding,
   name the cheaper alternative and pin it to file:line.
   Do not flag micro-optimizations on cold paths — the bar
   is "wasted work the diff introduces", not theoretical
   speedups. A finding you would call "minor", "trivial" or
   "cold path" is below the bar: drop it rather than report
   it as a nit.
