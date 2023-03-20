import React from "react";
import { render, act } from "@testing-library/react";
import { TablePlaceholder } from "./TablePlaceholder";

describe("<TablePlaceholder />", () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it("only renders after a delay of 250ms", async () => {
    const { queryByTestId } = render(<TablePlaceholder />);
    let placeholder = queryByTestId("table-placeholder");
    expect(placeholder).toBeNull();

    act(() => jest.advanceTimersByTime(251));

    placeholder = queryByTestId("table-placeholder");
    expect(placeholder).not.toBeNull();
    expect(placeholder).toBeVisible();
  });
});
