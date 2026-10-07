import { setupCopyButtons } from "copy-to-clipboard";

describe("setupCopyButtons", () => {
  let root;

  beforeEach(() => {
    root = document.createElement("div");
    root.innerHTML = `
      <input id="token" value="secret-token">
      <button type="button" data-copy-target="token">Copy</button>
      <code id="example">curl https://example.com</code>
      <button type="button" data-copy-target="example">Copy</button>
      <button type="button" data-copy-target="missing">Copy</button>
    `;
    document.body.appendChild(root);
    Object.assign(navigator, { clipboard: { writeText: jest.fn() } });
    setupCopyButtons(root);
  });

  afterEach(() => root.remove());

  const button = (target) => root.querySelector(`[data-copy-target="${target}"]`);

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
