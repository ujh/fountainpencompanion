import { act, screen } from "@testing-library/react";
import "love-button";

describe("love-button mount", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  it("mounts a button with the state rendered by the server", async () => {
    document.body.innerHTML = `
      <div class="fpc-love-button" data-url="/ink_reviews/1/love" data-loved="true" data-count="2"></div>
      <div class="fpc-love-button" data-url="/ink_reviews/2/love" data-loved="false" data-count="0"></div>
    `;

    await act(async () => {
      document.dispatchEvent(new Event("DOMContentLoaded"));
    });

    const [loved, notLoved] = screen.getAllByRole("button");
    expect(loved).toHaveAttribute("aria-pressed", "true");
    expect(loved.parentElement).toHaveTextContent("2 loves");
    expect(notLoved).toHaveAttribute("aria-pressed", "false");
    expect(notLoved.parentElement).toHaveTextContent("0 loves");
  });
});
