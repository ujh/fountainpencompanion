// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import { InkWithLink } from "./InkWithLink";

describe("<InkWithLink />", () => {
  it("renders a link if original ink ID is present", () => {
    const { getByRole } = render(
      <InkWithLink
        cell={{ value: "Blue", row: { original: { ink_id: "1" } } }}
      />
    );

    expect(getByRole("link")).toBeInTheDocument();
  });

  it("renders just the value if not given an original ink ID", () => {
    const { queryByRole } = render(
      <InkWithLink
        cell={{ value: "Blue", row: { original: { ink_id: undefined } } }}
      />
    );

    expect(queryByRole("link")).not.toBeInTheDocument();
  });
});
