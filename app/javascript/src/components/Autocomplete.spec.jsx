import React from "react";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
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
