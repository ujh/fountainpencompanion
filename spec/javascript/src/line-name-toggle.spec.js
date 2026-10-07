import { setupLineNameToggle } from "line-name-toggle";

describe("setupLineNameToggle", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <input id="manual_line_name_input" value="Iroshizuku">
      <input type="checkbox" id="macro_cluster_line_name_is_empty">
    `;
    setupLineNameToggle();
  });

  const checkbox = () => document.getElementById("macro_cluster_line_name_is_empty");
  const input = () => document.getElementById("manual_line_name_input");

  it("disables and clears the line name when it is marked as empty", () => {
    checkbox().click();

    expect(input().disabled).toBe(true);
    expect(input().value).toBe("");
  });

  it("enables the line name again when unchecked", () => {
    checkbox().click();
    checkbox().click();

    expect(input().disabled).toBe(false);
  });

  it("does nothing on pages without the fields", () => {
    document.body.innerHTML = "";

    expect(() => setupLineNameToggle()).not.toThrow();
  });
});
