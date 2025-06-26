import React from "react";
import { render, screen } from "@testing-library/react";
import { SearchLink } from "./SearchLink";

describe("SearchLink", () => {
  const mockEntry = {
    brand: "Pilot",
    line: "Iroshizuku",
    name: "Tsuki-yo"
  };

  it("renders a link with correct href", () => {
    render(<SearchLink e={mockEntry} fields={["brand", "line", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute(
      "href",
      "https://google.com/search?q=Pilot%20Iroshizuku%20Tsuki-yo"
    );
  });

  it("opens in new tab with correct security attributes", () => {
    render(<SearchLink e={mockEntry} fields={["brand", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("target", "_blank");
    expect(link).toHaveAttribute("rel", "noreferrer");
  });

  it("renders the external link icon", () => {
    render(<SearchLink e={mockEntry} fields={["brand"]} />);

    const icon = document.querySelector(".fa-external-link");
    expect(icon).toBeInTheDocument();
    expect(icon).toHaveClass("fa", "fa-external-link");
  });

  it("handles single field correctly", () => {
    render(<SearchLink e={mockEntry} fields={["brand"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot");
  });

  it("handles multiple fields correctly", () => {
    render(<SearchLink e={mockEntry} fields={["brand", "line"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot%20Iroshizuku");
  });

  it("encodes special characters in URL", () => {
    const entryWithSpecialChars = {
      brand: "Diamine",
      name: "Writer's Blood & Tears"
    };

    render(<SearchLink e={entryWithSpecialChars} fields={["brand", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute(
      "href",
      "https://google.com/search?q=Diamine%20Writer's%20Blood%20%26%20Tears"
    );
  });

  it("handles empty field values", () => {
    const entryWithEmpty = {
      brand: "Pilot",
      line: "",
      name: "Tsuki-yo"
    };

    render(<SearchLink e={entryWithEmpty} fields={["brand", "line", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot%20%20Tsuki-yo");
  });

  it("handles undefined field values", () => {
    const entryWithUndefined = {
      brand: "Pilot",
      name: "Tsuki-yo"
      // line is undefined
    };

    render(<SearchLink e={entryWithUndefined} fields={["brand", "line", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot%20%20Tsuki-yo");
  });

  it("handles empty fields array", () => {
    render(<SearchLink e={mockEntry} fields={[]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=");
  });

  it("handles numeric values in fields", () => {
    const entryWithNumbers = {
      brand: "Pilot",
      model: 823,
      size: "F"
    };

    render(<SearchLink e={entryWithNumbers} fields={["brand", "model", "size"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot%20823%20F");
  });

  it("handles non-existent fields gracefully", () => {
    render(<SearchLink e={mockEntry} fields={["brand", "nonexistent", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot%20%20Tsuki-yo");
  });

  it("handles unicode characters correctly", () => {
    const entryWithUnicode = {
      brand: "Pilot",
      name: "月夜"
    };

    render(<SearchLink e={entryWithUnicode} fields={["brand", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute("href", "https://google.com/search?q=Pilot%20%E6%9C%88%E5%A4%9C");
  });

  it("handles whitespace in field values", () => {
    const entryWithSpaces = {
      brand: "  Pilot  ",
      name: "  Tsuki-yo  "
    };

    render(<SearchLink e={entryWithSpaces} fields={["brand", "name"]} />);

    const link = screen.getByRole("link");
    expect(link).toHaveAttribute(
      "href",
      "https://google.com/search?q=%20%20Pilot%20%20%20%20%20Tsuki-yo%20%20"
    );
  });
});
