# CLAUDE.md

## Project Overview

Fountain Pen Companion (FPC) is a web application for managing fountain pen ink and pen collections. It aggregates user data to provide value to the community (e.g., brand/ink listings, clustering). Built with Ruby on Rails (server-rendered views + JSON API) and React (for the inks/pens UI), bundled with Webpack.

## Architecture

- **Backend**: Ruby on Rails with PostgreSQL (pgvector) and Redis
- **Frontend**: React components in `app/javascript/src/`, bundled by Webpack into `app/assets/builds/`
- **Background jobs**: Sidekiq with sidekiq-scheduler
- **API**: JSON API spec (`/api/v1/`) for collected inks, pens, currently inked
- **Auth**: Devise (with passwordless support)
- **DB schema format**: `structure.sql` (not `schema.rb`)
- **Deployment**: Fly.io via CI (master branch auto-deploys)

## Development Environment

The app runs via Docker (OrbStack recommended). All commands should be run through `docker-compose exec app`.

### Starting the App

```
docker-compose up
```

This starts: app (Puma), webpack (dev server), sidekiq (workers), postgres, and redis.

On first setup:

```
docker-compose exec app bundle exec rails db:setup
```

Access the app at the URL OrbStack assigns to the `app` container (e.g., `app.fountainpencompanion.orb.local`).

### Emails in Development

Accessible at `/letter_opener`.

## Running Tests

When making changes always run the tests to ensure they still pass. Run ALL tests as the final step before considering
a task done.

### Backend (RSpec)

Important: When running the tests, check the output to ensure that no new warnings were introduced.

All backend tests:

```
docker-compose exec -T app bundle exec rspec
```

Single file:

```
docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb
```

Single test by line number:

```
docker-compose exec -T app bundle exec rspec spec/models/user_spec.rb:3
```

Filter by example name:

```
docker-compose exec -T app bundle exec rspec -e "example name"
```

### Frontend (Jest)

All frontend tests:

```
docker-compose exec -T app yarn test
```

Single file:

```
docker-compose exec -T app yarn jest app/javascript/src/color-sorting.spec.js
```

Filter by pattern:

```
docker-compose exec -T app yarn jest --testPathPatterns="color-sorting"
```

Filter by test name:

```
docker-compose exec -T app yarn jest -t "test name"
```

## Linting & Formatting

Run all linters (Prettier + ESLint):

```
docker-compose exec -T app yarn lint
```

Auto-fix formatting:

```
docker-compose exec -T app yarn prettier-fix
```

Auto-fix ESLint issues:

```
docker-compose exec -T app yarn eslint --fix
```

### Style Rules

- **Prettier**: 100 char width, semicolons, double quotes, no trailing commas, `arrowParens: always`
- **ESLint**: react + react-hooks plugins; hooks rules enforced; no unused vars
- **Ruby**: formatted via Prettier Ruby plugin; follows standard Rails conventions

## Project Structure

```
app/
  agents/          # AI agents
  controllers/     # Rails controllers + API (api/v1/)
  javascript/
    src/           # React components and hooks
    stylesheets/   # SCSS styles
    images/        # Frontend images
  jobs/            # ActiveJob jobs
  models/          # ActiveRecord models
  operations/      # Operation/service objects
  serializable/    # JSONAPI::Rails serializers
  serializers/     # jsonapi-serializer serializers
  views/           # Slim templates
  workers/         # Sidekiq workers
config/
db/
  migrate/         # Database migrations
  structure.sql    # Database schema (SQL format)
  views/           # Scenic database views
spec/
  controllers/     # Controller specs
  javascript/      # Jest tests (mirrors app/javascript/src/)
  models/          # Model specs
  operations/      # Operation specs
  requests/        # Request specs
  workers/         # Worker specs
  factories/       # FactoryBot factories
```

## Key Conventions

- **New code should be well-structured and thoroughly tested.** Existing code quality varies; don't model new additions after poorly-tested older code.
- **Tests document behaviour, not comments.** Don't add explanatory comments that describe why a check or branch exists; write a test that pins the behaviour instead. Comments are for the rare non-obvious implementation detail a test can't express.
- **Ruby**: snake_case for methods/variables, CamelCase for classes/modules. Rescue specific errors only. Prefer `attr_accessor` with `self.x =` in constructors over bare `@x` instance variables.
- **JavaScript/JSX**: PascalCase for components, camelCase for variables/functions. Tests use `*.spec.js(x)` extension.
- **Commits**: lint-staged runs Prettier and ESLint on staged files via Husky pre-commit hook.

## AI Agents (RubyLLM)

AI agents live in `app/agents/` and use the `RubyLlmAgent` concern (`app/agents/concerns/ruby_llm_agent.rb`). Some older agents still use raix and are being migrated — do not use raix for new agents.

### Agent structure

An agent includes `RubyLlmAgent` and must implement four methods:

- `agent_log` (public) — returns or creates an `AgentLog` instance
- `model_id` (private) — e.g., `"gpt-4.1"` or `"gpt-4.1-mini"`
- `system_directive` (private) — the system prompt string
- `tools` (private) — array of `RubyLLM::Tool` instances (can be empty)

Use `ask(prompt)` in `perform` to send a user message and get a completion. The concern handles transcript saving, usage tracking, and transcript restoration automatically.

### Tool structure

Tools are defined as inner classes inheriting from `RubyLLM::Tool`:

```ruby
class MyTool < RubyLLM::Tool
  description "What this tool does"

  def name = "my_tool" # Required — auto-generated name includes module prefix for inner classes

  param :some_param, desc: "Description" # string (default)
  param :other_param, type: "integer", desc: "Description" # integer

  attr_accessor :some_dep, :other_dep

  def initialize(some_dep, other_dep)
    self.some_dep = some_dep
    self.other_dep = other_dep
  end

  def execute(some_param:, other_param:)
    # Do work...
    halt "result message" # Stops the conversation loop
    # Or return a string to let the LLM continue (e.g., for error/retry)
  end
end
```

Key points:

- Always override `def name` — the auto-generated name includes module prefixes for inner classes
- `halt "message"` stops the tool call loop; returning a plain string sends it back to the LLM
- Tools with no parameters: omit `param` declarations and define `execute` with no arguments
- Pass dependencies (owner objects, agent_log) via the constructor

### agent_log patterns

Top-level agents create their own log:

```ruby
def agent_log
  @agent_log ||= owner.agent_logs.create!(name: self.class.name, transcript: [])
end
```

Sub-agents (called by other agents) use `parent_agent_log:` and find-or-create for transcript restoration:

```ruby
def agent_log
  @agent_log ||= parent_agent_log.agent_logs.processing.where(name: self.class.name).first
  @agent_log ||= parent_agent_log.agent_logs.create!(name: self.class.name, transcript: [])
end
```

### Invocation

Agents are invoked from Sidekiq workers, typically via the generic `RunAgent` worker:

```ruby
RunAgent.perform_async("InkBrandClusterer", macro_cluster.id)
```

Which calls `InkBrandClusterer.new(macro_cluster.id).perform`.

### Testing

Agent specs use WebMock to stub `https://api.openai.com/v1/chat/completions`. Key test areas:

- **Tool unit tests**: instantiate tools directly, call `.call(args)`, assert on `RubyLLM::Tool::Halt` return and side effects
- **Integration tests**: stub API responses with tool_calls, verify agent_log state and extra_data
- **Data formatting**: use WebMock request body assertions to verify prompt content
- **Transcript/usage**: verify `agent_log.transcript` and `agent_log.usage` are populated
- **Error handling**: `RubyLLM::ServerError` for 500s, `Faraday::ParsingError` for malformed JSON

See `spec/agents/spam_classifier_spec.rb` or `spec/agents/ink_brand_clusterer_spec.rb` for reference.

## CI

Defined in `.github/workflows/ci.yml`. Runs on push to master and on PRs:

- **rspec**: full Rails test suite
- **jest**: linting + JS test suite
- **docker-build**: verifies production Docker image builds
- **deploy**: auto-deploys to Fly.io on master after tests pass
