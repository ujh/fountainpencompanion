import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { PenSuggestionWidget } from "dashboard/pen_suggestion_widget";

describe("PenSuggestionWidget", () => {
  describe("when not all pens are inked", () => {
    const server = setupServer(
      rest.get("/api/v1/collected_pens.json", (req, res, ctx) => {
        return res(
          ctx.json({
            data: [
              {
                id: 1,
                type: "collected_pen",
                attributes: {
                  brand: "Asa",
                  model: "Maya",
                  nib: "F",
                  color: "Teal",
                  inked: false,
                  usage: 1,
                  daily_usage: 1
                }
              }
            ],
            meta: {
              pagination: {
                total_pages: 1,
                current_page: 1
              }
            }
          })
        );
      })
    );

    beforeAll(() => server.listen());
    afterEach(() => server.resetHandlers());
    afterAll(() => server.close());

    it("renders the widget", async () => {
      render(<PenSuggestionWidget renderWhenInvisible />);
      await screen.findAllByText(/Pen suggestion/);
    });
  });

  describe("when all pens inked", () => {
    const server = setupServer(
      rest.get("/api/v1/collected_pens.json", (req, res, ctx) => {
        return res(
          ctx.json({
            data: [
              {
                id: 1,
                type: "collected_pen",
                attributes: {
                  brand: "Asa",
                  model: "Maya",
                  nib: "F",
                  color: "Teal",
                  inked: true,
                  usage: 1,
                  daily_usage: 1
                }
              }
            ],
            meta: {
              pagination: {
                total_pages: 1,
                current_page: 1
              }
            }
          })
        );
      })
    );

    beforeAll(() => server.listen());
    afterEach(() => server.resetHandlers());
    afterAll(() => server.close());

    it("notifies the user that all pens are already inked", async () => {
      render(<PenSuggestionWidget renderWhenInvisible />);
      await screen.findAllByText(/All pens are in use/);
    });
  });
});
