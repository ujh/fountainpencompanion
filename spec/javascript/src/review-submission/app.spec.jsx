import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { rest } from "msw";
import { setupServer } from "msw/node";
import { App } from "review-submission/app";

describe("ReviewSubmission App", () => {
  const submitUrl = "/brands/1/inks/2/ink_review_submissions";
  const server = setupServer();

  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  it("renders the form with heading and submit button", () => {
    render(<App url={submitUrl} />);
    expect(screen.getByRole("heading", { name: "Submit a review" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Submit a review" })).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/Enter the URL/)).toBeInTheDocument();
  });

  it("shows success message on successful submission", async () => {
    server.use(
      rest.post(submitUrl, (req, res, ctx) => {
        return res(ctx.status(200));
      })
    );

    render(<App url={submitUrl} />);
    const user = userEvent.setup();
    const input = screen.getByPlaceholderText(/Enter the URL/);

    await user.type(input, "https://example.com/review");
    await user.click(screen.getByRole("button", { name: "Submit a review" }));

    await waitFor(() => {
      expect(screen.getByText(/Review submitted successfully/)).toBeInTheDocument();
    });
    expect(screen.getByText(/Review submitted successfully/)).toHaveClass("text-success");
    expect(input).toHaveValue("");
  });

  it("shows error message when submission fails with validation errors", async () => {
    server.use(
      rest.post(submitUrl, (req, res, ctx) => {
        return res(
          ctx.status(422),
          ctx.json({
            errors: [
              "Url Instagram URLs are not supported as image previews do not work for Instagram posts"
            ]
          })
        );
      })
    );

    render(<App url={submitUrl} />);
    const user = userEvent.setup();

    await user.type(
      screen.getByPlaceholderText(/Enter the URL/),
      "https://www.instagram.com/p/abc123"
    );
    await user.click(screen.getByRole("button", { name: "Submit a review" }));

    await waitFor(() => {
      expect(screen.getByText(/Instagram URLs are not supported/)).toBeInTheDocument();
    });
    expect(screen.getByText(/Instagram URLs are not supported/)).toHaveClass("text-danger");
    expect(screen.getByPlaceholderText(/Enter the URL/)).toHaveClass("is-invalid");
  });

  it("disables the button while submitting", async () => {
    let resolveRequest;
    server.use(
      rest.post(submitUrl, (req, res, ctx) => {
        return new Promise((resolve) => {
          resolveRequest = () => resolve(res(ctx.status(200)));
        });
      })
    );

    render(<App url={submitUrl} />);
    const user = userEvent.setup();

    await user.type(screen.getByPlaceholderText(/Enter the URL/), "https://example.com/review");
    await user.click(screen.getByRole("button", { name: "Submit a review" }));

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Submitting..." })).toBeDisabled();
    });

    resolveRequest();

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Submit a review" })).toBeEnabled();
    });
  });
});
