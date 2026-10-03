import { deleteRequest, postRequest, putRequest } from "fetch";
import { rest } from "msw";
import { setupServer } from "msw/node";

const csrfError = {
  errors: [{ code: "invalid_csrf_token", detail: "CSRF token verification failed" }]
};

const server = setupServer();

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="stale-token">';
});

const currentToken = () =>
  document.querySelector("meta[name='csrf-token']").getAttribute("content");

// Accepts only the given token, like Rails' CSRF protection.
const protectedHandler = (validToken, onSuccess = () => {}) => {
  const receivedTokens = [];
  const handler = (req, res, ctx) => {
    const token = req.headers.get("X-CSRF-Token");
    receivedTokens.push(token);
    if (token !== validToken) return res(ctx.status(422), ctx.json(csrfError));
    onSuccess();
    return res(ctx.status(200), ctx.json({ ok: true }));
  };
  return { handler, receivedTokens };
};

describe("CSRF token refresh", () => {
  it("refreshes the token and retries once after a CSRF failure", async () => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    server.use(
      rest.post("/things", handler),
      rest.get("/csrf_token", (req, res, ctx) => res(ctx.json({ token: "fresh-token" })))
    );

    const response = await postRequest("/things", { a: 1 });

    expect(response.status).toBe(200);
    expect(receivedTokens).toEqual(["stale-token", "fresh-token"]);
    expect(currentToken()).toBe("fresh-token");
  });

  it.each([
    ["PUT", putRequest, rest.put],
    ["DELETE", deleteRequest, rest.delete]
  ])("works for %s requests", async (_method, request, restMethod) => {
    const { handler } = protectedHandler("fresh-token");
    server.use(
      restMethod("/things", handler),
      rest.get("/csrf_token", (req, res, ctx) => res(ctx.json({ token: "fresh-token" })))
    );

    const response = await request("/things");

    expect(response.status).toBe(200);
  });

  it("uses the refreshed token for later requests", async () => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    let tokenRequests = 0;
    server.use(
      rest.post("/things", handler),
      rest.get("/csrf_token", (req, res, ctx) => {
        tokenRequests += 1;
        return res(ctx.json({ token: "fresh-token" }));
      })
    );

    await postRequest("/things");
    await postRequest("/things");

    expect(tokenRequests).toBe(1);
    expect(receivedTokens).toEqual(["stale-token", "fresh-token", "fresh-token"]);
  });

  it("shares one token refresh between requests failing at the same time", async () => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    let tokenRequests = 0;
    server.use(
      rest.post("/things", handler),
      rest.get("/csrf_token", (req, res, ctx) => {
        tokenRequests += 1;
        return res(ctx.json({ token: `fresh-token${tokenRequests > 1 ? tokenRequests : ""}` }));
      })
    );

    const responses = await Promise.all([postRequest("/things"), postRequest("/things")]);

    expect(responses.map((response) => response.status)).toEqual([200, 200]);
    expect(tokenRequests).toBe(1);
    expect(receivedTokens).toEqual(["stale-token", "stale-token", "fresh-token", "fresh-token"]);
  });

  it("retries only once if the refreshed token is rejected too", async () => {
    const { handler, receivedTokens } = protectedHandler("never-valid");
    server.use(
      rest.post("/things", handler),
      rest.get("/csrf_token", (req, res, ctx) => res(ctx.json({ token: "fresh-token" })))
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(receivedTokens).toEqual(["stale-token", "fresh-token"]);
  });

  it("does not refresh the token for other 422 errors", async () => {
    let tokenRequests = 0;
    server.use(
      rest.post("/things", (req, res, ctx) =>
        res(ctx.status(422), ctx.json({ errors: [{ detail: "Name can't be blank" }] }))
      ),
      rest.get("/csrf_token", (req, res, ctx) => {
        tokenRequests += 1;
        return res(ctx.json({ token: "fresh-token" }));
      })
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(tokenRequests).toBe(0);
    expect((await response.json()).errors[0].detail).toBe("Name can't be blank");
  });

  it("does not refresh the token for 422 responses without a JSON body", async () => {
    let tokenRequests = 0;
    server.use(
      rest.post("/things", (req, res, ctx) => res(ctx.status(422), ctx.text("Unprocessable"))),
      rest.get("/csrf_token", (req, res, ctx) => {
        tokenRequests += 1;
        return res(ctx.json({ token: "fresh-token" }));
      })
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(tokenRequests).toBe(0);
  });

  it.each([
    ["errors", (req, res, ctx) => res(ctx.status(500))],
    ["returns no token", (req, res, ctx) => res(ctx.json({}))],
    ["fails with a network error", (req, res) => res.networkError("offline")]
  ])("returns the original response if refreshing the token %s", async (_, tokenHandler) => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    server.use(rest.post("/things", handler), rest.get("/csrf_token", tokenHandler));

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(receivedTokens).toEqual(["stale-token"]);
    expect(currentToken()).toBe("stale-token");
    expect((await response.json()).errors[0].code).toBe("invalid_csrf_token");
  });

  it("returns the original response if the page has no CSRF meta tag", async () => {
    document.head.innerHTML = "";
    let tokenRequests = 0;
    server.use(
      rest.post("/things", (req, res, ctx) => res(ctx.status(422), ctx.json(csrfError))),
      rest.get("/csrf_token", (req, res, ctx) => {
        tokenRequests += 1;
        return res(ctx.json({ token: "fresh-token" }));
      })
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(tokenRequests).toBe(0);
  });
});
