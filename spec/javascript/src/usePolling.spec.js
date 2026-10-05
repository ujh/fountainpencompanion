import { renderHook } from "@testing-library/react";
import { usePolling } from "usePolling";

const setHidden = (hidden) => {
  Object.defineProperty(document, "hidden", { configurable: true, get: () => hidden });
  document.dispatchEvent(new Event("visibilitychange"));
};

describe("usePolling", () => {
  beforeEach(() => {
    jest.useFakeTimers();
    Object.defineProperty(document, "hidden", { configurable: true, get: () => false });
  });

  afterEach(() => {
    jest.useRealTimers();
    delete document.hidden;
  });

  it("calls the callback immediately and on every interval", () => {
    const callback = jest.fn();
    renderHook(() => usePolling(callback, 1000));
    expect(callback).toHaveBeenCalledTimes(1);

    jest.advanceTimersByTime(3000);
    expect(callback).toHaveBeenCalledTimes(4);
  });

  it("does not call the callback while the page is hidden", () => {
    const callback = jest.fn();
    renderHook(() => usePolling(callback, 1000));
    setHidden(true);

    jest.advanceTimersByTime(3000);
    expect(callback).toHaveBeenCalledTimes(1);
  });

  it("calls the callback when the page becomes visible again after missing a poll", () => {
    const callback = jest.fn();
    renderHook(() => usePolling(callback, 1000));
    setHidden(true);
    jest.advanceTimersByTime(3500);

    setHidden(false);
    expect(callback).toHaveBeenCalledTimes(2);
  });

  it("restarts the interval after calling the callback on becoming visible", () => {
    const callback = jest.fn();
    renderHook(() => usePolling(callback, 1000));
    setHidden(true);
    jest.advanceTimersByTime(3500);
    setHidden(false);

    jest.advanceTimersByTime(999);
    expect(callback).toHaveBeenCalledTimes(2);

    jest.advanceTimersByTime(1);
    expect(callback).toHaveBeenCalledTimes(3);
  });

  it("does not call the callback when the page becomes visible again before the next poll", () => {
    const callback = jest.fn();
    renderHook(() => usePolling(callback, 1000));
    jest.advanceTimersByTime(1000);
    setHidden(true);
    jest.advanceTimersByTime(500);

    setHidden(false);
    expect(callback).toHaveBeenCalledTimes(2);

    jest.advanceTimersByTime(500);
    expect(callback).toHaveBeenCalledTimes(3);
  });

  it("uses the latest callback", () => {
    const first = jest.fn();
    const second = jest.fn();
    const { rerender } = renderHook(({ callback }) => usePolling(callback, 1000), {
      initialProps: { callback: first }
    });
    rerender({ callback: second });

    jest.advanceTimersByTime(1000);
    expect(first).toHaveBeenCalledTimes(1);
    expect(second).toHaveBeenCalledTimes(1);
  });

  it("stops polling when unmounted", () => {
    const callback = jest.fn();
    const { unmount } = renderHook(() => usePolling(callback, 1000));
    unmount();

    jest.advanceTimersByTime(3000);
    setHidden(false);
    expect(callback).toHaveBeenCalledTimes(1);
  });
});
