import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { InksSummaryWidget } from "dashboard/inks_summary_widget";

describe("InksSummaryWidget", () => {
  const server = setupServer(
    rest.get("/dashboard/widgets/inks_summary.json", (req, res, ctx) => {
      return res(
        ctx.json({
          data: {
            attributes: {
              count: 1,
              used: 1,
              swabbed: 1,
              archived: 1,
              inks_without_reviews: 1,
            },
          },
        })
      );
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the widget", async () => {
    render(<InksSummaryWidget renderWhenInvisible />);
    await screen.findByText(/Collection/);
  });
});
