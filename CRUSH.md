Fountain Pen Companion – CRUSH quick guide

- Stack: Ruby 3.4.4 / Rails 8; Node 24; React 19 + Vitest; Webpack 5; Prettier + ESLint
- Install: yarn install; bundle install; DB: docker-compose up (see README)
- Build: yarn build (prod to app/assets/builds); Dev: yarn dev
- Lint/format: yarn lint; Auto-fix: yarn prettier-fix and/or yarn eslint --fix
- Tests (Rails): docker-compose exec app bundle exec rspec [spec/File.rb[:line] | -e "example"]
- Tests (JS): yarn test; single file: yarn test path/to/Component.spec.jsx; -t "name"; watch mode: yarn vitest
- CI mirrors these in .github/workflows/ci.yml

JavaScript/React

- Prettier: width 100; semicolons; double quotes; no trailing commas; arrowParens always
- ESLint: react + hooks; hooks rules must pass; no-unused-vars enforced
- Code: JS/JSX only; Components PascalCase; vars/functions camelCase; prefer named exports
- Imports: relative paths; CSS/SCSS via webpack loaders
- Tests: _.spec.js(x) and **tests**/_.test.jsx
- Errors: wrap async/await in try/catch; avoid console.log; surface user errors

Ruby/Rails

- Follow Rails conventions; snake_case for methods/vars; CamelCase for classes/modules
- Use raise/rescue sparingly; rescue specific errors only
- Formatting via Prettier Ruby plugin; keep methods small and explicit

Environment

- Node 24 required (see package.json); assets to app/assets/builds
- Docker/OrbStack: prefix commands with docker-compose exec app
- No Cursor/Copilot rules present
