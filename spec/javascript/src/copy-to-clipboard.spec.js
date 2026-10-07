import { setupCopyButtons } from "copy-to-clipboard";

describe("setupCopyButtons", () => {
  beforeAll(() => setupCopyButtons());

  beforeEach(() => {
    document.body.innerHTML = `
      <input id="token" value="secret-token">
      <button type="button" data-copy-target="token">Copy</button>
      <code id="example">curl https://example.com</code>
      <button type="button" data-copy-target="example">Copy</button>
      <button type="button" data-copy-target="missing">Copy</button>
    `;
    Object.assign(navigator, { clipboard: { writeText: jest.fn() } });
  });

  const button = (target) => document.querySelector(`[data-copy-target="${target}"]`);

  it("copies the value of an input", () => {
    button("token").click();

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith("secret-token");
    expect(button("token").textContent).toBe("Copied!");
  });

  it("copies the text of other elements", () => {
    button("example").click();

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith("curl https://example.com");
  });

  it("does nothing when the target does not exist", () => {
    button("missing").click();

    expect(navigator.clipboard.writeText).not.toHaveBeenCalled();
    expect(button("missing").textContent).toBe("Copy");
  });
});
