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

### Backend (RSpec)

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
- **Ruby**: snake_case for methods/variables, CamelCase for classes/modules. Rescue specific errors only.
- **JavaScript/JSX**: PascalCase for components, camelCase for variables/functions. Tests use `*.spec.js(x)` extension.
- **Commits**: lint-staged runs Prettier and ESLint on staged files via Husky pre-commit hook.

## CI

Defined in `.github/workflows/ci.yml`. Runs on push to master and on PRs:

- **rspec**: full Rails test suite
- **jest**: linting + JS test suite
- **docker-build**: verifies production Docker image builds
- **deploy**: auto-deploys to Fly.io on master after tests pass
