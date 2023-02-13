import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

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

  describe("ink already in collection", () => {
    it("shows the add button", async () => {
      render(<App macro_cluster_id="in_collection" />);
      await screen.findByText("Add again?");
    });

    it("has a different text for the detail view", async () => {
      render(<App macro_cluster_id="in_collection" details={true} />);
      await screen.findByText("Add additional entries to collection?");
    });

    it("clicking shows the type selector", async () => {
      render(<App macro_cluster_id="in_collection" />);
      await screen.findByText("Add again?");
      const user = userEvent.setup();
      await user.click(screen.getByText("Add again?"));
      // Now we see the options
      await screen.findByText("bottle");
      await screen.findByText("sample");
      await screen.findByText("cartridge");
      await screen.findByText("swab");
    });
  });

  describe("ink not in collection", () => {
    it("shows the add button", async () => {
      render(<App macro_cluster_id="missing" />);
      await screen.findByText("Add to collection");
    });

    it("has the same text for detail view", async () => {
      render(<App macro_cluster_id="missing" details={true} />);
      await screen.findByText("Add to collection");
    });

    it("clicking shows the type selector", async () => {
      render(<App macro_cluster_id="missing" />);
      await screen.findByText("Add to collection");
      const user = userEvent.setup();
      await user.click(screen.getByText("Add to collection"));
      // Now we see the options
      await screen.findByText("bottle");
      await screen.findByText("sample");
      await screen.findByText("cartridge");
      await screen.findByText("swab");
    });
  });
});
