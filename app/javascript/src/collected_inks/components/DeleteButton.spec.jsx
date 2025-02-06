import React from "react";
import { render } from "@testing-library/react";
import { DeleteButton } from "./DeleteButton";

describe("<DeleteButton />", () => {
  it("renders nothing if archived false", () => {
    const { queryByRole } = render(<DeleteButton name="Pilot Blue" id="1" archived={false} />);

    const link = queryByRole("link");
    expect(link).toBeNull();
  });

  it("renders a button to delete if archived true", () => {
    const { getByRole } = render(<DeleteButton name="Pilot Blue" id="1" archived={true} />);

    const link = getByRole("link");

    expect(link.getAttribute("href")).toEqual("/collected_inks/1");
    expect(link.getAttribute("title")).toEqual("Delete Pilot Blue");
    expect(link.getAttribute("data-method")).toEqual("delete");
  });
});
