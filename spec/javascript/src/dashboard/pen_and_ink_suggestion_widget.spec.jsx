import { act, fireEvent, render, screen } from "@testing-library/react";
import {
  ERROR_MESSAGE,
  GATE_NOTE,
  PenAndInkSuggestionWidget,
  THROTTLED_MESSAGE,
  TIMEOUT_MESSAGE
} from "dashboard/pen_and_ink_suggestion_widget";
import { getRequest } from "fetch";

jest.mock("fetch", () => ({ getRequest: jest.fn() }));

const SUGGESTION_PATH = "/dashboard/widgets/pen_and_ink_suggestion.json";
const SETTINGS_PATH = "/dashboard/widgets/pen_and_ink_suggestion_settings.json";

const response = (body, status = 200) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => body
});

const pair = (inkId, penId, message = "Use the <b>Pilot</b>") => ({
  message,
  ink: { id: inkId },
  pen: { id: penId }
});

describe("PenAndInkSuggestionWidget", () => {
  let instructionsAllowed;
  let enqueueResponse;
  let pollResponses;
  let enqueueCount;

  const advance = async (ms) => {
    await act(async () => {
      await jest.advanceTimersByTimeAsync(ms);
    });
  };

  const renderWidget = async () => {
    const view = render(<PenAndInkSuggestionWidget renderWhenInvisible />);
    await advance(0);
    return view;
  };

  const requestedUrls = () => getRequest.mock.calls.map(([url]) => url);
  const enqueueUrls = () =>
    requestedUrls().filter((url) => url.startsWith(SUGGESTION_PATH) && !isPoll(url));
  const pollUrls = () => requestedUrls().filter(isPoll);
  const isPoll = (url) => url.includes("suggestion_id=");

  const clickButton = async (name) => {
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name }));
      await jest.advanceTimersByTimeAsync(0);
    });
  };

  const askAndPoll = async (name, polls) => {
    pollResponses.push(...polls);
    await clickButton(name);
    await advance(polls.length * 1000);
  };

  beforeEach(() => {
    jest.useFakeTimers();
    instructionsAllowed = true;
    enqueueResponse = null;
    pollResponses = [];
    enqueueCount = 0;
    getRequest.mockReset();
    getRequest.mockImplementation(async (url) => {
      if (url === SETTINGS_PATH) {
        return response({
          data: {
            attributes: {
              instructions_allowed: instructionsAllowed,
              instructions_max_length: 500
            }
          }
        });
      }
      if (isPoll(url)) return pollResponses.length > 0 ? pollResponses.shift() : response({});
      enqueueCount += 1;
      return enqueueResponse ?? response({ suggestion_id: `suggestion-${enqueueCount}` });
    });
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe("instruction gate", () => {
    it("loads the gate before anything is requested", async () => {
      await renderWidget();

      expect(requestedUrls()).toEqual([SETTINGS_PATH]);
    });

    it("shows a textarea limited to the server's maximum length when instructions are allowed", async () => {
      await renderWidget();

      expect(screen.getByRole("textbox", { name: "Extra instructions" })).toHaveAttribute(
        "maxLength",
        "500"
      );
      expect(screen.queryByText(GATE_NOTE)).not.toBeInTheDocument();
    });

    it("replaces the textarea with the gate note when instructions are not allowed", async () => {
      instructionsAllowed = false;

      await renderWidget();

      expect(screen.getByText(GATE_NOTE)).toBeInTheDocument();
      expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
    });

    it("sends no instruction when instructions are not allowed", async () => {
      instructionsAllowed = false;
      await renderWidget();

      await clickButton("Suggest something!");

      expect(enqueueUrls()).toEqual([SUGGESTION_PATH]);
    });
  });

  describe("polling", () => {
    it("polls the suggestion id every second until a result with a message arrives", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [response({}), response({}), response(pair(1, 2))]);

      expect(pollUrls()).toEqual([
        `${SUGGESTION_PATH}?suggestion_id=suggestion-1`,
        `${SUGGESTION_PATH}?suggestion_id=suggestion-1`,
        `${SUGGESTION_PATH}?suggestion_id=suggestion-1`
      ]);
      expect(screen.getByText("Pilot")).toBeInTheDocument();

      await advance(5000);

      expect(pollUrls()).toHaveLength(3);
    });

    it("shows a spinner while polling", async () => {
      const { container } = await renderWidget();

      await clickButton("Suggest something!");

      expect(container.querySelector(".loader")).toBeInTheDocument();
      expect(screen.queryByRole("button")).not.toBeInTheDocument();
    });

    it("links a suggested pair to a new currently inked entry", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [response(pair(1, 2))]);

      expect(screen.getByRole("link", { name: "Ink it Up!" })).toHaveAttribute(
        "href",
        "/currently_inked/new?collected_ink_id=1&collected_pen_id=2"
      );
      expect(screen.getByRole("button", { name: "Try again!" })).toBeInTheDocument();
      expect(screen.getByText(/Results provided by an AI/)).toBeInTheDocument();
    });

    it("hides Ink it Up! for a message-only result", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [response({ message: "All your pens are inked." })]);

      expect(screen.getByText("All your pens are inked.")).toBeInTheDocument();
      expect(screen.queryByRole("link", { name: "Ink it Up!" })).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: "Try again!" })).toBeInTheDocument();
    });

    it("stops polling when the widget is unmounted", async () => {
      const { unmount } = await renderWidget();
      await clickButton("Suggest something!");
      await advance(1000);

      unmount();
      await advance(5000);

      expect(pollUrls()).toHaveLength(1);
    });
  });

  describe("timeout", () => {
    it("shows an error after 60 seconds of polling without a result", async () => {
      await renderWidget();
      await clickButton("Suggest something!");

      await advance(59 * 1000);
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();

      await advance(1000);
      expect(screen.getByRole("alert")).toHaveTextContent(TIMEOUT_MESSAGE);
      expect(pollUrls()).toHaveLength(60);

      await advance(10 * 1000);
      expect(pollUrls()).toHaveLength(60);
    });

    it("shows a result that arrives on the last poll", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [
        ...Array.from({ length: 59 }, () => response({})),
        response(pair(1, 2))
      ]);

      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(screen.getByRole("link", { name: "Ink it Up!" })).toBeInTheDocument();
    });

    it("lets the user try again after a timeout", async () => {
      await renderWidget();
      await clickButton("Suggest something!");
      await advance(60 * 1000);

      await askAndPoll("Try again!", [response(pair(1, 2))]);

      expect(screen.getByRole("link", { name: "Ink it Up!" })).toBeInTheDocument();
    });
  });

  describe("errors", () => {
    beforeEach(() => {
      jest.spyOn(console, "error").mockImplementation(() => {});
    });

    afterEach(() => {
      console.error.mockRestore();
    });

    it("renders an error result with its message and without Ink it Up!", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [
        response({ status: "error", message: "<p>The server gave up.</p>" })
      ]);

      expect(screen.getByRole("alert")).toHaveTextContent("The server gave up.");
      expect(screen.queryByRole("link", { name: "Ink it Up!" })).not.toBeInTheDocument();
      expect(screen.queryByText(/Results provided by an AI/)).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: "Try again!" })).toBeInTheDocument();
    });

    it("stops polling on an error result without a message", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [response({ status: "error" })]);
      await advance(5000);

      expect(screen.getByRole("alert")).toHaveTextContent(ERROR_MESSAGE);
      expect(pollUrls()).toHaveLength(1);
    });

    it("shows an error when the suggestion cannot be requested", async () => {
      enqueueResponse = response({}, 500);
      await renderWidget();

      await clickButton("Suggest something!");

      expect(screen.getByRole("alert")).toHaveTextContent(ERROR_MESSAGE);
      expect(pollUrls()).toHaveLength(0);
    });

    it("shows an error when a poll fails", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [response({}, 500)]);
      await advance(5000);

      expect(screen.getByRole("alert")).toHaveTextContent(ERROR_MESSAGE);
      expect(pollUrls()).toHaveLength(1);
    });

    it("asks the user to wait when requests are throttled", async () => {
      enqueueResponse = response({}, 429);
      await renderWidget();

      await clickButton("Suggest something!");

      expect(screen.getByRole("alert")).toHaveTextContent(THROTTLED_MESSAGE);
    });
  });

  describe("retry payload", () => {
    const enqueueParams = (index) => new URL(enqueueUrls()[index], "http://localhost").searchParams;

    it("sends the instruction and every suggested pair as rejected on retry", async () => {
      await renderWidget();
      fireEvent.change(screen.getByRole("textbox", { name: "Extra instructions" }), {
        target: { value: "Only samples & no reds" }
      });

      await askAndPoll("Suggest something!", [response(pair(1, 2))]);
      await askAndPoll("Try again!", [response(pair(3, 4))]);
      await askAndPoll("Try again!", [response(pair(5, 6))]);

      expect(enqueueParams(0).get("extra_user_input")).toEqual("Only samples & no reds");
      expect(enqueueParams(0).has("rejected_suggestions")).toBe(false);
      expect(JSON.parse(enqueueParams(2).get("rejected_suggestions"))).toEqual([
        { ink_id: 1, pen_id: 2 },
        { ink_id: 3, pen_id: 4 }
      ]);
      expect(enqueueParams(2).get("extra_user_input")).toEqual("Only samples & no reds");
    });

    it("does not send message-only or error results as rejected pairs", async () => {
      await renderWidget();

      await askAndPoll("Suggest something!", [response(pair(1, 2))]);
      await askAndPoll("Try again!", [response({ message: "Daily limit reached." })]);
      await askAndPoll("Try again!", [response({ status: "error", message: "Sorry" })]);
      await askAndPoll("Try again!", [response(pair(3, 4))]);

      expect(JSON.parse(enqueueParams(3).get("rejected_suggestions"))).toEqual([
        { ink_id: 1, pen_id: 2 }
      ]);
    });

    it("sends no instruction when the textarea is blank", async () => {
      await renderWidget();
      fireEvent.change(screen.getByRole("textbox", { name: "Extra instructions" }), {
        target: { value: "   " }
      });

      await clickButton("Suggest something!");

      expect(enqueueUrls()).toEqual([SUGGESTION_PATH]);
    });
  });
});
