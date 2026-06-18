import { rest } from "msw";

// Components that use the useHiddenFields hook fire a background
// `GET /account` (and a `PUT /account` when migrating local preferences to
// the server). Component suites that don't exercise preference syncing can
// register these no-op handlers to silence MSW "unhandled request" warnings.
const accountResponse = {
  data: { id: "1", type: "user", attributes: { name: "Test", preferences: {} } }
};

export const accountHandlers = [
  rest.get("/account", (req, res, ctx) => res(ctx.json(accountResponse))),
  rest.put("/account", (req, res, ctx) => res(ctx.json(accountResponse)))
];
