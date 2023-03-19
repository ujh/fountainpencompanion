import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectedPens, storageKeyLayout } from "./CollectedPens";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CollectedPens />", () => {
  const server = setupServer(
    rest.get("/api/v1/collected_pens.json", (req, res, ctx) => {
      const page = req.url.searchParams.get("page[number]");
      const meta = {
        pagination: { current_page: page, next_page: page == 1 ? 2 : null }
      };
      const data = [
        {
          id: 1,
          type: "collected_pen",
          attributes: {
            brand: "Faber-Castell",
            model: "Loom",
            nib: "B",
            color: "green"
          }
        }
      ];
      return res(ctx.json({ data, meta }));
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders all active pens", async () => {
    const { findByText, queryAllByRole } = setup(<CollectedPens />);
    await findByText("Brand");
    // Header + Footer + 2 entries
    expect(queryAllByRole("row")).toHaveLength(4);
  });

  it("swaps to card layout when clicked", async () => {
    const { findByText, getByTitle, queryByTestId, user } = setup(
      <CollectedPens />
    );

    await findByText("Brand");
    const cardLayoutButton = getByTitle("Card layout");
    await user.click(cardLayoutButton);

    expect(queryByTestId("card-layout")).toBeInTheDocument();
  });

  it("remembers layout from localStorage", async () => {
    localStorage.setItem(storageKeyLayout, "card");

    const { findAllByText, queryByTestId } = setup(<CollectedPens />);

    await findAllByText("Faber-Castell Loom");

    expect(queryByTestId("card-layout")).toBeInTheDocument();
  });
});
