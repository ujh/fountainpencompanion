import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { UsageRecordForm } from "./UsageRecordForm";

// Mock react-select to make testing easier
jest.mock("react-select", () => {
  return function MockSelect({ inputId, options, value, onChange, placeholder }) {
    const allOptions = (options || []).flatMap((group) =>
      (group.options || []).map((opt) => ({ ...opt, groupLabel: group.label }))
    );
    return (
      <div data-testid="react-select">
        <label htmlFor={inputId} style={{ display: "none" }}>
          Currently inked
        </label>
        <select
          id={inputId}
          data-testid="select-element"
          value={value ? value.value : ""}
          onChange={(e) => {
            const selected = allOptions.find((o) => o.value === e.target.value);
            onChange(selected || null);
          }}
        >
          <option value="">{placeholder}</option>
          {(options || []).map((group) => (
            <optgroup key={group.label} label={group.label}>
              {group.options.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </div>
    );
  };
});

const activeEntry = {
  id: "1",
  type: "currently_inked",
  attributes: {
    inked_on: "2025-01-15",
    archived_on: null,
    pen_name: "Pilot Vanishing Point, M",
    ink_name: "Pilot Blue Black",
    used_today: false,
    daily_usage: 5,
    archived: false
  },
  relationships: {}
};

const archivedEntry = {
  id: "2",
  type: "currently_inked",
  attributes: {
    inked_on: "2025-06-01",
    archived_on: "2025-12-15",
    pen_name: "Lamy Safari, F",
    ink_name: "Diamine Oxblood",
    used_today: false,
    daily_usage: 10,
    archived: true
  },
  relationships: {}
};

const oldArchivedEntry = {
  id: "3",
  type: "currently_inked",
  attributes: {
    inked_on: "2020-01-01",
    archived_on: "2020-06-01",
    pen_name: "Old Pen, M",
    ink_name: "Old Ink",
    used_today: false,
    daily_usage: 2,
    archived: true
  },
  relationships: {}
};

const makeResponse = (data) => ({
  data,
  included: [],
  meta: {
    pagination: {
      total_pages: 1,
      current_page: 1,
      next_page: null,
      prev_page: null
    }
  }
});

const setup = (jsx) => {
  return {
    user: userEvent.setup(),
    ...render(jsx)
  };
};

describe("<UsageRecordForm />", () => {
  const server = setupServer(
    rest.get("/api/v1/currently_inked.json", (req, res, ctx) => {
      const archived = req.url.searchParams.get("filter[archived]");
      if (archived === "false") {
        return res(ctx.json(makeResponse([activeEntry])));
      } else if (archived === "true") {
        return res(ctx.json(makeResponse([archivedEntry, oldArchivedEntry])));
      }
      return res(ctx.json(makeResponse([])));
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders loading state initially", () => {
    setup(<UsageRecordForm />);
    expect(screen.getByText("Loading currently inked entries...")).toBeInTheDocument();
  });

  it("renders the form with only active entries by default", async () => {
    setup(<UsageRecordForm />);

    const select = await screen.findByLabelText("Currently inked");
    expect(select).toBeInTheDocument();

    expect(screen.getByText(/Pilot Blue Black/)).toBeInTheDocument();
    expect(screen.queryByText(/Diamine Oxblood/)).not.toBeInTheDocument();
  });

  it("shows archived entries when checkbox is checked", async () => {
    const { user } = setup(<UsageRecordForm />);

    await screen.findByLabelText("Currently inked");
    const checkbox = screen.getByLabelText("Include archived entries");
    await user.click(checkbox);

    expect(await screen.findByText(/Diamine Oxblood/)).toBeInTheDocument();
    expect(screen.getByText(/Old Ink/)).toBeInTheDocument();
  });

  it("removes archived entries when checkbox is unchecked", async () => {
    const { user } = setup(<UsageRecordForm />);

    await screen.findByLabelText("Currently inked");
    const checkbox = screen.getByLabelText("Include archived entries");
    await user.click(checkbox);

    expect(await screen.findByText(/Diamine Oxblood/)).toBeInTheDocument();

    await user.click(checkbox);
    expect(screen.queryByText(/Diamine Oxblood/)).not.toBeInTheDocument();
  });

  it("disables date picker until an entry is selected", async () => {
    setup(<UsageRecordForm />);

    const dateInput = await screen.findByLabelText("Date");
    expect(dateInput).toBeDisabled();
  });

  it("enables date picker after selecting an entry", async () => {
    const { user } = setup(<UsageRecordForm />);

    const select = await screen.findByLabelText("Currently inked");
    await user.selectOptions(select, "1");

    const dateInput = screen.getByLabelText("Date");
    expect(dateInput).not.toBeDisabled();
  });

  it("sets min/max on date picker for active entry", async () => {
    const { user } = setup(<UsageRecordForm />);

    const select = await screen.findByLabelText("Currently inked");
    await user.selectOptions(select, "1");

    const dateInput = screen.getByLabelText("Date");
    expect(dateInput.getAttribute("min")).toBe("2025-01-15");

    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, "0");
    const day = String(today.getDate()).padStart(2, "0");
    expect(dateInput.getAttribute("max")).toBe(`${year}-${month}-${day}`);
  });

  it("sets min/max on date picker for archived entry", async () => {
    const { user } = setup(<UsageRecordForm />);

    await screen.findByLabelText("Currently inked");
    await user.click(screen.getByLabelText("Include archived entries"));

    await screen.findByText(/Diamine Oxblood/);
    const select = screen.getByLabelText("Currently inked");
    await user.selectOptions(select, "2");

    const dateInput = screen.getByLabelText("Date");
    expect(dateInput.getAttribute("min")).toBe("2025-06-01");
    expect(dateInput.getAttribute("max")).toBe("2025-12-15");
  });

  it("disables submit button until both entry and date are selected", async () => {
    const { user } = setup(<UsageRecordForm />);

    const submitBtn = await screen.findByText("Add record");
    expect(submitBtn).toBeDisabled();

    const select = screen.getByLabelText("Currently inked");
    await user.selectOptions(select, "1");
    expect(submitBtn).toBeDisabled();
  });

  it("sets the form action to the correct path", async () => {
    const { user } = setup(<UsageRecordForm />);

    const select = await screen.findByLabelText("Currently inked");
    await user.selectOptions(select, "1");

    const form = select.closest("form");
    expect(form.getAttribute("action")).toBe("/currently_inked/1/usage_record");
  });
});
