# Required review checks

Required review checks. Each check is independent — run them in
parallel as subagents per the dispatch instructions in
`base.md`. The inlined "Repository review rules" section at
the top of this prompt may add to, replace, or remove items
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
   under `spec/` mirroring `app/`, Jest specs as `*.spec.js(x)`
   under `spec/javascript/` mirroring `app/javascript/src/`)
   exercises the new code path. Pure refactors with no
   behavior change are exempt. Report each uncovered change as
   one finding pinned to the production file:line that lacks
   coverage.

2. pr-meta — Combined PR-description + PR-size check. Read
   `.pr-context/meta.json` (`.title`, `.body`, `.additions`,
   `.deletions`, `.changedFiles`) and `.pr-context/diff-stat.txt`.
   Do NOT Read any source file in this check — meta.json and
   diff-stat are sufficient. Run two sub-checks and report at
   most one finding per sub-check (so 0–2 findings total,
   all PR-level, none pinned to a file):

   (a) Description quality. Verify the body explains WHY
   the change is being made, not just what changed. If
   the description is missing or only restates the diff,
   surface one PR-level finding asking for the
   motivation/context. This is an open-source project —
   do NOT require a linked issue or ticket; a `#123`
   GitHub issue reference is welcome where one plausibly
   exists, but its absence is not a finding. Trivial
   chores (typo fixes, dependency bumps, internal
   tooling) may have a terse description — use judgement.
   Do not re-run `gh pr view`; the data is in `meta.json`.

   (b) PR size and seams. If the diff is large or spans
   multiple unrelated concerns, surface one PR-level
   finding proposing a split along logical seams (e.g.
   refactor vs. feature, independent modules, prep
   commits vs. behavior change, test scaffolding vs.
   production code) — name the files/commits in each
   smaller PR and the seam. Cohesive small changes and
   pure mechanical sweeps (renames, formatting) are
   exempt — use judgement.

3. consistency — **Gated: skip when `additions + deletions ≤
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

4. clean-code — Enforce SOLID principles and top-down
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

5. correctness — Hunt for bugs that would break production.
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
   Mark severity `important` for behavior-breaking bugs, `nit`
   for narrow edge cases that are unlikely to fire, and
   `pre-existing` for bugs the diff did not introduce but
   exposed.

6. simplification — Flag unnecessary complexity the diff
   adds. Look for: redundant or derivable state (values
   recomputed or stored that could be derived from existing
   ones), copy-paste with slight variation (extract a
   parameterized helper), deep nesting that could be
   flattened with early returns or guard clauses, dead code
   left behind by the change (unused vars, unreachable
   branches, commented-out blocks), redundant conditionals,
   and abstractions introduced for a single caller. For each
   finding, name the simpler form that does the same job and
   pin it to file:line. This check is distinct from
   clean-code (SOLID): it targets local mechanical
   simplifications, not architectural shape.

7. efficiency — Flag wasted work the diff introduces.
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
   speedups.
