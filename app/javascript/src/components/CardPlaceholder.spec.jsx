import React from "react";
import { render, act } from "@testing-library/react";
import { CardsPlaceholder } from "./CardsPlaceholder";

describe("<CardsPlaceholder />", () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it("only renders after a delay of 250ms", async () => {
    const { queryByTestId } = render(<CardsPlaceholder />);
    let placeholder = queryByTestId("cards-placeholder");
    expect(placeholder).toBeNull();

    act(() => jest.advanceTimersByTime(251));

    placeholder = queryByTestId("cards-placeholder");
    expect(placeholder).not.toBeNull();
    expect(placeholder).toBeVisible();
  });
});
