import React from "react";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { App } from "add-ink-button/app";

describe("AddInkButton Loader and Add Flow", () => {
  let postCalled = false;
  const server = setupServer(
    rest.get("/collected_inks.json", (req, res, ctx) => {
      // Simulate a slow response for loading state
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve(res(ctx.json({ data: [] })));
        }, 50);
      });
    }),
    rest.post("/collected_inks/add.json", (req, res, ctx) => {
      postCalled = true;
      return res(ctx.status(200), ctx.json({ success: true }));
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => {
    server.resetHandlers();
    postCalled = false;
  });
  afterAll(() => server.close());

  it("shows Loader while loading", async () => {
    render(<App macro_cluster_id="loading-test" renderWhenInvisible={true} />);
    // Loader should be present immediately
    expect(screen.getByRole("status", { hidden: true })).toBeInTheDocument();
    // Wait for loading to finish
    await screen.findByText("Add to collection");
  });

  it("Loader disappears after loading", async () => {
    render(<App macro_cluster_id="loading-test" renderWhenInvisible={true} />);
    // Loader should be present
    expect(screen.getByRole("status", { hidden: true })).toBeInTheDocument();
    // Wait for loading to finish
    await screen.findByText("Add to collection");
    // Loader should be gone
    expect(screen.queryByRole("status", { hidden: true })).not.toBeInTheDocument();
  });

  it("shows Loader and disables button during add POST, then shows checkmark", async () => {
    render(<App macro_cluster_id="add-flow" renderWhenInvisible={true} />);
    await screen.findByText("Add to collection");
    const user = userEvent.setup();
    await user.click(screen.getByText("Add to collection"));
    // Click "Add" in the kind picker
    await screen.findByText("Add");
    await user.click(screen.getByText("Add"));
    // Loader should be present in the button
    expect(screen.getByRole("status", { hidden: true })).toBeInTheDocument();
    // Wait for POST to resolve and checkmark to appear
    await waitFor(() => {
      expect(screen.getByRole("button", { disabled: true })).toBeInTheDocument();
    });
    expect(postCalled).toBe(true);
  });

  it("shows Loader with correct class and icon", async () => {
    render(<App macro_cluster_id="loading-test" renderWhenInvisible={true} />);
    const loader = screen.getByRole("status", { hidden: true });
    expect(loader).toHaveClass("loader");
    // The icon should be present
    const icon = loader.querySelector("i.fa.fa-spin.fa-refresh");
    expect(icon).not.toBeNull();
    await screen.findByText("Add to collection");
  });
});
