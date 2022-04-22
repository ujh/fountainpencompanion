import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { App } from "add-ink-button/app";

describe("App", () => {
  const server = setupServer(
    rest.get("/collected_inks.json", (req, res, ctx) => {
      const macro_cluster_id = req.url.searchParams.get(
        "filter[macro_cluster_id]"
      );
      switch (macro_cluster_id) {
        case "in_collection":
          return res(ctx.json({ data: ["item"] }));
        default:
          return res(ctx.json({ data: [] }));
      }
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("shows the button if the ink is not in the user's collection", async () => {
    render(<App macro_cluster_id="missing" />);
    await screen.findByText("Add to collection");
  });

  it("does not show button if the ink is in the user's collection", async () => {
    render(<App macro_cluster_id="in_collection" />);
    await screen.findByTestId("ink-in-collection");
  });
});
