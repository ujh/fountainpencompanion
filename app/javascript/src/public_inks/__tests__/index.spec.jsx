import { act, waitFor } from "@testing-library/react";
import { getRequest } from "../../fetch";
import "../index";

vi.mock("../../fetch", () => ({
  getRequest: vi.fn(() =>
    Promise.resolve({
      ok: true,
      json: () =>
        Promise.resolve({
          data: { id: "1", attributes: { name: "Test User" } },
          included: []
        })
    })
  )
}));

describe("public inks mount", () => {
  let el;

  beforeEach(() => {
    getRequest.mockClear();
    el = document.createElement("div");
    el.id = "new-public-inks";
    document.body.appendChild(el);
  });

  afterEach(() => {
    el.remove();
  });

  const mount = () =>
    act(() => {
      document.dispatchEvent(new Event("DOMContentLoaded"));
    });

  it("requests the viewer's account when the page marks them as logged in", async () => {
    el.setAttribute("data-logged-in", "");
    await mount();
    await waitFor(() => expect(getRequest).toHaveBeenCalledWith("/account?include=collected_inks"));
  });

  it("does not request the viewer's account when the page has no logged-in flag", async () => {
    await mount();
    await waitFor(() => expect(getRequest).toHaveBeenCalledWith(location.href));
    await act(() => Promise.resolve());
    expect(getRequest).not.toHaveBeenCalledWith("/account?include=collected_inks");
  });
});
