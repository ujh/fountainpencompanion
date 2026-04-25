import { act, renderHook, waitFor } from "@testing-library/react";
import * as storage from "localStorage";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { useHiddenFields } from "useHiddenFields";

const server = setupServer();

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  storage.removeItem("fpc-collected-inks-table-hidden-fields");
});
afterAll(() => server.close());

const storageKey = "fpc-collected-inks-table-hidden-fields";
const defaultHiddenFields = ["maker", "kind"];

function mockAccountResponse(preferences) {
  server.use(
    rest.get("/account", (req, res, ctx) => {
      return res(
        ctx.json({
          data: {
            id: "1",
            type: "user",
            attributes: {
              name: "Test",
              preferences: preferences
            }
          }
        })
      );
    })
  );
}

function mockAccountUpdate(callback) {
  server.use(
    rest.put("/account", async (req, res, ctx) => {
      const body = await req.json();
      if (callback) callback(body);
      return res(
        ctx.json({
          data: {
            id: "1",
            type: "user",
            attributes: { name: "Test", preferences: {} }
          }
        })
      );
    })
  );
}

describe("useHiddenFields", () => {
  it("initializes from localStorage synchronously", () => {
    storage.setItem(storageKey, JSON.stringify(["comment"]));
    mockAccountResponse({});
    mockAccountUpdate();

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    // Synchronously available — no waitFor needed
    expect(result.current.hiddenFields).toEqual(["comment"]);
  });

  it("initializes from defaults when localStorage is empty", () => {
    mockAccountResponse({});

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    expect(result.current.hiddenFields).toEqual(defaultHiddenFields);
  });

  it("updates to server value after fetch", async () => {
    mockAccountResponse({ collected_inks_table_hidden_fields: ["nib", "color"] });

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    // Initially defaults
    expect(result.current.hiddenFields).toEqual(defaultHiddenFields);

    // After fetch, updates to server value
    await waitFor(() => {
      expect(result.current.hiddenFields).toEqual(["nib", "color"]);
    });
  });

  it("keeps localStorage value when server has no preference", async () => {
    storage.setItem(storageKey, JSON.stringify(["comment"]));
    mockAccountResponse({});
    mockAccountUpdate();

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    expect(result.current.hiddenFields).toEqual(["comment"]);

    // Wait for sync to complete — value should remain unchanged
    await waitFor(() => {
      expect(result.current.hiddenFields).toEqual(["comment"]);
    });
  });

  it("keeps localStorage value on network error", async () => {
    storage.setItem(storageKey, JSON.stringify(["tags"]));
    server.use(
      rest.get("/account", (req, res) => {
        return res.networkError("Connection refused");
      })
    );

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    expect(result.current.hiddenFields).toEqual(["tags"]);
  });

  it("updates localStorage with server value", async () => {
    storage.setItem(storageKey, JSON.stringify(["old"]));
    mockAccountResponse({ collected_inks_table_hidden_fields: ["nib"] });

    renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    await waitFor(() => {
      expect(JSON.parse(storage.getItem(storageKey))).toEqual(["nib"]);
    });
  });

  it("migrates localStorage data to server when server has no value", async () => {
    storage.setItem(storageKey, JSON.stringify(["comment"]));
    mockAccountResponse({});

    let savedBody;
    mockAccountUpdate((body) => {
      savedBody = body;
    });

    renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    await waitFor(() => {
      expect(savedBody).toBeDefined();
      expect(savedBody.user.preferences.collected_inks_table_hidden_fields).toEqual(["comment"]);
    });
  });

  it("saves to server on field change", async () => {
    mockAccountResponse({ collected_inks_table_hidden_fields: ["nib"] });

    let savedBody;
    mockAccountUpdate((body) => {
      savedBody = body;
    });

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    await waitFor(() => {
      expect(result.current.hiddenFields).toEqual(["nib"]);
    });

    act(() => {
      result.current.onHiddenFieldsChange(["nib", "color"]);
    });

    expect(result.current.hiddenFields).toEqual(["nib", "color"]);

    await waitFor(() => {
      expect(savedBody).toBeDefined();
      expect(savedBody.user.preferences.collected_inks_table_hidden_fields).toEqual([
        "nib",
        "color"
      ]);
    });
  });

  it("restores defaults when null is passed", async () => {
    mockAccountResponse({ collected_inks_table_hidden_fields: ["nib"] });

    let savedBody;
    mockAccountUpdate((body) => {
      savedBody = body;
    });

    const { result } = renderHook(() => useHiddenFields(storageKey, defaultHiddenFields));

    await waitFor(() => {
      expect(result.current.hiddenFields).toEqual(["nib"]);
    });

    act(() => {
      result.current.onHiddenFieldsChange(null);
    });

    expect(result.current.hiddenFields).toEqual(defaultHiddenFields);

    await waitFor(() => {
      expect(savedBody).toBeDefined();
      expect(savedBody.user.preferences.collected_inks_table_hidden_fields).toBeNull();
    });
  });
});
