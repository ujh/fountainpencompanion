import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LoveButton } from "love-button/LoveButton";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

describe("LoveButton", () => {
  const url = "/ink_reviews/1/love";
  const server = setupServer();

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("shows an outlined heart and the count when not loved", () => {
    render(<LoveButton url={url} initialLoved={false} initialCount={3} />);

    const button = screen.getByRole("button", { name: "Love this review" });
    expect(button).toHaveAttribute("aria-pressed", "false");
    expect(button.querySelector("i")).toHaveClass("fa-heart-o");
    expect(screen.getByText("3")).toBeInTheDocument();
  });

  it("shows a filled heart when loved", () => {
    render(<LoveButton url={url} initialLoved={true} initialCount={3} />);

    const button = screen.getByRole("button", { name: "Remove love" });
    expect(button).toHaveAttribute("aria-pressed", "true");
    expect(button.querySelector("i")).toHaveClass("fa-heart");
  });

  it("loves the review and shows the count from the server", async () => {
    server.use(http.post(url, () => HttpResponse.json({ loved: true, loves_count: 5 })));
    render(<LoveButton url={url} initialLoved={false} initialCount={3} />);

    await userEvent.setup().click(screen.getByRole("button", { name: "Love this review" }));

    await waitFor(() => expect(screen.getByText("5")).toBeInTheDocument());
    expect(screen.getByRole("button", { name: "Remove love" })).toBeEnabled();
  });

  it("removes the love", async () => {
    server.use(http.delete(url, () => HttpResponse.json({ loved: false, loves_count: 2 })));
    render(<LoveButton url={url} initialLoved={true} initialCount={3} />);

    await userEvent.setup().click(screen.getByRole("button", { name: "Remove love" }));

    await waitFor(() => expect(screen.getByText("2")).toBeInTheDocument());
    expect(screen.getByRole("button", { name: "Love this review" })).toBeEnabled();
  });

  it("updates immediately and disables the button while the request is pending", async () => {
    let respond;
    server.use(http.post(url, () => new Promise((resolve) => (respond = resolve))));
    render(<LoveButton url={url} initialLoved={false} initialCount={3} />);

    await userEvent.setup().click(screen.getByRole("button", { name: "Love this review" }));

    const button = screen.getByRole("button", { name: "Remove love" });
    expect(button).toBeDisabled();
    expect(screen.getByText("4")).toBeInTheDocument();

    respond(HttpResponse.json({ loved: true, loves_count: 4 }));
    await waitFor(() => expect(button).toBeEnabled());
  });

  it("reverts when the request fails", async () => {
    server.use(http.post(url, () => new HttpResponse(null, { status: 500 })));
    render(<LoveButton url={url} initialLoved={false} initialCount={3} />);

    await userEvent.setup().click(screen.getByRole("button", { name: "Love this review" }));

    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Love this review" })).toBeEnabled()
    );
    expect(screen.getByText("3")).toBeInTheDocument();
  });
});
