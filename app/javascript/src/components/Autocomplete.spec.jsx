import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Autocomplete } from "./Autocomplete";

describe("Autocomplete", () => {
  let inputElement;

  beforeEach(() => {
    // Create a mock input element for each test
    inputElement = document.createElement("input");
    inputElement.id = "test-input";
    document.body.appendChild(inputElement);
  });

  afterEach(() => {
    // Clean up the input element after each test
    if (inputElement && inputElement.parentNode) {
      inputElement.parentNode.removeChild(inputElement);
    }
    // Clean up any containers added by the component
    const containers = document.querySelectorAll("[id$='-autocomplete-container']");
    containers.forEach((container) => container.remove());
  });

  describe("with a function source", () => {
    it("shows suggestions when typing", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple", "Apricot", "Avocado"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      // Type in the input
      fireEvent.input(inputElement, { target: { value: "A" } });

      // Wait for debounce and suggestions to appear
      await waitFor(() => {
        expect(mockSource).toHaveBeenCalledWith("A", {});
      });

      await waitFor(() => {
        expect(screen.getByText("Apple")).toBeInTheDocument();
        expect(screen.getByText("Apricot")).toBeInTheDocument();
        expect(screen.getByText("Avocado")).toBeInTheDocument();
      });
    });

    it("selects a suggestion when clicked", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple", "Apricot"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      // Type in the input
      fireEvent.input(inputElement, { target: { value: "Ap" } });

      await waitFor(() => {
        expect(screen.getByText("Apple")).toBeInTheDocument();
      });

      // Click on a suggestion
      fireEvent.click(screen.getByText("Apple"));

      // The input value should be updated
      expect(inputElement.value).toBe("Apple");
    });

    it("does not fetch again after selecting a suggestion", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple", "Apricot"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      // Type in the input
      fireEvent.input(inputElement, { target: { value: "Ap" } });

      await waitFor(() => {
        expect(mockSource).toHaveBeenCalledTimes(1);
        expect(screen.getByText("Apple")).toBeInTheDocument();
      });

      // Click on a suggestion
      fireEvent.click(screen.getByText("Apple"));

      // The input value should be updated
      expect(inputElement.value).toBe("Apple");

      // Wait a bit for any potential debounced calls
      await new Promise((resolve) => setTimeout(resolve, 300));

      // Source should NOT have been called again after selection
      expect(mockSource).toHaveBeenCalledTimes(1);

      // Dropdown should remain closed
      expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    });

    it("calls getDependencies when provided", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Result"]);
      const mockGetDependencies = jest.fn().mockReturnValue({ brandName: "TestBrand" });

      render(
        <Autocomplete
          inputSelector="#test-input"
          source={mockSource}
          getDependencies={mockGetDependencies}
        />
      );

      // Type in the input
      fireEvent.input(inputElement, { target: { value: "Test" } });

      await waitFor(() => {
        expect(mockSource).toHaveBeenCalledWith("Test", { brandName: "TestBrand" });
      });
    });

    it("hides suggestions when input is empty", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      // Type in the input
      fireEvent.input(inputElement, { target: { value: "A" } });

      await waitFor(() => {
        expect(screen.getByText("Apple")).toBeInTheDocument();
      });

      // Clear the input
      fireEvent.input(inputElement, { target: { value: "" } });

      await waitFor(() => {
        expect(screen.queryByText("Apple")).not.toBeInTheDocument();
      });
    });
  });

  describe("keyboard navigation", () => {
    it("navigates with arrow keys", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple", "Apricot"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      fireEvent.input(inputElement, { target: { value: "A" } });

      await waitFor(() => {
        expect(screen.getByText("Apple")).toBeInTheDocument();
      });

      // Press down arrow
      fireEvent.keyDown(inputElement, { key: "ArrowDown" });

      // First item should be highlighted
      const firstItem = screen.getByText("Apple");
      expect(firstItem).toHaveClass("fpc-autocomplete-item--highlighted");

      // Press down arrow again
      fireEvent.keyDown(inputElement, { key: "ArrowDown" });

      // Second item should be highlighted
      const secondItem = screen.getByText("Apricot");
      expect(secondItem).toHaveClass("fpc-autocomplete-item--highlighted");

      // Press up arrow
      fireEvent.keyDown(inputElement, { key: "ArrowUp" });

      // First item should be highlighted again
      expect(firstItem).toHaveClass("fpc-autocomplete-item--highlighted");
    });

    it("selects with Enter key", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple", "Apricot"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      fireEvent.input(inputElement, { target: { value: "A" } });

      await waitFor(() => {
        expect(screen.getByText("Apple")).toBeInTheDocument();
      });

      // Navigate to first item
      fireEvent.keyDown(inputElement, { key: "ArrowDown" });

      // Press Enter
      fireEvent.keyDown(inputElement, { key: "Enter" });

      // The input value should be updated
      expect(inputElement.value).toBe("Apple");

      // Suggestions should be hidden
      await waitFor(() => {
        expect(screen.queryByText("Apple")).not.toBeInTheDocument();
      });
    });

    it("closes suggestions with Escape key", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple"]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      fireEvent.input(inputElement, { target: { value: "A" } });

      await waitFor(() => {
        expect(screen.getByText("Apple")).toBeInTheDocument();
      });

      // Press Escape
      fireEvent.keyDown(inputElement, { key: "Escape" });

      // Suggestions should be hidden
      await waitFor(() => {
        expect(screen.queryByText("Apple")).not.toBeInTheDocument();
      });
    });
  });

  describe("inline completion", () => {
    const selectedText = () =>
      inputElement.value.slice(inputElement.selectionStart, inputElement.selectionEnd);

    // Blur and wait for the delayed dropdown close so it happens inside act()
    const blur = async () => {
      fireEvent.blur(inputElement);
      await act(() => new Promise((resolve) => setTimeout(resolve, 200)));
    };

    const renderAndType = async (text, suggestions = ["Pilot", "Pelikan"]) => {
      const user = userEvent.setup();
      const mockSource = jest.fn().mockResolvedValue(suggestions);
      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);
      await user.type(inputElement, text);
      await waitFor(() => expect(screen.getByRole("listbox")).toBeInTheDocument());
      return { user, mockSource };
    };

    it("shows the rest of the first matching suggestion as a selection", async () => {
      await renderAndType("pi");

      await waitFor(() => expect(inputElement.value).toBe("pilot"));
      expect(selectedText()).toBe("lot");
      expect(screen.getByText("Pilot")).toHaveClass("fpc-autocomplete-item--highlighted");
    });

    it("skips suggestions that don't start with the typed text", async () => {
      await renderAndType("pe", ["Diamine Pelikan Blue", "Pelikan"]);

      await waitFor(() => expect(inputElement.value).toBe("pelikan"));
      expect(selectedText()).toBe("likan");
      expect(screen.getByText("Pelikan")).toHaveClass("fpc-autocomplete-item--highlighted");
    });

    it("does not complete when no suggestion starts with the typed text", async () => {
      await renderAndType("lot", ["Pilot"]);

      expect(inputElement.value).toBe("lot");
      expect(selectedText()).toBe("");
    });

    it("does not complete when the input is not focused", async () => {
      const mockSource = jest.fn().mockResolvedValue(["Pilot"]);
      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      fireEvent.input(inputElement, { target: { value: "pi" } });

      await waitFor(() => expect(screen.getByText("Pilot")).toBeInTheDocument());
      expect(inputElement.value).toBe("pi");
    });

    it("fills in the suggestion when tabbing out of the field", async () => {
      const { user } = await renderAndType("pi");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.tab();

      expect(inputElement.value).toBe("Pilot");
      expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    });

    it("fills in the suggestion when the field loses focus", async () => {
      await renderAndType("pi");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await blur();

      expect(inputElement.value).toBe("Pilot");
    });

    it("dispatches change and input events when filling in the suggestion", async () => {
      const { mockSource } = await renderAndType("pi");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));
      const onChange = jest.fn();
      inputElement.addEventListener("change", onChange);

      await blur();

      expect(onChange).toHaveBeenCalled();
      await new Promise((resolve) => setTimeout(resolve, 300));
      expect(mockSource).toHaveBeenCalledTimes(1);
    });

    it("selects the completed suggestion with Enter", async () => {
      const { user } = await renderAndType("pi");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("{Enter}");

      expect(inputElement.value).toBe("Pilot");
      expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    });

    it("replaces the completion when typing another character", async () => {
      const mockSource = jest
        .fn()
        .mockResolvedValueOnce(["Pilot", "Pelikan"])
        .mockResolvedValue(["Pelikan"]);
      const user = userEvent.setup();
      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      await user.type(inputElement, "p");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("e");

      expect(inputElement.value.startsWith("pe")).toBe(true);
      await waitFor(() => expect(inputElement.value).toBe("pelikan"));
      expect(selectedText()).toBe("likan");
    });

    it("keeps the completion while typing along with it", async () => {
      const { user } = await renderAndType("p");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("i");

      expect(inputElement.value).toBe("pilot");
      expect(selectedText()).toBe("lot");
    });

    it("removes only the completion on Backspace, then deletes typed characters", async () => {
      const { user, mockSource } = await renderAndType("pil");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("{Backspace}");
      expect(inputElement.value).toBe("pil");

      // The completion must not come back once the new suggestions arrive
      await waitFor(() => expect(mockSource).toHaveBeenCalledTimes(2));
      await new Promise((resolve) => setTimeout(resolve, 50));
      expect(inputElement.value).toBe("pil");

      await user.keyboard("{Backspace}");
      expect(inputElement.value).toBe("pi");
    });

    it("removes only the completion on Delete", async () => {
      const { user } = await renderAndType("pil");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("{Delete}");

      expect(inputElement.value).toBe("pil");
    });

    it("does not fill in anything on blur after the completion was deleted", async () => {
      const { user } = await renderAndType("pil");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("{Backspace}");
      await blur();

      expect(inputElement.value).toBe("pil");
    });

    it("removes the completion on Escape", async () => {
      const { user } = await renderAndType("pi");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.keyboard("{Escape}");
      await blur();

      expect(inputElement.value).toBe("pi");
    });

    it("updates the completion when navigating with the arrow keys", async () => {
      const { user } = await renderAndType("p", ["Pilot", "Diamine", "Pelikan"]);
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      // Non-matching suggestion: only the typed text remains
      await user.keyboard("{ArrowDown}");
      expect(inputElement.value).toBe("p");

      await user.keyboard("{ArrowDown}");
      expect(inputElement.value).toBe("pelikan");
      expect(selectedText()).toBe("elikan");

      await user.tab();
      expect(inputElement.value).toBe("Pelikan");
    });

    it("lets the user click a different suggestion", async () => {
      const { user } = await renderAndType("p");
      await waitFor(() => expect(inputElement.value).toBe("pilot"));

      await user.click(screen.getByText("Pelikan"));

      expect(inputElement.value).toBe("Pelikan");
    });

    it("ignores responses for outdated requests", async () => {
      let resolveFirst;
      const mockSource = jest
        .fn()
        .mockImplementationOnce(() => new Promise((resolve) => (resolveFirst = resolve)))
        .mockResolvedValue(["Pelikan"]);
      const user = userEvent.setup();
      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      await user.type(inputElement, "p");
      await waitFor(() => expect(mockSource).toHaveBeenCalledTimes(1));
      await user.type(inputElement, "e");
      await waitFor(() => expect(inputElement.value).toBe("pelikan"));

      resolveFirst(["Pilot"]);
      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(screen.queryByText("Pilot")).not.toBeInTheDocument();
      expect(inputElement.value).toBe("pelikan");
    });
  });

  describe("with empty results", () => {
    it("does not show dropdown when no suggestions", async () => {
      const mockSource = jest.fn().mockResolvedValue([]);

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      fireEvent.input(inputElement, { target: { value: "xyz" } });

      await waitFor(() => {
        expect(mockSource).toHaveBeenCalled();
      });

      // No dropdown should be visible
      expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    });
  });

  describe("error handling", () => {
    it("handles fetch errors gracefully", async () => {
      const consoleSpy = jest.spyOn(console, "error").mockImplementation(() => {});
      const mockSource = jest.fn().mockRejectedValue(new Error("Network error"));

      render(<Autocomplete inputSelector="#test-input" source={mockSource} />);

      fireEvent.input(inputElement, { target: { value: "test" } });

      await waitFor(() => {
        expect(mockSource).toHaveBeenCalled();
      });

      // Should not crash and no dropdown should be visible
      expect(screen.queryByRole("listbox")).not.toBeInTheDocument();

      consoleSpy.mockRestore();
    });
  });

  describe("when input element does not exist", () => {
    it("renders nothing and does not crash", () => {
      const mockSource = jest.fn().mockResolvedValue(["Apple"]);

      // Remove the input element
      inputElement.parentNode.removeChild(inputElement);

      // Should not throw
      expect(() => {
        render(<Autocomplete inputSelector="#non-existent-input" source={mockSource} />);
      }).not.toThrow();

      // No dropdown should be visible
      expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    });
  });
});
