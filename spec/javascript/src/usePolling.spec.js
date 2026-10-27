import { renderHook } from "@testing-library/react";
import { usePolling } from "usePolling";

const setHidden = (hidden) => {
  Object.defineProperty(document, "hidden", { configurable: true, get: () => hidden });
  document.dispatchEvent(new Event("visibilitychange"));
};

describe("usePolling", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    Object.defineProperty(document, "hidden", { configurable: true, get: () => false });
  });

  afterEach(() => {
    vi.useRealTimers();
    delete document.hidden;
  });

  it("calls the callback immediately and on every interval", () => {
    const callback = vi.fn();
    renderHook(() => usePolling(callback, 1000));
    expect(callback).toHaveBeenCalledTimes(1);

    vi.advanceTimersByTime(3000);
    expect(callback).toHaveBeenCalledTimes(4);
  });

  it("does not call the callback while the page is hidden", () => {
    const callback = vi.fn();
    renderHook(() => usePolling(callback, 1000));
    setHidden(true);

    vi.advanceTimersByTime(3000);
    expect(callback).toHaveBeenCalledTimes(1);
  });

  it("calls the callback when the page becomes visible again after missing a poll", () => {
    const callback = vi.fn();
    renderHook(() => usePolling(callback, 1000));
    setHidden(true);
    vi.advanceTimersByTime(3500);

    setHidden(false);
    expect(callback).toHaveBeenCalledTimes(2);
  });

  it("restarts the interval after calling the callback on becoming visible", () => {
    const callback = vi.fn();
    renderHook(() => usePolling(callback, 1000));
    setHidden(true);
    vi.advanceTimersByTime(3500);
    setHidden(false);

    vi.advanceTimersByTime(999);
    expect(callback).toHaveBeenCalledTimes(2);

    vi.advanceTimersByTime(1);
    expect(callback).toHaveBeenCalledTimes(3);
  });

  it("does not call the callback when the page becomes visible again before the next poll", () => {
    const callback = vi.fn();
    renderHook(() => usePolling(callback, 1000));
    vi.advanceTimersByTime(1000);
    setHidden(true);
    vi.advanceTimersByTime(500);

    setHidden(false);
    expect(callback).toHaveBeenCalledTimes(2);

    vi.advanceTimersByTime(500);
    expect(callback).toHaveBeenCalledTimes(3);
  });

  it("uses the latest callback", () => {
    const first = vi.fn();
    const second = vi.fn();
    const { rerender } = renderHook(({ callback }) => usePolling(callback, 1000), {
      initialProps: { callback: first }
    });
    rerender({ callback: second });

    vi.advanceTimersByTime(1000);
    expect(first).toHaveBeenCalledTimes(1);
    expect(second).toHaveBeenCalledTimes(1);
  });

  it("stops polling when unmounted", () => {
    const callback = vi.fn();
    const { unmount } = renderHook(() => usePolling(callback, 1000));
    unmount();

    vi.advanceTimersByTime(3000);
    setHidden(false);
    expect(callback).toHaveBeenCalledTimes(1);
  });
});
