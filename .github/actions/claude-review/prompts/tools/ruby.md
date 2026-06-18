# Ruby / Rails toolset guidance

This repo is a Ruby on Rails app (server-rendered Slim views +
JSON API) with React for the inks/pens UI. No Ruby runtime is
installed in this workflow and Bundler is **not** on the
allowlist — review from source and the diff, do not try to run
`bundle`, `rails`, `rspec`, or `rubocop`.

## Conventions to enforce (from CLAUDE.md)

- **snake_case** methods/variables, **CamelCase** classes/modules.
- **Rescue specific errors only** — flag bare `rescue` /
  `rescue StandardError` that swallows everything.
- **Prefer `attr_accessor`/`attr_reader` with `self.x =` in
  constructors** over bare `@x` instance variables. Flag new
  classes that reach for raw ivars where an accessor reads
  cleaner.
- DB schema is **`structure.sql`** (SQL format), not
  `schema.rb`. It is generated from migrations — never review
  edits to it as hand-written code; check the migration
  instead.
- Service/business logic lives in `app/operations/`,
  background work in `app/jobs/` (ActiveJob) and
  `app/workers/` (Sidekiq), AI agents in `app/agents/`.
- **New AI agents must use the `RubyLlmAgent` concern, not
  raix** (raix agents are legacy, being migrated). Flag a new
  agent built on raix. RubyLLM inner-class tools **must
  override `def name`** — the auto-generated name includes the
  module prefix, so a missing `name` override is a bug.

## Reading gem source

To inspect the source of a gem this repo depends on:

1. Read `Gemfile.lock` via the `Read` tool to find the gem's
   version (rubygems-sourced) or revision (GIT-sourced).
2. For GIT-sourced gems pinned to a SHA, fetch individual
   files via `gh api repos/<org>/<repo>/contents/<path>?ref=<sha>`
   (the response includes base64-encoded content).
3. For public rubygems with no readily-available GitHub
   source, note in the finding that external gem source was
   not inspected. Do not list this as a blocked tool in the
   trailing comment.
