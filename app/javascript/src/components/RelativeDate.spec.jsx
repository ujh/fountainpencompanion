import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { add, formatISO9075 } from "date-fns";
import { RelativeDate } from "./RelativeDate";

describe("<RelativeDate>", () => {
  it("renders nothing when no date passed", () => {
    const { container } = render(<RelativeDate />);
    expect(container).toBeEmptyDOMElement();
  });

  it("shows today if date is today", () => {
    const today = new Date();
    const dateStr = formatISO9075(today, { representation: "date" });
    render(<RelativeDate date={dateStr} />);
    expect(screen.getByText("today")).toBeInTheDocument();
  });

  it("shows ' 1 day ago' if from yesterday", () => {
    const yesterday = add(new Date(), { days: -1 });
    const dateStr = formatISO9075(yesterday, { representation: "date" });
    render(<RelativeDate date={dateStr} />);
    expect(screen.getByText("1 day ago")).toBeInTheDocument();
  });

  it("shows an unparseable date as is", () => {
    render(<RelativeDate date="72026-10-07" />);
    expect(screen.getByText("72026-10-07")).toBeInTheDocument();
  });

  it("shows an unparseable date as is when absolute is the default", () => {
    render(<RelativeDate date="72026-10-07" relativeAsDefault={false} />);
    expect(screen.getByText("72026-10-07")).toBeInTheDocument();
  });

  it("shows the absolute date when clicking on it", async () => {
    const yesterday = add(new Date(), { days: -1 });
    const dateStr = formatISO9075(yesterday, { representation: "date" });
    render(<RelativeDate date={dateStr} />);
    await userEvent.click(screen.getByText("1 day ago"));
    expect(screen.getByText(dateStr)).toBeInTheDocument();
  });
});
