import { render, screen } from "@testing-library/react";
import { CurrentlyInkedSummaryWidget } from "dashboard/currently_inked_summary_widget";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("CurrentlyInkedSummaryWidget", () => {
  const server = setupServer(
    http.get("/dashboard/widgets/currently_inked_summary.json", () => {
      return HttpResponse.json({
        data: { attributes: { active: 1, total: 1, usage_records: 1 } }
      });
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the widget", async () => {
    render(<CurrentlyInkedSummaryWidget renderWhenInvisible />);
    await screen.findByText(/Currently inked pens/);
  });
});
