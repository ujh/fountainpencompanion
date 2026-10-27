import { render, screen } from "@testing-library/react";
import { PensSummaryWidget } from "dashboard/pens_summary_widget";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("PensSummaryWidget", () => {
  const server = setupServer(
    http.get("/dashboard/widgets/pens_summary.json", () => {
      return HttpResponse.json({ data: { attributes: { count: 1, archived: 1 } } });
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
