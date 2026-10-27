import { act, render } from "@testing-library/react";
import { TablePlaceholder } from "./TablePlaceholder";

describe("<TablePlaceholder />", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("only renders after a delay of 250ms", async () => {
    const { queryByTestId } = render(<TablePlaceholder />);
    let placeholder = queryByTestId("table-placeholder");
    expect(placeholder).toBeNull();

    act(() => vi.advanceTimersByTime(251));

    placeholder = queryByTestId("table-placeholder");
    expect(placeholder).not.toBeNull();
    expect(placeholder).toBeVisible();
  });
});
