# Frontend toolset guidance

React components and hooks live in `app/javascript/src/`,
bundled by Webpack into `app/assets/builds/` (generated — never
review the builds output; it is excluded from `diff-code.patch`).
Tests are Vitest (jsdom environment), named `*.spec.js(x)`, under `spec/javascript/`
mirroring the source tree. No Node toolchain runs in this
workflow — review from source and the diff, do not try to run
`pnpm`, `vitest`, `eslint`, or `prettier`.

## Conventions to enforce (from CLAUDE.md)

- **PascalCase** for components, **camelCase** for
  variables/functions.
- **React Hooks rules are enforced** (eslint-plugin-react-hooks).
  Flag: hooks called conditionally or in loops, missing/incorrect
  dependency arrays on `useEffect`/`useMemo`/`useCallback`,
  state derived in an effect that should be computed during
  render, and effects that should be event handlers.
- **No unused vars** (ESLint). Flag dead imports/locals the
  diff introduces.

## Formatting is owned by Prettier — do NOT flag style nits

Prettier config: **100-char width, semicolons, double quotes,
no trailing commas, `arrowParens: always`**. Quote style,
semicolons, line width, trailing commas, and arrow-paren style
are owned by the formatter and enforced by `pnpm lint` in CI — do
**not** raise findings about them. Likewise Ruby is formatted by
the Prettier Ruby plugin. Focus on logic, correctness, hook
usage, and structure, not anything a formatter rewrites.
