import { render } from "@testing-library/react";
import { extraColumn } from "admin/micro-clusters/extraColumn";

describe("extraColumn", () => {
  it("renders a colored square div", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Diamine",
      ink_name: "Marine",
      color: "#40E0D0"
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toBeInTheDocument();
    expect(div.tagName).toBe("DIV");
  });

  it("applies the correct background color from the collected ink", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Pilot",
      ink_name: "Iroshizuku Kon-peki",
      color: "#1E90FF"
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toHaveStyle("background-color: #1E90FF");
  });

  it("applies the correct dimensions", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Monteverde",
      ink_name: "Olivine",
      color: "#808000"
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toHaveStyle("height: 45px");
    expect(div).toHaveStyle("width: 45px");
  });

  it("handles different color formats", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Noodler's",
      ink_name: "Black",
      color: "rgb(0, 0, 0)"
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toHaveStyle("background-color: rgb(0, 0, 0)");
  });

  it("handles undefined color gracefully", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Unknown",
      ink_name: "Unknown",
      color: undefined
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toBeInTheDocument();
    // When backgroundColor is undefined, browser normalizes it to transparent
    expect(div).toHaveStyle("background-color: rgba(0, 0, 0, 0)");
  });

  it("handles null color gracefully", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Unknown",
      ink_name: "Unknown",
      color: null
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toBeInTheDocument();
    // When backgroundColor is null, browser normalizes it to transparent
    expect(div).toHaveStyle("background-color: rgba(0, 0, 0, 0)");
  });

  it("handles empty string color", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Unknown",
      ink_name: "Unknown",
      color: ""
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toBeInTheDocument();
    // When backgroundColor is empty string, browser normalizes it to transparent
    expect(div).toHaveStyle("background-color: rgba(0, 0, 0, 0)");
  });

  it("renders with all style properties", () => {
    const collectedInk = {
      id: "1",
      brand_name: "Waterman",
      ink_name: "Serenity Blue",
      color: "#4169E1"
    };

    const { container } = render(extraColumn(collectedInk));
    const div = container.firstChild;

    expect(div).toHaveStyle({
      backgroundColor: "#4169E1",
      height: "45px",
      width: "45px"
    });
  });
});
