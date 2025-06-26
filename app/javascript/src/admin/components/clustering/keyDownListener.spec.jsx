import { keyDownListener, setInBrandSelector } from "./keyDownListener";

describe("keyDownListener", () => {
  let mockCallback;

  let removeListener;
  let addEventListenerSpy;
  let removeEventListenerSpy;

  beforeEach(() => {
    mockCallback = jest.fn();

    // Reset the inBrandSelector state
    setInBrandSelector(false);

    // Mock document event listener methods
    addEventListenerSpy = jest.spyOn(document, "addEventListener");
    removeEventListenerSpy = jest.spyOn(document, "removeEventListener");

    // Clear any existing event listeners
    if (removeListener) {
      removeListener();
      removeListener = null;
    }
  });

  afterEach(() => {
    // Clean up any remaining listeners
    if (removeListener) {
      removeListener();
      removeListener = null;
    }

    // Restore mocks
    addEventListenerSpy.mockRestore();
    removeEventListenerSpy.mockRestore();
    jest.clearAllMocks();
  });

  describe("Basic functionality", () => {
    it("adds a keydown event listener to document", () => {
      removeListener = keyDownListener(mockCallback);

      expect(addEventListenerSpy).toHaveBeenCalledWith("keydown", expect.any(Function));
    });

    it("returns a cleanup function", () => {
      removeListener = keyDownListener(mockCallback);

      expect(typeof removeListener).toBe("function");
    });

    it("removes event listener when cleanup function is called", () => {
      removeListener = keyDownListener(mockCallback);
      const listener = addEventListenerSpy.mock.calls[0][1];

      removeListener();

      expect(removeEventListenerSpy).toHaveBeenCalledWith("keydown", listener);
    });
  });

  describe("Event handling", () => {
    it("calls callback function when key is pressed", () => {
      removeListener = keyDownListener(mockCallback);

      // Simulate keydown event
      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalledWith(event);
    });

    it("passes the event object to callback", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 66,
        bubbles: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalledWith(event);
      expect(mockCallback.mock.calls[0][0]).toHaveProperty("keyCode");
    });

    it("handles multiple different key codes", () => {
      removeListener = keyDownListener(mockCallback);

      const event1 = new KeyboardEvent("keydown", { keyCode: 65 }); // A
      const event2 = new KeyboardEvent("keydown", { keyCode: 66 }); // B
      const event3 = new KeyboardEvent("keydown", { keyCode: 67 }); // C

      document.dispatchEvent(event1);
      document.dispatchEvent(event2);
      document.dispatchEvent(event3);

      expect(mockCallback).toHaveBeenCalledTimes(3);
    });
  });

  describe("Filtering - inBrandSelector", () => {
    it("does not call callback when inBrandSelector is true", () => {
      setInBrandSelector(true);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("calls callback when inBrandSelector is false", () => {
      setInBrandSelector(false);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalledWith(event);
    });

    it("responds to changes in inBrandSelector state", () => {
      removeListener = keyDownListener(mockCallback);

      // Initially false, should call callback
      setInBrandSelector(false);
      const event1 = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event1);
      expect(mockCallback).toHaveBeenCalledTimes(1);

      // Set to true, should not call callback
      setInBrandSelector(true);
      const event2 = new KeyboardEvent("keydown", { keyCode: 66 });
      document.dispatchEvent(event2);
      expect(mockCallback).toHaveBeenCalledTimes(1);

      // Set back to false, should call callback again
      setInBrandSelector(false);
      const event3 = new KeyboardEvent("keydown", { keyCode: 67 });
      document.dispatchEvent(event3);
      expect(mockCallback).toHaveBeenCalledTimes(2);
    });
  });

  describe("Filtering - modifier keys", () => {
    it("does not call callback when ctrlKey is pressed", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        ctrlKey: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("does not call callback when shiftKey is pressed", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        shiftKey: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("does not call callback when altKey is pressed", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        altKey: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("does not call callback when metaKey is pressed", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        metaKey: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("does not call callback when multiple modifier keys are pressed", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        ctrlKey: true,
        shiftKey: true,
        altKey: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("calls callback when no modifier keys are pressed", () => {
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        ctrlKey: false,
        shiftKey: false,
        altKey: false,
        metaKey: false
      });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalledWith(event);
    });
  });

  describe("Combined filtering", () => {
    it("does not call callback when both inBrandSelector is true and modifier key is pressed", () => {
      setInBrandSelector(true);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        ctrlKey: true
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("does not call callback when inBrandSelector is true even if no modifier keys", () => {
      setInBrandSelector(true);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", {
        keyCode: 65,
        ctrlKey: false,
        shiftKey: false,
        altKey: false,
        metaKey: false
      });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });
  });

  describe("setInBrandSelector function", () => {
    it("sets inBrandSelector to true", () => {
      setInBrandSelector(true);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("sets inBrandSelector to false", () => {
      setInBrandSelector(false);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalled();
    });

    it("accepts truthy values", () => {
      setInBrandSelector("true");
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it("accepts falsy values", () => {
      setInBrandSelector(null);
      removeListener = keyDownListener(mockCallback);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalled();
    });
  });

  describe("Multiple listeners", () => {
    it("supports multiple simultaneous listeners", () => {
      const mockCallback2 = jest.fn();

      const removeListener1 = keyDownListener(mockCallback);
      const removeListener2 = keyDownListener(mockCallback2);

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).toHaveBeenCalledWith(event);
      expect(mockCallback2).toHaveBeenCalledWith(event);

      // Clean up both listeners
      removeListener1();
      removeListener2();
    });

    it("removes only the specific listener when cleanup is called", () => {
      const mockCallback2 = jest.fn();

      const removeListener1 = keyDownListener(mockCallback);
      const removeListener2 = keyDownListener(mockCallback2);

      // Remove first listener
      removeListener1();

      const event = new KeyboardEvent("keydown", { keyCode: 65 });
      document.dispatchEvent(event);

      expect(mockCallback).not.toHaveBeenCalled();
      expect(mockCallback2).toHaveBeenCalledWith(event);

      // Clean up remaining listener
      removeListener2();
    });
  });
});
