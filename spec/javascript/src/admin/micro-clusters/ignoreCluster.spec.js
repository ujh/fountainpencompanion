import { ignoreCluster } from "admin/micro-clusters/ignoreCluster";

import { rest } from "msw";
import { setupServer } from "msw/node";

describe("ignoreCluster", () => {
  const server = setupServer(
    rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
      const microClusterId = req.params.id;
      const body = req.body;

      // Verify the request body format
      expect(body.data.type).toBe("micro_cluster");
      expect(body.data.attributes.ignored).toBe(true);

      return res(
        ctx.json({
          data: {
            id: microClusterId,
            type: "micro_cluster",
            attributes: {
              simplified_brand_name: "Brand",
              simplified_line_name: "Line",
              simplified_ink_name: "Ink",
              ignored: true
            }
          }
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

  it("sends correct PUT request to ignore a micro cluster", async () => {
    const cluster = { id: "123" };

    const response = await ignoreCluster(cluster);

    expect(response.ok).toBe(true);
  });

  it("handles different cluster IDs", async () => {
    const cluster = { id: "456" };

    const response = await ignoreCluster(cluster);

    expect(response.ok).toBe(true);
  });

  it("handles string cluster IDs", async () => {
    const cluster = { id: "abc-123" };

    const response = await ignoreCluster(cluster);

    expect(response.ok).toBe(true);
  });

  it("handles server errors gracefully", async () => {
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        return res(ctx.status(500), ctx.json({ error: "Internal server error" }));
      })
    );

    const cluster = { id: "123" };

    const response = await ignoreCluster(cluster);
    expect(response.ok).toBe(false);
    expect(response.status).toBe(500);
  });

  it("handles network errors", async () => {
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res) => {
        return res.networkError("Network error");
      })
    );

    const cluster = { id: "123" };

    await expect(ignoreCluster(cluster)).rejects.toThrow();
  });

  it("handles 404 errors when cluster doesn't exist", async () => {
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        return res(ctx.status(404), ctx.json({ error: "Cluster not found" }));
      })
    );

    const cluster = { id: "nonexistent" };

    const response = await ignoreCluster(cluster);
    expect(response.ok).toBe(false);
    expect(response.status).toBe(404);
  });

  it("handles validation errors", async () => {
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        return res(
          ctx.status(422),
          ctx.json({
            errors: {
              ignored: ["cannot be set for this cluster"]
            }
          })
        );
      })
    );

    const cluster = { id: "123" };

    const response = await ignoreCluster(cluster);
    expect(response.ok).toBe(false);
    expect(response.status).toBe(422);
  });

  it("sends request to correct URL path", async () => {
    const cluster = { id: "test-cluster-789" };

    let requestUrl;
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        requestUrl = req.url.pathname;
        return res(ctx.json({ data: { id: cluster.id, type: "micro_cluster" } }));
      })
    );

    await ignoreCluster(cluster);

    expect(requestUrl).toBe("/admins/micro_clusters/test-cluster-789.json");
  });

  it("verifies request payload structure", async () => {
    const cluster = { id: "payload-test" };

    let requestPayload;
    server.use(
      rest.put("/admins/micro_clusters/:id.json", (req, res, ctx) => {
        requestPayload = req.body;
        return res(ctx.json({ data: { id: cluster.id, type: "micro_cluster" } }));
      })
    );

    await ignoreCluster(cluster);

    expect(requestPayload).toEqual({
      data: {
        type: "micro_cluster",
        attributes: { ignored: true }
      }
    });
  });
});
