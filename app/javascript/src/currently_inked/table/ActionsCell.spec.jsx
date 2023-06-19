import React from "react";
import { render, screen } from "@testing-library/react";
import { ActionsCell } from "./ActionsCell";

describe("<ActionsCell />", () => {
  describe("refill button", () => {
    it("shows the refill button if refilling is possible", async () => {
      render(<ActionsCell id={1} refillable={true} />);
      const button = await screen.findByTitle("Refill this pen");
      expect(button).toBeInTheDocument();
      expect(button.getAttribute("href")).toEqual("/currently_inked/1/refill");
    });

    it("does not show the refill button if refilling is not possible", () => {
      render(<ActionsCell id={1} refillable={false} />);
      const button = screen.queryByTitle("Refill this pen");
      expect(button).not.toBeInTheDocument();
    });
  });

  describe("edit button", () => {
    it("shows the edit button", async () => {
      render(<ActionsCell id={1} />);
      const button = await screen.findByTitle("edit");
      expect(button).toBeInTheDocument();
      expect(button.getAttribute("href")).toEqual("/currently_inked/1/edit");
    });
  });

  describe("archive button", () => {
    it("shows the archive button", async () => {
      render(<ActionsCell id={1} />);
      const button = await screen.findByTitle("archive");
      expect(button).toBeInTheDocument();
      expect(button.getAttribute("href")).toEqual("/currently_inked/1/archive");
    });
  });
});
