import { render, screen } from "@testing-library/react";
import { InksSummaryWidget } from "dashboard/inks_summary_widget";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("InksSummaryWidget", () => {
  const server = setupServer(
    http.get("/dashboard/widgets/inks_summary.json", () => {
      return HttpResponse.json({
        data: {
          attributes: {
            count: 1,
            used: 1,
            swabbed: 1,
            archived: 1,
            inks_without_reviews: 1
          }
        }
      });
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
