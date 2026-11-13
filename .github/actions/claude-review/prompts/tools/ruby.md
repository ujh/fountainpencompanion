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
- **AI agents use the `RubyLlmAgent` concern.** RubyLLM
  inner-class tools should override `def name`. Without it,
  `config/initializers/ruby_llm.rb` derives the name from the
  demodulized class name, so renaming or moving the class
  silently changes the name the system prompt and saved
  transcripts refer to. Flag a missing override as a `nit`.

## Reading gem source

To inspect the source of a gem this repo depends on:

1. Read `Gemfile.lock` via the `Read` tool to find the gem's
   version (rubygems-sourced) or revision (GIT-sourced).
2. Gem source is not reachable from the reviewer (`gh api`
   is not allowlisted and gems are not installed); note in
   the finding that external gem source was not inspected.
