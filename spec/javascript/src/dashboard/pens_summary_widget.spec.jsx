import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { PensSummaryWidget } from "dashboard/pens_summary_widget";

describe("PensSummaryWidget", () => {
  const server = setupServer(
    rest.get("/dashboard/widgets/pens_summary.json", (req, res, ctx) => {
      return res(ctx.json({ data: { attributes: { count: 1, archived: 1 } } }));
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the widget", async () => {
    render(<PensSummaryWidget renderWhenInvisible />);
    await screen.findByText(/Collection/);
  });
});
