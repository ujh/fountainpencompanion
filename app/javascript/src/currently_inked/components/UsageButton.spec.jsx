// @ts-check
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";
import { UsageButton } from "./UsageButton";

const jsonApiResponse = {
  data: {
    id: "1",
    type: "currently_inked",
    attributes: {
      used_today: true,
      daily_usage: 3,
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
  http.post("/currently_inked/1/usage_record.json", () => {
    return HttpResponse.json(jsonApiResponse, { status: 201 });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe("<UsageButton />", () => {
  it("shows the correct button when used_today is true", async () => {
    render(<UsageButton used={true} id={1} />);
    const button = await screen.findByTitle("Already recorded usage for today");
    expect(button).toBeInTheDocument();
    expect(button.querySelector(".fa-bookmark-o")).toBeTruthy();
  });

  it("shows the correct button when used_today is false", async () => {
    render(<UsageButton used={false} id={1} />);
    const button = await screen.findByTitle("Record usage for today");
    expect(button).toBeInTheDocument();
    expect(button.querySelector(".fa-bookmark")).toBeTruthy();
  });

  it("calls onUsageRecorded with updated entry after clicking", async () => {
    const onUsageRecorded = vi.fn();
    render(<UsageButton used={false} id={1} onUsageRecorded={onUsageRecorded} />);

    const button = await screen.findByTitle("Record usage for today");
    await userEvent.click(button);

    await waitFor(() => {
      expect(onUsageRecorded).toHaveBeenCalledTimes(1);
    });

    const entry = onUsageRecorded.mock.calls[0][0];
    expect(entry.id).toBe("1");
    expect(entry.used_today).toBe(true);
    expect(entry.daily_usage).toBe(3);
  });

  it("handles network errors gracefully", async () => {
    server.use(
      http.post("/currently_inked/1/usage_record.json", () => {
        return HttpResponse.error();
      })
    );
    render(<UsageButton used={false} id={1} />);
    const button = await screen.findByTitle("Record usage for today");
    await userEvent.click(button);
    await waitFor(() => {
      expect(screen.getByTitle("Record usage for today")).toBeInTheDocument();
    });
  });

  it("is not clickable when already used today", () => {
    render(<UsageButton used={true} id={1} />);
    const el = screen.getByTitle("Already recorded usage for today");
    expect(el.tagName).toBe("DIV");
  });
});
