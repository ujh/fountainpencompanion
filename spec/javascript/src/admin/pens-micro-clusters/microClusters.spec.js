import { ignoreCluster, assignCluster } from "admin/pens-micro-clusters/microClusters";
import * as fetchModule from "fetch";

// Mock the fetch functions
jest.mock("fetch", () => ({
  getRequest: jest.fn(),
  putRequest: jest.fn()
}));

// Mock Jsona
jest.mock("jsona", () => {
  return jest.fn().mockImplementation(() => ({
    deserialize: jest.fn()
  }));
});

describe("microClusters", () => {
  let mockPutRequest;

  beforeEach(() => {
    mockPutRequest = fetchModule.putRequest;
    jest.clearAllMocks();
  });

  describe("ignoreCluster", () => {
    it("sends PUT request to ignore cluster", async () => {
      const clusterId = 123;
      const mockResponse = { success: true };

      mockPutRequest.mockResolvedValue(mockResponse);

      const result = await ignoreCluster({ id: clusterId });

      expect(mockPutRequest).toHaveBeenCalledWith("/admins/pens/micro_clusters/123.json", {
        data: {
          type: "pens_micro_cluster",
          attributes: { ignored: true }
        }
      });
      expect(result).toBe(mockResponse);
    });

    it("handles string ID", async () => {
      const clusterId = "456";
      mockPutRequest.mockResolvedValue({});

      await ignoreCluster({ id: clusterId });

      expect(mockPutRequest).toHaveBeenCalledWith(
        "/admins/pens/micro_clusters/456.json",
        expect.any(Object)
      );
    });
  });

  describe("assignCluster", () => {
    it("sends PUT request with correct parameters", async () => {
      const microClusterId = 123;
      const macroClusterId = 456;

      const mockApiResponse = {
        data: {
          id: "123",
          type: "micro_cluster",
          attributes: {
            collected_pens: [{ id: 1, brand: "Pilot", model: "Metropolitan" }]
          }
        }
      };

      const mockDeserializedData = {
        id: 123,
        collected_pens: [{ id: 1, brand: "Pilot", model: "Metropolitan" }],
        model_variant: {
          id: 456,
          micro_clusters: [
            { id: 123, collected_pens: [{ id: 1, brand: "Pilot", model: "Metropolitan" }] }
          ]
        }
      };

      const Jsona = require("jsona");
      const mockJsona = { deserialize: jest.fn().mockReturnValue(mockDeserializedData) };
      Jsona.mockImplementation(() => mockJsona);

      mockPutRequest.mockResolvedValue({
        json: jest.fn().mockResolvedValue(mockApiResponse)
      });

      const result = await assignCluster(microClusterId, macroClusterId);

      expect(mockPutRequest).toHaveBeenCalledWith("/admins/pens/micro_clusters/123.json", {
        data: {
          id: microClusterId,
          type: "pens_micro_cluster",
          attributes: { pens_model_variant_id: macroClusterId }
        }
      });

      expect(result).toEqual(
        expect.objectContaining({
          id: 123,
          entries: expect.any(Array),
          macro_cluster: expect.any(Object)
        })
      );
    });

    it("transforms response data correctly", async () => {
      const microClusterId = 123;
      const macroClusterId = 456;

      const mockDeserializedData = {
        id: 123,
        collected_pens: [{ id: 1, brand: "Pilot", model: "Metropolitan" }],
        model_variant: {
          id: 456,
          micro_clusters: [
            { id: 123, collected_pens: [{ id: 1, brand: "Pilot", model: "Metropolitan" }] }
          ]
        }
      };

      const Jsona = require("jsona");
      const mockJsona = { deserialize: jest.fn().mockReturnValue(mockDeserializedData) };
      Jsona.mockImplementation(() => mockJsona);

      mockPutRequest.mockResolvedValue({
        json: jest.fn().mockResolvedValue({})
      });

      const result = await assignCluster(microClusterId, macroClusterId);

      // Should transform collected_pens to entries
      expect(result).toHaveProperty("entries");
      expect(result).not.toHaveProperty("collected_pens");

      // Should transform model_variant to macro_cluster
      expect(result).toHaveProperty("macro_cluster");
      expect(result).not.toHaveProperty("model_variant");

      // Should transform nested micro_clusters
      expect(result.macro_cluster.micro_clusters[0]).toHaveProperty("entries");
      expect(result.macro_cluster.micro_clusters[0]).not.toHaveProperty("collected_pens");
    });
  });
});
