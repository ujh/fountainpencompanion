import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";

import { LeaderboardRankingWidget } from "dashboard/leaderboard_ranking_widget";

describe("LeaderboardRankingWidget", () => {
  const server = setupServer(
    rest.get("/dashboard/widgets/leaderboard_ranking.json", (req, res, ctx) => {
      return res(
        ctx.json({
          data: {
            attributes: {
              inks: 1,
              bottles: 1,
              samples: 1,
              brands: 1,
              ink_review_submissions: 1,
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
    render(<LeaderboardRankingWidget renderWhenInvisible />);
    await screen.findAllByText(/You are in/);
  });
});
