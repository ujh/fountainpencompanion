import { createMacroClusterAndAssign } from "admin/micro-clusters/createMacroClusterAndAssign";
import { assignCluster } from "admin/micro-clusters/assignCluster";
import { UPDATING, ADD_MACRO_CLUSTER } from "admin/components/clustering/actions";

import { rest } from "msw";
import { setupServer } from "msw/node";

// Mock the assignCluster function
jest.mock("admin/micro-clusters/assignCluster");

describe("createMacroClusterAndAssign", () => {
  const server = setupServer(
    rest.post("/admins/macro_clusters.json", (req, res, ctx) => {
      const body = req.body;

      // Verify the request structure
      expect(body.data.type).toBe("macro_cluster");
      expect(body.data.attributes).toEqual({
        brand_name: "Test Brand",
        line_name: "Test Line",
        ink_name: "Test Ink",
        color: "#FF0000"
      });

      return res(
        ctx.json({
          data: {
            id: "new-macro-123",
            type: "macro_cluster",
            attributes: {
              brand_name: "Test Brand",
              line_name: "Test Line",
              ink_name: "Test Ink",
              color: "#FF0000"
            }
          }
        })
      );
    })
  );

  beforeAll(() => {
    server.listen();
    // Mock timers to control setTimeout behavior
    jest.useFakeTimers();
  });

  afterEach(() => {
    server.resetHandlers();
    jest.clearAllMocks();
    jest.clearAllTimers();
  });

  afterAll(() => {
    server.close();
    jest.useRealTimers();
  });

  it("creates a macro cluster, assigns the micro cluster, and dispatches actions", async () => {
    const mockDispatch = jest.fn();
    const mockAfterCreate = jest.fn();
    const mockMicroCluster = {
      id: "micro-456",
      macro_cluster: {
        id: "new-macro-123",
        brand_name: "Test Brand",
        line_name: "Test Line",
        ink_name: "Test Ink",
        color: "#FF0000",
        micro_clusters: [
          {
            id: "micro-456",
            entries: [
              {
                id: "ink-1",
                brand_name: "Test Brand",
                line_name: "Test Line",
                ink_name: "Test Ink",
                color: "#FF0000"
              }
            ]
          }
        ]
      }
    };

    // Mock assignCluster to return the expected structure
    assignCluster.mockResolvedValue(mockMicroCluster);

    const values = {
      brand_name: "Test Brand",
      line_name: "Test Line",
      ink_name: "Test Ink",
      color: "#FF0000"
    };

    // Call the function
    createMacroClusterAndAssign(values, "micro-456", mockDispatch, mockAfterCreate);

    // Verify UPDATING action is dispatched immediately
    expect(mockDispatch).toHaveBeenCalledWith({ type: UPDATING });

    // Fast-forward timers to trigger the setTimeout
    jest.advanceTimersByTime(10);

    // Run all pending timers and promises
    await jest.runAllTimersAsync();

    // Verify assignCluster was called with correct parameters
    expect(assignCluster).toHaveBeenCalledWith("micro-456", "new-macro-123");

    // Verify ADD_MACRO_CLUSTER action was dispatched
    expect(mockDispatch).toHaveBeenCalledWith({
      type: ADD_MACRO_CLUSTER,
      payload: {
        id: "new-macro-123",
        brand_name: "Test Brand",
        line_name: "Test Line",
        ink_name: "Test Ink",
        color: "#FF0000",
        micro_clusters: [
          {
            id: "micro-456",
            entries: [
              {
                id: "ink-1",
                brand_name: "Test Brand",
                line_name: "Test Line",
                ink_name: "Test Ink",
                color: "#FF0000"
              }
            ]
          }
        ],
        grouped_entries: [
          {
            id: "ink-1",
            brand_name: "Test Brand",
            line_name: "Test Line",
            ink_name: "Test Ink",
            color: "#FF0000"
          }
        ]
      }
    });

    // Verify afterCreate callback was called
    expect(mockAfterCreate).toHaveBeenCalledWith(mockMicroCluster);
  });

  it("dispatches UPDATING action immediately", () => {
    const mockDispatch = jest.fn();
    const mockAfterCreate = jest.fn();
    const values = { brand_name: "Test Brand" };

    createMacroClusterAndAssign(values, "micro-456", mockDispatch, mockAfterCreate);

    expect(mockDispatch).toHaveBeenCalledWith({ type: UPDATING });
  });

  it("handles basic error cases gracefully", () => {
    const mockDispatch = jest.fn();
    const mockAfterCreate = jest.fn();
    const values = { brand_name: "Test Brand" };

    // Should not throw when called
    expect(() => {
      createMacroClusterAndAssign(values, "micro-456", mockDispatch, mockAfterCreate);
    }).not.toThrow();

    // Should dispatch UPDATING immediately
    expect(mockDispatch).toHaveBeenCalledWith({ type: UPDATING });
  });

  it("calls setTimeout with correct delay", () => {
    const mockDispatch = jest.fn();
    const mockAfterCreate = jest.fn();
    const values = { brand_name: "Test Brand" };

    const setTimeoutSpy = jest.spyOn(global, "setTimeout");

    createMacroClusterAndAssign(values, "micro-456", mockDispatch, mockAfterCreate);

    expect(setTimeoutSpy).toHaveBeenCalledWith(expect.any(Function), 10);

    setTimeoutSpy.mockRestore();
  });
});
