import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { CollectedPens } from "./CollectedPens";

describe("<CollectedPens />", () => {
  const server = setupServer(
    rest.get("/api/v1/collected_pens.json", (req, res, ctx) => {
      const page = req.url.searchParams.get("page[number]");
      const meta = {
        pagination: { current_page: page, next_page: page == 1 ? 2 : null }
      };
      const data = [
        {
          id: 1,
          type: "collected_pen",
          attributes: {
            brand: "Faber-Castell",
            model: "Loom",
            nib: "B",
            color: "green"
          }
        }
      ];
      console.log({ data, meta });
      return res(ctx.json({ data, meta }));
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders all active pens", async () => {
    render(<CollectedPens />);
    await screen.findByText("Brand");
    // Header + Footer + 2 entries
    expect(screen.queryAllByRole("row")).toHaveLength(4);
  });
});
