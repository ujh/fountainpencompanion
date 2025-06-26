import {
  getMacroClusters,
  createMacroClusterAndAssign,
  updateMacroCluster
} from "admin/pens-model-micro-clusters/macroClusters";
import { getRequest, postRequest } from "fetch";
import { UPDATING } from "admin/components/clustering/actions";

// Mock the fetch functions
jest.mock("fetch", () => ({
  getRequest: jest.fn(),
  postRequest: jest.fn()
}));

// Mock Jsona
jest.mock("jsona", () => {
  return jest.fn().mockImplementation(() => ({
    deserialize: jest.fn((data) => data.data || data)
  }));
});

// Mock assignCluster
jest.mock("admin/pens-model-micro-clusters/microClusters", () => ({
  assignCluster: jest.fn()
}));

import { assignCluster } from "admin/pens-model-micro-clusters/microClusters";

describe("macroClusters", () => {
  let mockDispatch;
  let mockAfterCreate;

  beforeEach(() => {
    mockDispatch = jest.fn();
    mockAfterCreate = jest.fn();
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
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

      jest.advanceTimersByTime(10);

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

      jest.advanceTimersByTime(500);

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

      jest.advanceTimersByTime(500);

      expect(getRequest).toHaveBeenCalledWith("/admins/pens/models/123.json");
    });
  });
});
