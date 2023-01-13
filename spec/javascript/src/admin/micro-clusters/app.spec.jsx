import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { App } from "admin/micro-clusters/App";

describe("Admin micro clusters app", () => {
  const server = setupServer(
    rest.get("/admins/micro_clusters.json", (req, res, ctx) => {
      return res(
        ctx.json({
          data: [
            {
              id: 1,
              type: "micro_cluster",
              attributes: {},
              relationships: {
                collected_inks: { data: [] },
                macro_cluster: { data: null },
              },
            },
          ],
          meta: {
            pagination: { current_page: 1, total_pages: 1, next_page: null },
          },
        })
      );
    }),
    rest.get("/admins/macro_clusters.json", (req, res, ctx) => {
      return res(
        ctx.json({
          data: [
            {
              id: 1,
              type: "macro_cluster",
              attributes: {},
              relationships: { micro_clusters: { data: [] } },
            },
          ],
          meta: {
            pagination: { current_page: 1, total_pages: 1, next_page: null },
          },
        })
      );
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the app", async () => {
    render(<App />);
    await screen.findByText("No clusters to assign.");
  });
});
