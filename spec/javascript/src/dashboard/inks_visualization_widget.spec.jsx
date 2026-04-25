import { render, screen } from "@testing-library/react";
import { InksVisualizationWidget } from "dashboard/inks_visualization_widget";
import { rest } from "msw";
import { setupServer } from "msw/node";

describe("InksVisualizationWidget", () => {
  const server = setupServer(
    rest.get("/collected_inks.json", (req, res, ctx) => {
      return res(
        ctx.json({
          data: [{ id: 1, attributes: { archived: false, color: "#FFF" } }]
        })
      );
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the widget", async () => {
    render(<InksVisualizationWidget renderWhenInvisible />);
    await screen.findAllByText(/Include archived inks/);
  });
});
