import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectedInks, storageKeyLayout } from "./CollectedInks";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CollectedInks />", () => {
  const server = setupServer(
    rest.get("/collected_inks.json", (req, res, ctx) =>
      res(
        ctx.json({
          data: [
            {
              id: "4",
              type: "collected_ink",
              attributes: {
                brand_name: "Sailor",
                line_name: "Shikiori",
                ink_name: "Yozakura",
                maker: "Sailor",
                color: "#ac54b5",
                archived_on: null,
                comment:
                  "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                kind: "bottle",
                private: false,
                private_comment:
                  "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
                simplified_brand_name: "sailor",
                simplified_ink_name: "yozakura",
                simplified_line_name: "shikiori",
                swabbed: true,
                used: true,
                archived: false,
                ink_id: 3,
                usage: 2,
                daily_usage: 1
              },
              relationships: {
                micro_cluster: { data: { id: "3", type: "micro_cluster" } },
                tags: {
                  data: [
                    { id: "1", type: "tag" },
                    { id: "2", type: "tag" }
                  ]
                },
                currently_inkeds: {
                  data: [
                    { id: "1", type: "currently_inked" },
                    { id: "3", type: "currently_inked" }
                  ]
                }
              }
            },
            {
              id: "11",
              type: "collected_ink",
              attributes: {
                brand_name: "DeAtramentis",
                line_name: "Document",
                ink_name: "Black",
                maker: "",
                color: "#120e0e",
                archived_on: "2023-02-18",
                comment: "",
                kind: "",
                private: false,
                private_comment: "",
                simplified_brand_name: "deatramentis",
                simplified_ink_name: "black",
                simplified_line_name: "document",
                swabbed: false,
                used: false,
                archived: true,
                ink_id: 49,
                usage: 0,
                daily_usage: 0
              },
              relationships: {
                micro_cluster: { data: { id: "8", type: "micro_cluster" } },
                tags: { data: [] },
                currently_inkeds: { data: [] }
              }
            }
          ],
          included: [
            { id: "1", type: "tag", attributes: { name: "maximum" } },
            { id: "2", type: "tag", attributes: { name: "taggage" } }
          ]
        })
      )
    )
  );

  beforeAll(() => {
    localStorage.clear();
    server.listen();
  });

  afterEach(() => {
    localStorage.clear();
    server.resetHandlers();
  });

  afterAll(() => server.close());

  it("renders the app", async () => {
    const { findByText, queryByText } = setup(
      <CollectedInks archive={false} />
    );

    const result = await findByText("Yozakura");

    expect(result).toBeTruthy();
    // Does not show archived when archive=false
    expect(queryByText("DeAtramentis")).not.toBeInTheDocument();
  });

  it("swaps to card layout when clicked", async () => {
    const { findByText, getByTitle, getByTestId, user } = setup(
      <CollectedInks archive={false} />
    );

    await findByText("Yozakura");
    const cardLayoutButton = getByTitle("Card layout");
    await user.click(cardLayoutButton);

    // Mock response data from Yozakura, formated as in a card
    expect(getByTestId("usage")).toBeInTheDocument();
  });

  it("remembers layout from localStorage", async () => {
    localStorage.setItem(storageKeyLayout, "card");

    const { findByText, getByTestId } = setup(
      <CollectedInks archive={false} />
    );

    await findByText("Sailor Shikiori Yozakura");

    // Mock response data from Yozakura, formated as in a card
    expect(getByTestId("usage")).toBeInTheDocument();
  });

  it("renders the archive", async () => {
    const { findByText, queryByText } = setup(<CollectedInks archive={true} />);

    const result = await findByText("DeAtramentis");

    expect(result).toBeTruthy();
    // Does not show unarchived when archive=true
    expect(queryByText("Yozakura")).not.toBeInTheDocument();
  });
});
