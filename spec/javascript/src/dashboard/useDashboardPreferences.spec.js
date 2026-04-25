import { act, renderHook } from "@testing-library/react";
import { useDashboardPreferences } from "dashboard/useDashboardPreferences";
import * as storage from "localStorage";
import { rest } from "msw";
import { setupServer } from "msw/node";

const server = setupServer(
  rest.get("/account", (req, res, ctx) => {
    return res(
      ctx.json({
        data: {
          attributes: {
            preferences: {}
          }
        }
      })
    );
  }),
  rest.put("/account", (req, res, ctx) => {
    return res(ctx.json({ data: { attributes: { preferences: {} } } }));
  })
);

beforeAll(() => server.listen());
afterEach(() => {
  server.resetHandlers();
  storage.removeItem("fpc-dashboard-widgets");
});
afterAll(() => server.close());

function saveToStorage(value) {
  storage.setItem("fpc-dashboard-widgets", JSON.stringify(value));
}

describe("useDashboardPreferences", () => {
  it("returns all widget IDs by default", () => {
    const { result } = renderHook(() => useDashboardPreferences());
    expect(result.current.visibleWidgetIds).toHaveLength(9);
    expect(result.current.visibleWidgetIds[0]).toBe("currently_inked_summary");
  });

  it("reads from localStorage on mount", () => {
    saveToStorage({ visible: ["pens_summary", "inks_summary"], removed: [] });

    const { result } = renderHook(() => useDashboardPreferences());
    // visible includes the saved ones plus new widgets not in removed
    expect(result.current.visibleWidgetIds[0]).toBe("pens_summary");
    expect(result.current.visibleWidgetIds[1]).toBe("inks_summary");
  });

  it("strips invalid IDs from saved preference", () => {
    saveToStorage({ visible: ["nonexistent_widget", "inks_summary"], removed: [] });

    const { result } = renderHook(() => useDashboardPreferences());
    expect(result.current.visibleWidgetIds[0]).toBe("inks_summary");
  });

  it("falls back to defaults if saved value is empty after sanitizing", () => {
    saveToStorage({ visible: ["nonexistent"], removed: [] });

    const { result } = renderHook(() => useDashboardPreferences());
    expect(result.current.visibleWidgetIds).toHaveLength(9);
  });

  it("updates localStorage and state on save", () => {
    const { result } = renderHook(() => useDashboardPreferences());
    const newIds = ["pens_summary", "inks_summary"];

    act(() => {
      result.current.setVisibleWidgetIds(newIds);
    });

    expect(result.current.visibleWidgetIds).toEqual(newIds);
    const stored = JSON.parse(storage.getItem("fpc-dashboard-widgets"));
    expect(stored.visible).toEqual(newIds);
    expect(stored.removed).toContain("currently_inked_summary");
  });

  it("resets to defaults and clears storage when saving null", () => {
    saveToStorage({
      visible: ["pens_summary"],
      removed: ["inks_summary"]
    });

    const { result } = renderHook(() => useDashboardPreferences());

    act(() => {
      result.current.setVisibleWidgetIds(null);
    });

    expect(storage.getItem("fpc-dashboard-widgets")).toBeNull();
    expect(result.current.visibleWidgetIds).toHaveLength(9);
    expect(result.current.visibleWidgetIds[0]).toBe("currently_inked_summary");
  });

  it("syncs from server when server has a value", async () => {
    const serverValue = {
      visible: ["leaderboard_ranking", "inks_summary"],
      removed: ["pens_summary"]
    };
    server.use(
      rest.get("/account", (req, res, ctx) => {
        return res(
          ctx.json({
            data: {
              attributes: {
                preferences: { dashboard_widgets: serverValue }
              }
            }
          })
        );
      })
    );

    const { result, rerender } = renderHook(() => useDashboardPreferences());

    await act(async () => {
      await new Promise((r) => setTimeout(r, 50));
      rerender();
    });

    expect(result.current.visibleWidgetIds[0]).toBe("leaderboard_ranking");
    expect(result.current.visibleWidgetIds[1]).toBe("inks_summary");
    expect(result.current.visibleWidgetIds).not.toContain("pens_summary");
  });

  it("auto-appends new widgets not in visible or removed", () => {
    // Simulate a saved preference that doesn't include all current registry widgets.
    // "currently_inked_summary" is not in visible or removed, so it should be auto-appended.
    saveToStorage({
      visible: ["inks_summary", "pens_summary"],
      removed: ["leaderboard_ranking"]
    });

    const { result } = renderHook(() => useDashboardPreferences());

    expect(result.current.visibleWidgetIds).toContain("inks_summary");
    expect(result.current.visibleWidgetIds).toContain("pens_summary");
    expect(result.current.visibleWidgetIds).toContain("currently_inked_summary");
    expect(result.current.visibleWidgetIds).not.toContain("leaderboard_ranking");
    // New widgets appended after the explicitly visible ones
    expect(result.current.visibleWidgetIds.indexOf("inks_summary")).toBeLessThan(
      result.current.visibleWidgetIds.indexOf("currently_inked_summary")
    );
  });

  it("keeps explicitly removed widgets hidden even when new widgets are added", () => {
    saveToStorage({
      visible: ["inks_summary"],
      removed: ["pens_summary", "leaderboard_ranking"]
    });

    const { result } = renderHook(() => useDashboardPreferences());

    expect(result.current.visibleWidgetIds).toContain("inks_summary");
    expect(result.current.visibleWidgetIds).not.toContain("pens_summary");
    expect(result.current.visibleWidgetIds).not.toContain("leaderboard_ranking");
  });

  it("tracks removed widgets when setting visible IDs", () => {
    const { result } = renderHook(() => useDashboardPreferences());

    act(() => {
      result.current.setVisibleWidgetIds(["inks_summary", "pens_summary"]);
    });

    const stored = JSON.parse(storage.getItem("fpc-dashboard-widgets"));
    expect(stored.visible).toEqual(["inks_summary", "pens_summary"]);
    expect(stored.removed).toContain("currently_inked_summary");
    expect(stored.removed).toContain("leaderboard_ranking");
    expect(stored.removed).not.toContain("inks_summary");
    expect(stored.removed).not.toContain("pens_summary");
  });
});
