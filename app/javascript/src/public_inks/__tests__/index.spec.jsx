import { act, screen, waitFor } from "@testing-library/react";
import { getRequest } from "../../fetch";
import "../index";

vi.mock("../../fetch", () => ({
  getRequest: vi.fn(() =>
    Promise.resolve({
      ok: true,
      json: () =>
        Promise.resolve({
          data: { id: "1", attributes: { name: "Test User" } },
          included: [
            {
              type: "collected_inks",
              attributes: { ink_id: 101, brand_name: "BrandA", ink_name: "InkA", kind: "bottle" }
            }
          ]
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
    expect(await screen.findByText("InkA")).toBeInTheDocument();
    expect(getRequest).not.toHaveBeenCalledWith("/account?include=collected_inks");
  });
});
