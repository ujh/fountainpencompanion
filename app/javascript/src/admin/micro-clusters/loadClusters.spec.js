import { loadMicroClusters, loadMacroClusters } from "./loadClusters";

import { rest } from "msw";
import { setupServer } from "msw/node";

describe("loadMicroClusters", () => {
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
    loadMicroClusters(dispatch);
    setTimeout(() => {
      expect(dispatch).toHaveBeenCalled();
      const args = dispatch.mock.calls[0];
      expect(args).toHaveLength(1);
      const arg = args[0];
      expect(arg.type).toBe("SET_MICRO_CLUSTERS");
      const payload = arg.payload;
      expect(payload).toHaveLength(1);
      const microCluster = payload[0];
      expect(microCluster.collected_inks).toHaveLength(2);
      expect(microCluster.grouped_collected_inks).toHaveLength(1);
      done();
    }, 500);
  });
});

describe("loadMacroClusters", () => {
  const server = setupServer(
    rest.get("/admins/macro_clusters.json", (req, res, ctx) =>
      res(
        ctx.json({
          data: [
            {
              id: "4332",
              type: "macro_cluster",
              attributes: {
                brand_name: "brand_name",
                line_name: "line_name",
                ink_name: "ink_name_1",
                color: "#FFFFFF"
              },
              relationships: {
                micro_clusters: {
                  data: [{ id: "1637", type: "micro_cluster" }]
                }
              }
            }
          ],
          included: [
            {
              id: "10497",
              type: "collected_ink",
              attributes: {
                brand_name: "Diamine",
                line_name: "",
                ink_name: "Marine 1",
                maker: "",
                color: "#40E0D0"
              },
              relationships: {
                micro_cluster: { data: { id: "1637", type: "micro_cluster" } }
              }
            },
            {
              id: "10498",
              type: "collected_ink",
              attributes: {
                brand_name: "Diamine",
                line_name: "",
                ink_name: "Marine 2",
                maker: "",
                color: "#40E0D0"
              },
              relationships: {
                micro_cluster: { data: { id: "1637", type: "micro_cluster" } }
              }
            },

            {
              id: "1637",
              type: "micro_cluster",
              attributes: {},
              relationships: {
                collected_inks: {
                  data: [
                    { id: "10497", type: "collected_ink" },
                    { id: "10498", type: "collected_ink" }
                  ]
                },
                macro_cluster: { data: { id: "4332", type: "macro_cluster" } }
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
    loadMacroClusters(dispatch);
    setTimeout(() => {
      expect(dispatch.mock.calls).toHaveLength(2);
      const firstCall = dispatch.mock.calls[0][0];
      expect(firstCall.type).toBe("SET_LOADING_PERCENTAGE");
      const secondCall = dispatch.mock.calls[1][0];
      expect(secondCall.type).toBe("SET_MACRO_CLUSTERS");
      const payload = secondCall.payload;
      expect(payload).toHaveLength(1);
      const macroCluster = payload[0];
      expect(macroCluster.micro_clusters).toHaveLength(1);
      expect(macroCluster.grouped_collected_inks).toHaveLength(2);
      done();
    }, 500);
  });
});
