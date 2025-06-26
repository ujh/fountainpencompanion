import { getMicroClusters } from "admin/micro-clusters/microClusters";

import { rest } from "msw";
import { setupServer } from "msw/node";

describe("getMicroClusters", () => {
  const server = setupServer(
    rest.get("/admins/micro_clusters.json", (req, res, ctx) =>
      res(
        ctx.json({
          data: [
            {
              id: "1636",
              type: "micro_cluster",
              attributes: {
                simplified_brand_name: "MyText",
                simplified_line_name: "MyText",
                simplified_ink_name: "MyText1"
              },
              relationships: {
                macro_cluster: { data: null },
                collected_inks: {
                  data: [
                    { id: "10495", type: "collected_ink" },
                    { id: "10496", type: "collected_ink" }
                  ]
                }
              }
            }
          ],
          included: [
            {
              id: "10495",
              type: "collected_ink",
              attributes: {
                brand_name: "Diamine",
                line_name: "",
                ink_name: "Marine",
                maker: "",
                color: "#40E0D0"
              },
              relationships: {
                micro_cluster: { data: { id: "1636", type: "micro_cluster" } }
              }
            },
            {
              id: "10496",
              type: "collected_ink",
              attributes: {
                brand_name: "Diamine",
                line_name: "",
                ink_name: "Marine",
                maker: "",
                color: "#40E0D0"
              },
              relationships: {
                micro_cluster: { data: { id: "1636", type: "micro_cluster" } }
              }
            }
          ],
          meta: {
            pagination: {
              total_pages: 1,
              current_page: 1,
              next_page: null,
              prev_page: null
            }
          }
        })
      )
    )
  );

  beforeAll(() => {
    server.listen();
  });

  afterEach(() => {
    server.resetHandlers();
  });

  afterAll(() => server.close());

  it("loads and transforms the cluster data", (done) => {
    const dispatch = jest.fn();
    getMicroClusters(dispatch);
    setTimeout(() => {
      expect(dispatch).toHaveBeenCalled();
      const args = dispatch.mock.calls[0];
      expect(args).toHaveLength(1);
      const arg = args[0];
      expect(arg.type).toBe("SET_MICRO_CLUSTERS");
      const payload = arg.payload;
      expect(payload).toHaveLength(1);
      const microCluster = payload[0];
      expect(microCluster.entries).toHaveLength(2);
      expect(microCluster.grouped_entries).toHaveLength(1);
      done();
    }, 500);
  });
});
