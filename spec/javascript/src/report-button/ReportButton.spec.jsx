import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";
import { ReportButton } from "report-button/ReportButton";

describe("ReportButton", () => {
  const url = "/ink_reviews/1/report";
  const server = setupServer();

  beforeAll(() => {
    server.listen();
    HTMLDialogElement.prototype.showModal = function () {
      this.open = true;
    };
    HTMLDialogElement.prototype.close = function () {
      this.open = false;
    };
  });
  afterEach(() => server.resetHandlers());
  afterAll(() => server.close());

  const renderButton = (props = {}) =>
    render(
      <ReportButton
        url={url}
        heading="Report a problem with this review"
        label="Report this review"
        icon={true}
        {...props}
      />
    );

  const openDialog = async (user, name = "Report this review") => {
    await user.click(screen.getByRole("button", { name }));
    return screen.getByRole("dialog", { name: "Report a problem with this review" });
  };

  it("renders an exclamation circle icon button", () => {
    renderButton();

    const button = screen.getByRole("button", { name: "Report this review" });
    expect(button.querySelector("i")).toHaveClass("fa-exclamation-circle");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("renders a text button without the icon", async () => {
    renderButton({ label: "Report an error", icon: false });

    const button = screen.getByRole("button", { name: "Report an error" });
    expect(button).toHaveTextContent("Report an error");
    expect(button.querySelector("i")).toBeNull();
  });

  it("opens the dialog with a required description field", async () => {
    const user = userEvent.setup();
    renderButton();

    const dialog = await openDialog(user);

    expect(dialog).toHaveAttribute("open");
    expect(screen.getByLabelText("What is wrong?")).toBeRequired();
    expect(screen.getByLabelText("What is wrong?")).toHaveAttribute("maxLength", "2000");
  });

  it("sends the description and thanks the user", async () => {
    let body;
    server.use(
      http.post(url, async ({ request }) => {
        body = await request.json();
        return new HttpResponse(null, { status: 200 });
      })
    );
    const user = userEvent.setup();
    renderButton();
    await openDialog(user);

    await user.type(screen.getByLabelText("What is wrong?"), "The video is gone");
    await user.click(screen.getByRole("button", { name: "Send report" }));

    await waitFor(() =>
      expect(screen.getByText("Thanks! Your report was sent.")).toBeInTheDocument()
    );
    expect(body).toEqual({ description: "The video is gone" });

    await user.click(screen.getByRole("button", { name: "Close" }));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("shows a fresh form when opened again after sending", async () => {
    server.use(http.post(url, () => new HttpResponse(null, { status: 200 })));
    const user = userEvent.setup();
    renderButton();
    await openDialog(user);
    await user.type(screen.getByLabelText("What is wrong?"), "The video is gone");
    await user.click(screen.getByRole("button", { name: "Send report" }));
    await user.click(await screen.findByRole("button", { name: "Close" }));

    await openDialog(user);

    expect(screen.getByLabelText("What is wrong?")).toHaveValue("");
  });

  it("shows the server's validation errors", async () => {
    server.use(
      http.post(url, () =>
        HttpResponse.json({ errors: ["Description can't be blank"] }, { status: 422 })
      )
    );
    const user = userEvent.setup();
    renderButton();
    await openDialog(user);

    await user.type(screen.getByLabelText("What is wrong?"), "   ");
    await user.click(screen.getByRole("button", { name: "Send report" }));

    await waitFor(() => expect(screen.getByText("Description can't be blank")).toBeInTheDocument());
    expect(screen.getByRole("button", { name: "Send report" })).toBeEnabled();
  });

  it("shows a generic error when the request fails and keeps the text", async () => {
    server.use(http.post(url, () => new HttpResponse(null, { status: 500 })));
    const user = userEvent.setup();
    renderButton();
    await openDialog(user);

    await user.type(screen.getByLabelText("What is wrong?"), "The video is gone");
    await user.click(screen.getByRole("button", { name: "Send report" }));

    await waitFor(() =>
      expect(screen.getByText("Sending the report failed. Please try again.")).toBeInTheDocument()
    );
    expect(screen.getByLabelText("What is wrong?")).toHaveValue("The video is gone");
  });

  it("disables sending while the request is pending", async () => {
    let respond;
    server.use(http.post(url, () => new Promise((resolve) => (respond = resolve))));
    const user = userEvent.setup();
    renderButton();
    await openDialog(user);

    await user.type(screen.getByLabelText("What is wrong?"), "The video is gone");
    await user.click(screen.getByRole("button", { name: "Send report" }));

    expect(screen.getByRole("button", { name: "Send report" })).toBeDisabled();
    respond(new HttpResponse(null, { status: 200 }));
    await waitFor(() =>
      expect(screen.getByText("Thanks! Your report was sent.")).toBeInTheDocument()
    );
  });

  it("closes without sending on cancel", async () => {
    const user = userEvent.setup();
    renderButton();
    await openDialog(user);

    await user.click(screen.getByRole("button", { name: "Cancel" }));

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
});
