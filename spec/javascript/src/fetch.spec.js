import { deleteRequest, postRequest, putRequest } from "fetch";
import { HttpResponse, http } from "msw";
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
  const handler = ({ request }) => {
    const token = request.headers.get("X-CSRF-Token");
    receivedTokens.push(token);
    if (token !== validToken) return HttpResponse.json(csrfError, { status: 422 });
    onSuccess();
    return HttpResponse.json({ ok: true });
  };
  return { handler, receivedTokens };
};

describe("CSRF token refresh", () => {
  it("refreshes the token and retries once after a CSRF failure", async () => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    server.use(
      http.post("/things", handler),
      http.get("/csrf_token", () => HttpResponse.json({ token: "fresh-token" }))
    );

    const response = await postRequest("/things", { a: 1 });

    expect(response.status).toBe(200);
    expect(receivedTokens).toEqual(["stale-token", "fresh-token"]);
    expect(currentToken()).toBe("fresh-token");
  });

  it.each([
    ["PUT", putRequest, http.put],
    ["DELETE", deleteRequest, http.delete]
  ])("works for %s requests", async (_method, request, httpMethod) => {
    const { handler } = protectedHandler("fresh-token");
    server.use(
      httpMethod("/things", handler),
      http.get("/csrf_token", () => HttpResponse.json({ token: "fresh-token" }))
    );

    const response = await request("/things");

    expect(response.status).toBe(200);
  });

  it("uses the refreshed token for later requests", async () => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    let tokenRequests = 0;
    server.use(
      http.post("/things", handler),
      http.get("/csrf_token", () => {
        tokenRequests += 1;
        return HttpResponse.json({ token: "fresh-token" });
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
      http.post("/things", handler),
      http.get("/csrf_token", () => {
        tokenRequests += 1;
        return HttpResponse.json({ token: `fresh-token${tokenRequests > 1 ? tokenRequests : ""}` });
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
      http.post("/things", handler),
      http.get("/csrf_token", () => HttpResponse.json({ token: "fresh-token" }))
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(receivedTokens).toEqual(["stale-token", "fresh-token"]);
  });

  it("does not refresh the token for other 422 errors", async () => {
    let tokenRequests = 0;
    server.use(
      http.post("/things", () =>
        HttpResponse.json({ errors: [{ detail: "Name can't be blank" }] }, { status: 422 })
      ),
      http.get("/csrf_token", () => {
        tokenRequests += 1;
        return HttpResponse.json({ token: "fresh-token" });
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
      http.post("/things", () => HttpResponse.text("Unprocessable", { status: 422 })),
      http.get("/csrf_token", () => {
        tokenRequests += 1;
        return HttpResponse.json({ token: "fresh-token" });
      })
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(tokenRequests).toBe(0);
  });

  it.each([
    ["errors", () => new HttpResponse(null, { status: 500 })],
    ["returns no token", () => HttpResponse.json({})],
    ["fails with a network error", () => HttpResponse.error()]
  ])("returns the original response if refreshing the token %s", async (_, tokenHandler) => {
    const { handler, receivedTokens } = protectedHandler("fresh-token");
    server.use(http.post("/things", handler), http.get("/csrf_token", tokenHandler));

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
      http.post("/things", () => HttpResponse.json(csrfError, { status: 422 })),
      http.get("/csrf_token", () => {
        tokenRequests += 1;
        return HttpResponse.json({ token: "fresh-token" });
      })
    );

    const response = await postRequest("/things");

    expect(response.status).toBe(422);
    expect(tokenRequests).toBe(0);
  });
});
