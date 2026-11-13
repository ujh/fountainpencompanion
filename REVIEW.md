# Repository review rules — Fountain Pen Companion

These rules apply in addition to the default review checks and are the
highest-priority guidance for this repo. When a default check would
produce a finding that contradicts a rule here, the rule here wins —
suppress the finding (and log the suppression in the step summary).

## Intentional designs — do NOT flag these as bugs

- **Wiki-style community editing.** Brand and ink descriptions can be
  edited by **any authenticated user** by design — this is intentional
  wiki-style collaborative editing, not a broken authorization check.
  Do not raise authz/IDOR/"missing permission check" findings against
  description-editing paths on this basis.

- **Agents auto-publishing to live.** AI agents (e.g. `ReviewApprover`)
  auto-publishing ink reviews to the live site is an **accepted,
  intentional risk**. Do not flag it as a missing human-in-the-loop or
  unsafe-automation finding.

## Skip / scope rules

- **`db/structure.sql`** is the generated SQL schema dump, not
  hand-written code. It is excluded from `diff-code.patch`. Never
  review it as source — if schema behavior matters, review the
  migration under `db/migrate/` instead.

- **`app/assets/builds/`** is Webpack output (generated). Never review
  it; excluded from `diff-code.patch`.

- **Formatter-owned style.** Prettier (JS + Ruby via the Prettier Ruby
  plugin) and ESLint run in CI via `pnpm lint`. Do NOT raise
  findings about quote style, semicolons, line width (100), trailing
  commas, arrow-paren style, or import ordering — the formatter owns
  these and CI enforces them.

- **No issue/ticket requirement.** This is an open-source project. Do
  not require PR descriptions to link an issue or ticket. A `#123`
  GitHub issue reference is welcome but its absence is never a finding.

## Must-flag rules

- **Runtime versions live in a fixed set of files.** The Ruby version
  is in `.ruby-version` (the `Gemfile` reads it), the `RUBY VERSION`
  stanza of `Gemfile.lock` and the `ruby` `FROM` line of the
  `Dockerfile`; the Node version is in `.nvmrc` (CI reads it),
  `engines` in `package.json` and the `node` `FROM` line.
  `spec/config/runtime_versions_spec.rb` fails when they diverge.
  Raise a `correctness` finding when a PR writes a Ruby or Node
  version anywhere else without extending that spec, or turns a
  `FROM` tag back into an `ARG`, which Dependabot cannot bump.

## Calibration

- **Efficiency on cold paths.** Sidekiq workers, AI agents, rake and
  bench tasks (`lib/tasks/`, `lib/bench/`), console scripts under
  `.claude/` and admin-only pages are cold paths. Do not raise
  efficiency findings there for a repeated cheap call, a second parse,
  an extra in-memory lookup or one extra query. Report them only when
  the waste grows with the data (an N+1 over unbounded rows, loading a
  whole table) or a request path waits on it.

- **Tests, not comments.** CLAUDE.md says tests document behaviour.
  Never suggest adding an explanatory code comment to protect a
  behaviour; suggest the spec that would pin it instead (for query
  counts, `assert_queries_match`).

- **No claims about third-party behaviour from memory.** Gem source is
  not available to the reviewer and dependencies change their defaults
  between versions. Do not state how a gem, CLI tool or library
  behaves (flags, defaults, exit codes, error classes) as a fact unless
  the repo's own code, specs or docs show it. If the risk matters, ask
  it as a question in a `nit`; never make it `important`.

- **Data migrations stay in SQL.** Application models change after a
  migration is written, so raw SQL in a migration is deliberate. Do not
  suggest replacing it with model calls such as `User.where(...)`.

- CLAUDE.md notes existing code quality varies and that older code is
  often poorly tested. Judge new and changed code on its own merits and
  hold it to the "well-structured and thoroughly tested" bar — do not
  excuse a weak new addition because nearby legacy code is worse, and
  do not demand that a PR fix unrelated pre-existing problems (flag
  those as `pre-existing` at most).
