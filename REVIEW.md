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
  plugin) and ESLint run via lint-staged on commit. Do NOT raise
  findings about quote style, semicolons, line width (100), trailing
  commas, arrow-paren style, or import ordering — the formatter owns
  these and lint-staged enforces them.

- **No issue/ticket requirement.** This is an open-source project. Do
  not require PR descriptions to link an issue or ticket. A `#123`
  GitHub issue reference is welcome but its absence is never a finding.

## Calibration

- CLAUDE.md notes existing code quality varies and that older code is
  often poorly tested. Judge new and changed code on its own merits and
  hold it to the "well-structured and thoroughly tested" bar — do not
  excuse a weak new addition because nearby legacy code is worse, and
  do not demand that a PR fix unrelated pre-existing problems (flag
  those as `pre-existing` at most).
