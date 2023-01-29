// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import { ActionsCell } from "./ActionsCell";

const setup = (jsx, options) => {
  return render(
    <table>
      <tbody>
        <tr>{jsx}</tr>
      </tbody>
    </table>,
    options
  );
};

describe("<ActionsCell />", () => {
  it("combines brand, line and ink names", () => {
    const { getAllByRole } = setup(
      <ActionsCell
        id="1"
        brand_name="Pilot"
        line_name="Iroshizuku"
        ink_name="Kon-peki"
        archived={false}
      />
    );

    const [edit, archive] = getAllByRole("link");

    expect(edit.getAttribute("title")).toEqual(
      "Edit Pilot Iroshizuku Kon-peki"
    );
    expect(archive.getAttribute("title")).toEqual(
      "Archive Pilot Iroshizuku Kon-peki"
    );
  });

  it("inkludes kind if set", () => {
    const { getAllByRole } = setup(
      <ActionsCell
        id="1"
        brand_name="Pilot"
        line_name="Iroshizuku"
        ink_name="Kon-peki"
        kind="bottle"
        archived={false}
      />
    );

    const [edit, archive] = getAllByRole("link");

    expect(edit.getAttribute("title")).toEqual(
      "Edit Pilot Iroshizuku Kon-peki - bottle"
    );
    expect(archive.getAttribute("title")).toEqual(
      "Archive Pilot Iroshizuku Kon-peki - bottle"
    );
  });
});
