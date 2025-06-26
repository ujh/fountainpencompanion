import {
  getMicroClusters,
  ignoreCluster,
  assignCluster
} from "admin/pens-model-micro-clusters/microClusters";
import { getRequest, putRequest } from "fetch";
import { SET_LOADING_PERCENTAGE, SET_MICRO_CLUSTERS } from "admin/components/clustering/actions";

// Mock the fetch functions
jest.mock("fetch", () => ({
  getRequest: jest.fn(),
  putRequest: jest.fn()
}));

// Mock Jsona
jest.mock("jsona", () => {
  return jest.fn().mockImplementation(() => ({
    deserialize: jest.fn((data) => data.data || data)
  }));
});

describe("microClusters", () => {
  let mockDispatch;

  beforeEach(() => {
    mockDispatch = jest.fn();
    jest.clearAllMocks();
  });

  describe("getMicroClusters", () => {
    it("dispatches loading percentage and micro clusters on successful fetch", async () => {
      const mockResponse = {
        data: [
          {
            id: 1,
            model_variants: [
              { brand: "Pilot", model: "Metropolitan", color: "Black" },
              { brand: "Pilot", model: "Metropolitan", color: "Red" }
            ]
          }
        ],
        meta: {
          pagination: {
            current_page: 1,
            total_pages: 1,
            next_page: null
          }
        }
      };

      getRequest.mockResolvedValue({
        json: () => Promise.resolve(mockResponse)
      });

      await getMicroClusters(mockDispatch);

      // Wait for async operations
      await new Promise(process.nextTick);

      expect(getRequest).toHaveBeenCalledWith(
        "/admins/pens/model_micro_clusters.json?unassigned=true&without_ignored=true&page=1"
      );

      expect(mockDispatch).toHaveBeenCalledWith({
        type: SET_LOADING_PERCENTAGE,
        payload: 100
      });

      expect(mockDispatch).toHaveBeenCalledWith({
        type: SET_MICRO_CLUSTERS,
        payload: expect.arrayContaining([
          expect.objectContaining({
            id: 1,
            entries: expect.any(Array),
            grouped_entries: expect.any(Array)
          })
        ])
      });
    });

    it("handles multiple pages", async () => {
      const mockResponse1 = {
        data: [
          {
            id: 1,
            model_variants: [{ brand: "Pilot", model: "Metropolitan" }]
          }
        ],
        meta: {
          pagination: {
            current_page: 1,
            total_pages: 2,
            next_page: 2
          }
        }
      };

      const mockResponse2 = {
        data: [
          {
            id: 2,
            model_variants: [{ brand: "Lamy", model: "Safari" }]
          }
        ],
        meta: {
          pagination: {
            current_page: 2,
            total_pages: 2,
            next_page: null
          }
        }
      };

      getRequest
        .mockResolvedValueOnce({
          json: () => Promise.resolve(mockResponse1)
        })
        .mockResolvedValueOnce({
          json: () => Promise.resolve(mockResponse2)
        });

      await getMicroClusters(mockDispatch);

      // Wait for async operations
      await new Promise(process.nextTick);
      await new Promise(process.nextTick);

      expect(getRequest).toHaveBeenCalledTimes(2);
      expect(getRequest).toHaveBeenNthCalledWith(
        1,
        "/admins/pens/model_micro_clusters.json?unassigned=true&without_ignored=true&page=1"
      );
      expect(getRequest).toHaveBeenNthCalledWith(
        2,
        "/admins/pens/model_micro_clusters.json?unassigned=true&without_ignored=true&page=2"
      );

      expect(mockDispatch).toHaveBeenCalledWith({
        type: SET_LOADING_PERCENTAGE,
        payload: 50
      });

      expect(mockDispatch).toHaveBeenCalledWith({
        type: SET_LOADING_PERCENTAGE,
        payload: 100
      });
    });

    it("filters out clusters without model variants", async () => {
      const mockResponse = {
        data: [
          {
            id: 1,
            model_variants: [{ brand: "Pilot", model: "Metropolitan" }]
          },
          {
            id: 2,
            model_variants: []
          },
          {
            id: 3,
            model_variants: [{ brand: "Lamy", model: "Safari" }]
          }
        ],
        meta: {
          pagination: {
            current_page: 1,
            total_pages: 1,
            next_page: null
          }
        }
      };

      getRequest.mockResolvedValue({
        json: () => Promise.resolve(mockResponse)
      });

      await getMicroClusters(mockDispatch);

      // Wait for async operations
      await new Promise(process.nextTick);

      expect(mockDispatch).toHaveBeenCalledWith({
        type: SET_MICRO_CLUSTERS,
        payload: expect.arrayContaining([
          expect.objectContaining({ id: 1 }),
          expect.objectContaining({ id: 3 })
        ])
      });

      const setMicroClustersCall = mockDispatch.mock.calls.find(
        (call) => call[0].type === SET_MICRO_CLUSTERS
      );
      expect(setMicroClustersCall[0].payload).toHaveLength(2);
    });

    it("transforms data correctly", async () => {
      const mockResponse = {
        data: [
          {
            id: 1,
            name: "Test Cluster",
            model_variants: [
              { brand: "Pilot", model: "Metropolitan", color: "Black" },
              { brand: "Pilot", model: "Metropolitan", color: "Red" }
            ]
          }
        ],
        meta: {
          pagination: {
            current_page: 1,
            total_pages: 1,
            next_page: null
          }
        }
      };

      getRequest.mockResolvedValue({
        json: () => Promise.resolve(mockResponse)
      });

      await getMicroClusters(mockDispatch);

      // Wait for async operations
      await new Promise(process.nextTick);

      const setMicroClustersCall = mockDispatch.mock.calls.find(
        (call) => call[0].type === SET_MICRO_CLUSTERS
      );

      const cluster = setMicroClustersCall[0].payload[0];
      expect(cluster).toEqual({
        id: 1,
        name: "Test Cluster",
        entries: [
          { brand: "Pilot", model: "Metropolitan", color: "Black" },
          { brand: "Pilot", model: "Metropolitan", color: "Red" }
        ],
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan", color: "Black" }]
      });
      expect(cluster).not.toHaveProperty("model_variants");
    });
  });

  describe("ignoreCluster", () => {
    it("makes PUT request with correct parameters", async () => {
      const mockResponse = { success: true };
      putRequest.mockResolvedValue(mockResponse);

      const result = await ignoreCluster({ id: 123 });

      expect(putRequest).toHaveBeenCalledWith("/admins/pens/model_micro_clusters/123.json", {
        data: {
          type: "pens_model_micro_cluster",
          attributes: { ignored: true }
        }
      });

      expect(result).toBe(mockResponse);
    });

    it("handles cluster ID as string", async () => {
      const mockResponse = { success: true };
      putRequest.mockResolvedValue(mockResponse);

      await ignoreCluster({ id: "456" });

      expect(putRequest).toHaveBeenCalledWith(
        "/admins/pens/model_micro_clusters/456.json",
        expect.any(Object)
      );
    });
  });

  describe("assignCluster", () => {
    it("makes PUT request and transforms response correctly", async () => {
      const mockResponse = {
        data: {
          id: 1,
          type: "pens_model_micro_cluster",
          attributes: {
            name: "Test Cluster"
          },
          model_variants: [{ brand: "Pilot", model: "Metropolitan" }],
          model: {
            id: 100,
            name: "Test Model",
            model_micro_clusters: [
              {
                id: 1,
                model_variants: [{ brand: "Pilot", model: "Metropolitan" }]
              }
            ]
          }
        }
      };

      putRequest.mockResolvedValue({
        json: () => Promise.resolve(mockResponse)
      });

      const result = await assignCluster(1, 100);

      expect(putRequest).toHaveBeenCalledWith("/admins/pens/model_micro_clusters/1.json", {
        data: {
          id: 1,
          type: "pens_model_micro_cluster",
          attributes: { pens_model_id: 100 }
        }
      });

      expect(result).toEqual({
        id: 1,
        type: "pens_model_micro_cluster",
        attributes: { name: "Test Cluster" },
        entries: expect.any(Array),
        macro_cluster: expect.objectContaining({
          id: 100,
          name: "Test Model",
          micro_clusters: expect.arrayContaining([
            expect.objectContaining({
              id: 1,
              entries: expect.any(Array)
            })
          ])
        })
      });
    });

    it("handles string IDs", async () => {
      const mockResponse = {
        data: {
          id: 1,
          model_variants: [],
          model: {
            id: 100,
            model_micro_clusters: []
          }
        }
      };

      putRequest.mockResolvedValue({
        json: () => Promise.resolve(mockResponse)
      });

      await assignCluster("1", "100");

      expect(putRequest).toHaveBeenCalledWith("/admins/pens/model_micro_clusters/1.json", {
        data: {
          id: "1",
          type: "pens_model_micro_cluster",
          attributes: { pens_model_id: "100" }
        }
      });
    });

    it("transforms nested micro clusters correctly", async () => {
      const mockResponse = {
        data: {
          id: 1,
          model_variants: [{ brand: "Pilot", model: "Metropolitan" }],
          model: {
            id: 100,
            model_micro_clusters: [
              {
                id: 1,
                model_variants: [{ brand: "Pilot", model: "Metropolitan" }]
              },
              {
                id: 2,
                model_variants: [{ brand: "Pilot", model: "Metro" }]
              }
            ]
          }
        }
      };

      putRequest.mockResolvedValue({
        json: () => Promise.resolve(mockResponse)
      });

      const result = await assignCluster(1, 100);

      expect(result.macro_cluster.micro_clusters).toHaveLength(2);
      expect(result.macro_cluster.micro_clusters[0]).toHaveProperty("entries");
      expect(result.macro_cluster.micro_clusters[0]).not.toHaveProperty("model_variants");
      expect(result.macro_cluster.micro_clusters[1]).toHaveProperty("entries");
      expect(result.macro_cluster.micro_clusters[1]).not.toHaveProperty("model_variants");
    });
  });
});
