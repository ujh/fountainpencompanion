import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ActionsCell } from "./ActionsCell";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<ActionsCell />", () => {
  describe("usage button", () => {
    it("shows the correct button when used_today is true", async () => {
      render(<ActionsCell used_today={true} />);
      const button = await screen.findByTitle(
        "Already recorded usage for today"
      );
      expect(button).toBeInTheDocument();
    });

    it("shows the correct button when used_today is false", async () => {
      render(<ActionsCell used_today={false} id={1} />);
      const button = await screen.findByTitle("Record usage for today");
      expect(button).toBeInTheDocument();
      expect(button.getAttribute("href")).toEqual(
        "/currently_inked/1/usage_record"
      );
    });

    it("shows the correct button after clicking on it", async () => {
      const { user } = setup(<ActionsCell used_today={false} id={1} />);
      const button = await screen.findByTitle("Record usage for today");
      await user.click(button);
      const newButton = await screen.findByTitle(
        "Already recorded usage for today"
      );
      expect(newButton).toBeInTheDocument();
    });
  });

  describe("refill button", () => {
    it("shows the refill button if refilling is possible", async () => {
      render(<ActionsCell id={1} refillable={true} />);
      const button = await screen.findByTitle("Refill this pen");
      expect(button).toBeInTheDocument();
      expect(button.getAttribute("href")).toEqual("/currently_inked/1/refill");
    });

    it("does not show the refill button if refilling is not possible", async () => {
      render(<ActionsCell id={1} refillable={false} />);
      const button = await screen.queryByTitle("Refill this pen");
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
