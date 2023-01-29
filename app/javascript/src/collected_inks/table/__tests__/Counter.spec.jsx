// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import { Counter } from "../Counter";

describe("<Counter />", () => {
  it("renders the result if non-zero", () => {
    const { getByText } = render(
      <Counter
        data={{ bottle: 1, sample: 3, cartridge: 0, swab: 0 }}
        field="bottle"
      />
    );

    expect(getByText("1x bottle")).toBeInTheDocument();
  });

  it("renders nothing if zero", () => {
    const { queryByText } = render(
      <Counter
        data={{ bottle: 1, sample: 3, cartridge: 0, swab: 0 }}
        field="cartridge"
      />
    );

    expect(queryByText("cartridge")).not.toBeInTheDocument();
  });
});
