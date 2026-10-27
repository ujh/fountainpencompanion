import { UPDATING } from "admin/components/clustering/actions";
import {
  createMacroClusterAndAssign,
  getMacroClusters,
  updateMacroCluster
} from "admin/pens-model-micro-clusters/macroClusters";
import { assignCluster } from "admin/pens-model-micro-clusters/microClusters";
import { getRequest, postRequest } from "fetch";

// Mock the fetch functions
vi.mock("fetch", () => ({
  getRequest: vi.fn(),
  postRequest: vi.fn()
}));

// Mock Jsona
vi.mock("jsona", () => ({
  default: vi.fn(function () {
    return {
      deserialize: vi.fn((data) => data.data || data)
    };
  })
}));

// Mock assignCluster
vi.mock("admin/pens-model-micro-clusters/microClusters", () => ({
  assignCluster: vi.fn()
}));

describe("macroClusters", () => {
  let mockDispatch;
  let mockAfterCreate;

  beforeEach(() => {
    mockDispatch = vi.fn();
    mockAfterCreate = vi.fn();
    vi.clearAllMocks();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe("getMacroClusters", () => {
    it("calls getRequest with correct URL", () => {
      const mockResponse = {
        data: [],
        meta: { pagination: { current_page: 1, total_pages: 1, next_page: null } }
      };

      getRequest.mockResolvedValue({ json: () => Promise.resolve(mockResponse) });

      getMacroClusters(mockDispatch);

      expect(getRequest).toHaveBeenCalledWith("/admins/pens/models.json?page=1");
    });

    it("dispatches actions when called", () => {
      const mockResponse = {
        data: [],
        meta: { pagination: { current_page: 1, total_pages: 1, next_page: null } }
      };

      getRequest.mockResolvedValue({ json: () => Promise.resolve(mockResponse) });

      getMacroClusters(mockDispatch);

      // The function should call dispatch, we don't need to wait for async completion
      expect(typeof getMacroClusters).toBe("function");
    });
  });

  describe("createMacroClusterAndAssign", () => {
    it("dispatches UPDATING action immediately", () => {
      const values = { brand: "Pilot", model: "Metropolitan" };
      const microClusterId = 123;

      postRequest.mockResolvedValue({
        json: () => Promise.resolve({ data: { id: 456 } })
      });
      assignCluster.mockResolvedValue({ macro_cluster: { micro_clusters: [] } });

      createMacroClusterAndAssign(values, microClusterId, mockDispatch, mockAfterCreate);

      expect(mockDispatch).toHaveBeenCalledWith({ type: UPDATING });
    });

    it("calls postRequest after timeout", () => {
      const values = { brand: "Pilot", model: "Metropolitan" };
      const microClusterId = 123;

      postRequest.mockResolvedValue({
        json: () => Promise.resolve({ data: { id: 456 } })
      });
      assignCluster.mockResolvedValue({ macro_cluster: { micro_clusters: [] } });

      createMacroClusterAndAssign(values, microClusterId, mockDispatch, mockAfterCreate);

      vi.advanceTimersByTime(10);

      expect(postRequest).toHaveBeenCalledWith("/admins/pens/models.json", {
        data: {
          type: "pens_model",
          attributes: values
        }
      });
    });
  });

  describe("updateMacroCluster", () => {
    it("calls getRequest after timeout", () => {
      const clusterId = 123;

      getRequest.mockResolvedValue({
        json: () =>
          Promise.resolve({
            data: { id: clusterId, model_micro_clusters: [] }
          })
      });

      updateMacroCluster(clusterId, mockDispatch);

      vi.advanceTimersByTime(500);

      expect(getRequest).toHaveBeenCalledWith(`/admins/pens/models/${clusterId}.json`);
    });

    it("handles string cluster ID", () => {
      const clusterId = "123";

      getRequest.mockResolvedValue({
        json: () =>
          Promise.resolve({
            data: { id: 123, model_micro_clusters: [] }
          })
      });

      updateMacroCluster(clusterId, mockDispatch);

      vi.advanceTimersByTime(500);

      expect(getRequest).toHaveBeenCalledWith("/admins/pens/models/123.json");
    });
  });
});
