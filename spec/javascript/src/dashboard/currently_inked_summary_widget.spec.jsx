import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { CurrentlyInkedSummaryWidget } from "dashboard/currently_inked_summary_widget";

describe("CurrentlyInkedSummaryWidget", () => {
  const server = setupServer(
    rest.get(
      "/dashboard/widgets/currently_inked_summary.json",
      (req, res, ctx) => {
        return res(
          ctx.json({
            data: { attributes: { active: 1, total: 1, usage_records: 1 } }
          })
        );
      }
    )
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the widget", async () => {
    render(<CurrentlyInkedSummaryWidget renderWhenInvisible />);
    await screen.findByText(/Currently inked pens/);
    await setTimeout(500, "resolved");
  });
});
