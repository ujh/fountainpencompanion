import { assignCluster } from "admin/micro-clusters/assignCluster";

import { rest } from "msw";
import { setupServer } from "msw/node";

describe("assignCluster", () => {
  const server = setupServer(
    rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
      const microClusterId = req.params.id;
      const body = req.body;

      // Verify the request body format
      expect(body.data.id).toBe(microClusterId);
      expect(body.data.type).toBe("micro_cluster");
      expect(body.data.attributes.macro_cluster_id).toBe("123");

      return res(
        ctx.json({
          data: {
            id: microClusterId,
            type: "micro_cluster",
            attributes: {
              simplified_brand_name: "Brand",
              simplified_line_name: "Line",
              simplified_ink_name: "Ink"
            },
            relationships: {
              macro_cluster: { data: { id: "123", type: "macro_cluster" } },
              collected_inks: {
                data: [
                  { id: "1001", type: "collected_ink" },
                  { id: "1002", type: "collected_ink" }
                ]
              }
            }
          },
          included: [
            {
              id: "1001",
              type: "collected_ink",
              attributes: {
                brand_name: "Diamine",
                line_name: "Standard",
                ink_name: "Blue",
                maker: "",
                color: "#0000FF"
              },
              relationships: {
                micro_cluster: { data: { id: microClusterId, type: "micro_cluster" } }
              }
            },
            {
              id: "1002",
              type: "collected_ink",
              attributes: {
                brand_name: "Diamine",
                line_name: "Standard",
                ink_name: "Blue",
                maker: "",
                color: "#0000FF"
              },
              relationships: {
                micro_cluster: { data: { id: microClusterId, type: "micro_cluster" } }
              }
            },
            {
              id: "123",
              type: "macro_cluster",
              attributes: {
                brand_name: "Diamine",
                line_name: "Standard",
                ink_name: "Blue",
                color: "#0000FF"
              },
              relationships: {
                micro_clusters: {
                  data: [
                    { id: microClusterId, type: "micro_cluster" },
                    { id: "999", type: "micro_cluster" }
                  ]
                }
              }
            },
            {
              id: "999",
              type: "micro_cluster",
              attributes: {
                simplified_brand_name: "Another Brand",
                simplified_line_name: "Another Line",
                simplified_ink_name: "Another Ink"
              },
              relationships: {
                macro_cluster: { data: { id: "123", type: "macro_cluster" } },
                collected_inks: {
                  data: [{ id: "2001", type: "collected_ink" }]
                }
              }
            },
            {
              id: "2001",
              type: "collected_ink",
              attributes: {
                brand_name: "Pilot",
                line_name: "Iroshizuku",
                ink_name: "Kon-peki",
                maker: "",
                color: "#1E90FF"
              },
              relationships: {
                micro_cluster: { data: { id: "999", type: "micro_cluster" } }
              }
            }
          ]
        })
      );
    })
  );

  beforeAll(() => {
    server.listen();
  });

  afterEach(() => {
    server.resetHandlers();
  });

  afterAll(() => server.close());

  it("assigns a micro cluster to a macro cluster and transforms the response", async () => {
    const result = await assignCluster("456", "123");

    // Verify the micro cluster structure
    expect(result.id).toBe("456");
    expect(result.type).toBe("micro_cluster");

    // Verify collected_inks was renamed to entries
    expect(result.entries).toBeDefined();
    expect(result.collected_inks).toBeUndefined();
    expect(result.entries).toHaveLength(2);

    // Verify macro cluster relationship
    expect(result.macro_cluster).toBeDefined();
    expect(result.macro_cluster.id).toBe("123");
    expect(result.macro_cluster.micro_clusters).toHaveLength(2);

    // Verify micro clusters in the macro cluster also have entries instead of collected_inks
    result.macro_cluster.micro_clusters.forEach((mc) => {
      expect(mc.entries).toBeDefined();
      expect(mc.collected_inks).toBeUndefined();
    });
  });

  it("handles server errors gracefully", async () => {
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ error: "Internal server error" }));
      })
    );

    await expect(assignCluster("456", "123")).rejects.toThrow();
  });

  it("handles malformed JSON responses", async () => {
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        return res(ctx.text("Invalid JSON"));
      })
    );

    await expect(assignCluster("456", "123")).rejects.toThrow();
  });
});
