import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { UsageButton } from "currently_inked/components/UsageButton";
import { rest } from "msw";
import { setupServer } from "msw/node";

const jsonApiResponse = {
  data: {
    id: "42",
    type: "currently_inked",
    attributes: {
      used_today: true,
      daily_usage: 5,
      last_used_on: "2026-03-16",
      ink_name: "Test Ink",
      pen_name: "Test Pen"
    },
    relationships: {
      collected_ink: { data: { id: "1", type: "collected_ink" } },
      collected_pen: { data: { id: "2", type: "collected_pen" } }
    }
  },
  included: [
    {
      id: "1",
      type: "collected_ink",
      attributes: { brand_name: "Test", ink_name: "Ink", color: "#000" }
    },
    {
      id: "2",
      type: "collected_pen",
      attributes: { brand: "Test", model: "Pen" }
    }
  ]
};

const server = setupServer(
  rest.post("/currently_inked/42/usage_record.json", (req, res, ctx) => {
    return res(ctx.status(201), ctx.json(jsonApiResponse));
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe("UsageButton", () => {
  it("shows bookmark icon when not used today", () => {
    render(<UsageButton id="42" used={false} />);
    const button = screen.getByTitle("Record usage for today");
    expect(button.querySelector(".fa-bookmark")).toBeTruthy();
  });

  it("shows bookmark-o icon when already used today", () => {
    render(<UsageButton id="42" used={true} />);
    const el = screen.getByTitle("Already recorded usage for today");
    expect(el.querySelector(".fa-bookmark-o")).toBeTruthy();
  });

  it("is not clickable when already used today", () => {
    render(<UsageButton id="42" used={true} />);
    const el = screen.getByTitle("Already recorded usage for today");
    expect(el.tagName).toBe("DIV");
  });

  it("makes a POST request and calls onUsageRecorded on click", async () => {
    const onUsageRecorded = jest.fn();
    render(<UsageButton id="42" used={false} onUsageRecorded={onUsageRecorded} />);

    const button = screen.getByTitle("Record usage for today");
    await userEvent.click(button);

    await waitFor(() => {
      expect(onUsageRecorded).toHaveBeenCalledTimes(1);
    });

    const entry = onUsageRecorded.mock.calls[0][0];
    expect(entry.id).toBe("42");
    expect(entry.used_today).toBe(true);
    expect(entry.daily_usage).toBe(5);
  });
});
