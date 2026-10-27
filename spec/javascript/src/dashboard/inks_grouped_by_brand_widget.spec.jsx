import { render, screen } from "@testing-library/react";
import { InksGroupedByBrandWidget } from "dashboard/inks_grouped_by_brand_widget";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("InksGroupedByBrandWidget", () => {
  const server = setupServer(
    http.get("/dashboard/widgets/inks_grouped_by_brand.json", () => {
      return HttpResponse.json({
        data: {
          attributes: { brands: [{ brand_name: "brand", count: 1 }] }
        }
      });
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
