import { ignoreCluster } from "admin/micro-clusters/ignoreCluster";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("ignoreCluster", () => {
  const server = setupServer(
    http.put("/admins/micro_clusters/:id.json", async ({ request, params }) => {
      const microClusterId = params.id;
      const body = await request.json();

      // Verify the request body format
      expect(body.data.type).toBe("micro_cluster");
      expect(body.data.attributes.ignored).toBe(true);

      return HttpResponse.json({
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
      });
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
      http.put("/admins/micro_clusters/:id.json", () => {
        return HttpResponse.json({ error: "Internal server error" }, { status: 500 });
      })
    );

    const cluster = { id: "123" };

    const response = await ignoreCluster(cluster);
    expect(response.ok).toBe(false);
    expect(response.status).toBe(500);
  });

  it("handles network errors", async () => {
    server.use(
      http.put("/admins/micro_clusters/:id.json", () => {
        return HttpResponse.error();
      })
    );

    const cluster = { id: "123" };

    await expect(ignoreCluster(cluster)).rejects.toThrow();
  });

  it("handles 404 errors when cluster doesn't exist", async () => {
    server.use(
      http.put("/admins/micro_clusters/:id.json", () => {
        return HttpResponse.json({ error: "Cluster not found" }, { status: 404 });
      })
    );

    const cluster = { id: "nonexistent" };

    const response = await ignoreCluster(cluster);
    expect(response.ok).toBe(false);
    expect(response.status).toBe(404);
  });

  it("handles validation errors", async () => {
    server.use(
      http.put("/admins/micro_clusters/:id.json", () => {
        return HttpResponse.json(
          {
            errors: {
              ignored: ["cannot be set for this cluster"]
            }
          },
          { status: 422 }
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
      http.put("/admins/micro_clusters/:id.json", ({ request }) => {
        requestUrl = new URL(request.url).pathname;
        return HttpResponse.json({ data: { id: cluster.id, type: "micro_cluster" } });
      })
    );

    await ignoreCluster(cluster);

    expect(requestUrl).toBe("/admins/micro_clusters/test-cluster-789.json");
  });

  it("verifies request payload structure", async () => {
    const cluster = { id: "payload-test" };

    let requestPayload;
    server.use(
      http.put("/admins/micro_clusters/:id.json", async ({ request }) => {
        requestPayload = await request.json();
        return HttpResponse.json({ data: { id: cluster.id, type: "micro_cluster" } });
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
