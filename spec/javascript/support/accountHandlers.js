import { HttpResponse, http } from "msw";

// Components that use the useHiddenFields hook fire a background
// `GET /account` (and a `PUT /account` when migrating local preferences to
// the server). Component suites that don't exercise preference syncing can
// register these no-op handlers to silence MSW "unhandled request" warnings.
const accountResponse = {
  data: { id: "1", type: "user", attributes: { name: "Test", preferences: {} } }
};

export const accountHandlers = [
  http.get("/account", () => HttpResponse.json(accountResponse)),
  http.put("/account", () => HttpResponse.json(accountResponse))
];
