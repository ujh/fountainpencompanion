import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CurrentlyInked, storageKeyLayout } from "./CurrentlyInked";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CurrentlyInked />", () => {
  const server = setupServer(
    rest.get("/api/v1/currently_inked.json", (req, res, ctx) =>
      res(
        ctx.json({
          data: [
            {
              id: "82353",
              type: "currently_inked",
              attributes: {
                inked_on: "2022-09-11",
                archived_on: null,
                comment: "",
                last_used_on: "2022-09-23",
                pen_name: "Pilot Kaküno, transparent, M",
                ink_name: "Pilot Blue Black - bottle",
                used_today: false,
                daily_usage: 13,
                refillable: true,
                unarchivable: false,
                archived: false
              },
              relationships: {
                collected_ink: {
                  data: {
                    id: "18809",
                    type: "collected_ink"
                  }
                },
                collected_pen: {
                  data: {
                    id: "148",
                    type: "collected_pen"
                  }
                }
              }
            },
            {
              id: "83466",
              type: "currently_inked",
              attributes: {
                inked_on: "2023-04-21",
                archived_on: null,
                comment: null,
                last_used_on: "2023-04-21",
                pen_name: "Giants' Pens Pocket Pen, M (Magna Carta)",
                ink_name: "Montblanc Swan Illusion - sample",
                used_today: true,
                daily_usage: 1,
                refillable: true,
                unarchivable: false,
                archived: false
              },
              relationships: {
                collected_ink: {
                  data: {
                    id: "35623",
                    type: "collected_ink"
                  }
                },
                collected_pen: {
                  data: {
                    id: "72476",
                    type: "collected_pen"
                  }
                }
              }
            },
            {
              id: "83467",
              type: "currently_inked",
              attributes: {
                inked_on: "2023-04-21",
                archived_on: null,
                comment: "",
                last_used_on: null,
                pen_name: "Platinum #3776 Century, Chartres, UEF",
                ink_name: "Pilot Blue Black - bottle",
                used_today: false,
                daily_usage: 0,
                refillable: true,
                unarchivable: false,
                archived: false
              },
              relationships: {
                collected_ink: {
                  data: {
                    id: "18809",
                    type: "collected_ink"
                  }
                },
                collected_pen: {
                  data: {
                    id: "3",
                    type: "collected_pen"
                  }
                }
              }
            }
          ],
          included: [
            {
              id: "13148",
              type: "micro_cluster",
              attributes: {},
              relationships: {}
            },
            {
              id: "18809",
              type: "collected_ink",
              attributes: {
                brand_name: "Pilot",
                line_name: "",
                ink_name: "Blue Black",
                color: "#2f3074",
                archived: false
              },
              relationships: {
                micro_cluster: {
                  data: {
                    id: "13148",
                    type: "micro_cluster"
                  }
                }
              }
            },
            {
              id: "148",
              type: "collected_pen",
              attributes: {
                brand: "Pilot",
                model: "Kaküno",
                nib: "M",
                color: "transparent"
              },
              relationships: {}
            },
            {
              id: "17058",
              type: "micro_cluster",
              attributes: {},
              relationships: {
                macro_cluster: {
                  data: {
                    id: "1704",
                    type: "macro_cluster"
                  }
                }
              }
            },
            {
              id: "35623",
              type: "collected_ink",
              attributes: {
                brand_name: "Montblanc",
                line_name: "",
                ink_name: "Swan Illusion",
                color: "#c9ab91",
                archived: false
              },
              relationships: {
                micro_cluster: {
                  data: {
                    id: "17058",
                    type: "micro_cluster"
                  }
                }
              }
            },
            {
              id: "72476",
              type: "collected_pen",
              attributes: {
                brand: "Giants' Pens",
                model: "Pocket Pen",
                nib: "M (Magna Carta)",
                color: ""
              },
              relationships: {}
            },
            {
              id: "3",
              type: "collected_pen",
              attributes: {
                brand: "Platinum",
                model: "#3776 Century",
                nib: "UEF",
                color: "Chartres"
              },
              relationships: {}
            }
          ],
          meta: {
            pagination: {
              total_pages: 1,
              current_page: 1,
              next_page: null,
              prev_page: null
            }
          }
        })
      )
    )
  );

  beforeAll(() => {
    server.listen();
  });

  afterEach(() => {
    server.resetHandlers();
  });

  afterAll(() => server.close());

  it("renders the app", async () => {
    const { findByText } = setup(<CurrentlyInked />);

    const entry = await findByText("Giants' Pens Pocket Pen, M (Magna Carta)");
    expect(entry).toBeInTheDocument();
  });

  it("swaps to card layout when clicked", async () => {
    const { findByText, getByTitle, queryByText, user } = setup(
      <CurrentlyInked />
    );

    // Actions heading from the table should be visible
    const heading = await findByText("Actions");
    expect(heading).toBeInTheDocument();

    const cardLayoutButton = getByTitle("Card layout");
    await user.click(cardLayoutButton);

    // Actions heading from the table should not be visible anymore
    expect(queryByText("Actions")).not.toBeInTheDocument();
  });

  it("remembers layout from localStorage", async () => {
    localStorage.setItem(storageKeyLayout, "card");

    const { findByText, queryByText } = setup(<CurrentlyInked />);

    await findByText("Giants' Pens Pocket Pen, M (Magna Carta)");

    // Actions heading from the table should not be visible
    expect(queryByText("Actions")).not.toBeInTheDocument();
  });
});
