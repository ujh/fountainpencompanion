import { act, screen } from "@testing-library/react";
import "report-button";

describe("report-button mount", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  it("mounts a button for each element with its data attributes", async () => {
    document.body.innerHTML = `
      <div class="fpc-report-button" data-url="/ink_reviews/1/report" data-heading="Report a problem with this review" data-label="Report this review" data-icon="true"></div>
      <div class="fpc-report-button" data-url="/inks/2/report" data-heading="Report an error with Oxblood" data-label="Report an error"></div>
    `;

    await act(async () => {
      document.dispatchEvent(new Event("DOMContentLoaded"));
    });

    const iconButton = screen.getByRole("button", { name: "Report this review" });
    expect(iconButton.querySelector(".fa-exclamation-circle")).not.toBeNull();
    expect(screen.getByRole("button", { name: "Report an error" })).toHaveTextContent(
      "Report an error"
    );
    const dialogHeadings = [...document.querySelectorAll("dialog")].map(
      (dialog) => document.getElementById(dialog.getAttribute("aria-labelledby")).textContent
    );
    expect(dialogHeadings).toEqual([
      "Report a problem with this review",
      "Report an error with Oxblood"
    ]);
  });

  it("gives each button's dialog unique ids", async () => {
    document.body.innerHTML = `
      <div class="fpc-report-button" data-url="/ink_reviews/1/report" data-heading="A" data-label="Report this review" data-icon="true"></div>
      <div class="fpc-report-button" data-url="/ink_reviews/2/report" data-heading="B" data-label="Report this review" data-icon="true"></div>
    `;

    await act(async () => {
      document.dispatchEvent(new Event("DOMContentLoaded"));
    });

    const ids = [...document.querySelectorAll("[id]")].map((el) => el.id);
    expect(ids).toHaveLength(4);
    expect(new Set(ids).size).toBe(ids.length);
  });
});
