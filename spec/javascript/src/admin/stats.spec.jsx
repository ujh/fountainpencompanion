import { act, render, screen } from "@testing-library/react";
import { ConditionalStat, Stat } from "admin/stats";
import * as fetchModule from "fetch";

const deferredResponse = () => {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = (json) => res({ json: async () => json });
    reject = rej;
  });
  return { promise, resolve, reject };
};

const spinner = (container) => container.querySelector(".fa-spin");

describe("admin stats", () => {
  let requests;
  let lastLock;

  beforeAll(() => {
    global.navigator.locks = { request: (_name, cb) => (lastLock = cb()) };
  });

  afterAll(() => {
    delete global.navigator.locks;
  });

  beforeEach(() => {
    jest.useFakeTimers();
    requests = [];
    jest.spyOn(fetchModule, "getRequest").mockImplementation((url) => {
      const request = deferredResponse();
      requests.push({ url, ...request });
      return request.promise;
    });
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.restoreAllMocks();
  });

  const respond = async (index, json) => {
    await act(async () => requests[index].resolve(json));
  };

  const poll = async () => {
    await act(async () => jest.advanceTimersByTime(1000 * 30));
  };

  describe("Stat", () => {
    it("requests the stat with the arg", () => {
      render(<Stat id="users" arg="7" />);
      expect(requests[0].url).toEqual("/admins/stats/users?arg=7");
    });

    it("shows only a spinner on the first load", () => {
      const { container } = render(<Stat id="users" />);
      expect(spinner(container)).not.toBeNull();
      expect(container.textContent.trim()).toEqual("");
    });

    it("shows the value once loaded", async () => {
      const { container } = render(<Stat id="users" />);
      await respond(0, 42);
      expect(screen.getByText(/42/)).toBeInTheDocument();
      expect(spinner(container)).toBeNull();
    });

    it("keeps the old value and shows a spinner while reloading", async () => {
      const { container } = render(<Stat id="users" />);
      await respond(0, 42);

      await poll();
      expect(screen.getByText(/42/)).toBeInTheDocument();
      expect(spinner(container)).not.toBeNull();

      await respond(1, 43);
      expect(screen.queryByText(/42/)).toBeNull();
      expect(screen.getByText(/43/)).toBeInTheDocument();
      expect(spinner(container)).toBeNull();
    });

    it("keeps the old value and hides the spinner when a reload fails", async () => {
      const { container } = render(<Stat id="users" />);
      await respond(0, 42);

      await poll();
      await act(async () => {
        requests[1].reject(new Error("network"));
        await expect(lastLock).rejects.toThrow("network");
      });
      expect(screen.getByText(/42/)).toBeInTheDocument();
      expect(spinner(container)).toBeNull();
    });

    it("shows a zero value", async () => {
      render(<Stat id="users" />);
      await respond(0, 0);
      expect(screen.getByText(/0/)).toBeInTheDocument();
    });
  });

  describe("ConditionalStat", () => {
    const props = { id: "spam", href: "/admins/spam", template: "%count% to review" };

    it("shows only a spinner on the first load", () => {
      const { container } = render(<ConditionalStat {...props} />);
      expect(spinner(container)).not.toBeNull();
      expect(screen.queryByRole("link")).toBeNull();
    });

    it("renders the link once loaded", async () => {
      const { container } = render(<ConditionalStat {...props} />);
      await respond(0, 5);
      expect(screen.getByRole("link", { name: "5 to review" })).toHaveAttribute(
        "href",
        "/admins/spam"
      );
      expect(spinner(container)).toBeNull();
    });

    it("renders nothing when there is nothing to show", async () => {
      const { container } = render(<ConditionalStat {...props} />);
      await respond(0, 0);
      expect(container).toBeEmptyDOMElement();
    });

    it("keeps the old link and shows a spinner while reloading", async () => {
      const { container } = render(<ConditionalStat {...props} />);
      await respond(0, 5);

      await poll();
      expect(screen.getByRole("link", { name: "5 to review" })).toBeInTheDocument();
      expect(spinner(container)).not.toBeNull();

      await respond(1, 6);
      expect(screen.getByRole("link", { name: "6 to review" })).toBeInTheDocument();
      expect(spinner(container)).toBeNull();
    });

    it("shows only a spinner while reloading when there was nothing to show", async () => {
      const { container } = render(<ConditionalStat {...props} />);
      await respond(0, 0);

      await poll();
      expect(spinner(container)).not.toBeNull();
      expect(screen.queryByRole("link")).toBeNull();
    });
  });
});
