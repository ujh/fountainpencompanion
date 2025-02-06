import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { InksGroupedByBrandWidget } from "dashboard/inks_grouped_by_brand_widget";

describe("InksGroupedByBrandWidget", () => {
  const server = setupServer(
    rest.get("/dashboard/widgets/inks_grouped_by_brand.json", (req, res, ctx) => {
      return res(
        ctx.json({
          data: {
            attributes: { brands: [{ brand_name: "brand", count: 1 }] }
          }
        })
      );
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the widget", async () => {
    render(<InksGroupedByBrandWidget renderWhenInvisible />);
    await screen.findAllByText(/Your inks grouped by brand/);
  });
});
