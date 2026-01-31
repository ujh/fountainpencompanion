import React, { useState, useEffect, useRef, useCallback } from "react";
import PropTypes from "prop-types";
import "./autocomplete.scss";

/**
 * Autocomplete component that enhances an existing input element with autocomplete functionality.
 * This component renders a dropdown of suggestions below the target input.
 *
 * @param {string} inputSelector - CSS selector for the input element to enhance
 * @param {string|function} source - URL string or async function that returns suggestions
 * @param {function} [getDependencies] - Optional function that returns additional parameters for the source
 */
export const Autocomplete = ({ inputSelector, source, getDependencies }) => {
  const [suggestions, setSuggestions] = useState([]);
  const [isOpen, setIsOpen] = useState(false);
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const [position, setPosition] = useState({ top: 0, left: 0, width: 0 });
  const dropdownRef = useRef(null);
  const inputRef = useRef(null);
  const debounceRef = useRef(null);
  const justSelectedRef = useRef(false);

  // Find and store reference to the target input
  useEffect(() => {
    const input = document.querySelector(inputSelector);
    if (input) {
      inputRef.current = input;
    }
  }, [inputSelector]);

  // Update dropdown position based on input position
  const updatePosition = useCallback(() => {
    if (inputRef.current) {
      const rect = inputRef.current.getBoundingClientRect();
      setPosition({
        top: rect.bottom + window.scrollY,
        left: rect.left + window.scrollX,
        width: rect.width
      });
    }
  }, []);

  // Fetch suggestions from source
  const fetchSuggestions = useCallback(
    async (term) => {
      if (!term || term.length < 1) {
        setSuggestions([]);
        setIsOpen(false);
        return;
      }

      try {
        let results;

        if (typeof source === "function") {
          results = await source(term, getDependencies ? getDependencies() : {});
        } else if (typeof source === "string") {
          const params = new URLSearchParams({ term });
          if (getDependencies) {
            const deps = getDependencies();
            Object.keys(deps).forEach((key) => {
              if (deps[key]) {
                params.append(key, deps[key]);
              }
            });
          }
          const response = await fetch(`${source}?${params.toString()}`);
          results = await response.json();
        }

        if (Array.isArray(results)) {
          setSuggestions(results);
          setIsOpen(results.length > 0);
          setHighlightedIndex(-1);
        }
      } catch (error) {
        console.error("Autocomplete fetch error:", error);
        setSuggestions([]);
        setIsOpen(false);
      }
    },
    [source, getDependencies]
  );

  // Debounced input handler
  const handleInputChange = useCallback(
    (value) => {
      // Skip fetching if we just selected a suggestion
      if (justSelectedRef.current) {
        justSelectedRef.current = false;
        return;
      }

      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
      debounceRef.current = setTimeout(() => {
        fetchSuggestions(value);
      }, 200);
    },
    [fetchSuggestions]
  );

  // Select a suggestion
  const selectSuggestion = useCallback((suggestion) => {
    // Set flag to prevent fetching when the input event fires
    justSelectedRef.current = true;

    if (inputRef.current) {
      inputRef.current.value = suggestion;
      inputRef.current.dispatchEvent(new Event("change", { bubbles: true }));
      inputRef.current.dispatchEvent(new Event("input", { bubbles: true }));
    }
    setSuggestions([]);
    setIsOpen(false);
    setHighlightedIndex(-1);
  }, []);

  // Handle keyboard navigation
  const handleKeyDown = useCallback(
    (e) => {
      if (!isOpen) return;

      switch (e.key) {
        case "ArrowDown":
          e.preventDefault();
          setHighlightedIndex((prev) => (prev < suggestions.length - 1 ? prev + 1 : prev));
          break;
        case "ArrowUp":
          e.preventDefault();
          setHighlightedIndex((prev) => (prev > 0 ? prev - 1 : -1));
          break;
        case "Enter":
          e.preventDefault();
          if (highlightedIndex >= 0 && highlightedIndex < suggestions.length) {
            selectSuggestion(suggestions[highlightedIndex]);
          }
          break;
        case "Escape":
          setIsOpen(false);
          setHighlightedIndex(-1);
          break;
        case "Tab":
          setIsOpen(false);
          setHighlightedIndex(-1);
          break;
      }
    },
    [isOpen, highlightedIndex, suggestions, selectSuggestion]
  );

  // Attach event listeners to the input
  useEffect(() => {
    const input = inputRef.current;
    if (!input) return;

    const onInput = (e) => {
      handleInputChange(e.target.value);
      updatePosition();
    };

    const onFocus = () => {
      updatePosition();
      if (input.value && suggestions.length > 0) {
        setIsOpen(true);
      }
    };

    const onBlur = () => {
      // Delay closing to allow click on dropdown
      setTimeout(() => {
        setIsOpen(false);
      }, 150);
    };

    const onKeyDown = (e) => {
      handleKeyDown(e);
    };

    input.addEventListener("input", onInput);
    input.addEventListener("focus", onFocus);
    input.addEventListener("blur", onBlur);
    input.addEventListener("keydown", onKeyDown);

    return () => {
      input.removeEventListener("input", onInput);
      input.removeEventListener("focus", onFocus);
      input.removeEventListener("blur", onBlur);
      input.removeEventListener("keydown", onKeyDown);
    };
  }, [handleInputChange, handleKeyDown, updatePosition, suggestions.length]);

  // Update position on window resize/scroll
  useEffect(() => {
    const handleResize = () => updatePosition();
    window.addEventListener("resize", handleResize);
    window.addEventListener("scroll", handleResize, true);
    return () => {
      window.removeEventListener("resize", handleResize);
      window.removeEventListener("scroll", handleResize, true);
    };
  }, [updatePosition]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target) &&
        inputRef.current &&
        !inputRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  if (!isOpen || suggestions.length === 0) {
    return null;
  }

  return (
    <ul
      ref={dropdownRef}
      className="fpc-autocomplete-dropdown"
      style={{
        position: "absolute",
        top: `${position.top}px`,
        left: `${position.left}px`,
        width: `${position.width}px`
      }}
      role="listbox"
    >
      {suggestions.map((suggestion, index) => (
        <li
          key={suggestion}
          className={`fpc-autocomplete-item ${index === highlightedIndex ? "fpc-autocomplete-item--highlighted" : ""}`}
          onClick={() => selectSuggestion(suggestion)}
          onMouseEnter={() => setHighlightedIndex(index)}
          role="option"
          aria-selected={index === highlightedIndex}
        >
          {suggestion}
        </li>
      ))}
    </ul>
  );
};

Autocomplete.propTypes = {
  inputSelector: PropTypes.string.isRequired,
  source: PropTypes.oneOfType([PropTypes.string, PropTypes.func]).isRequired,
  getDependencies: PropTypes.func
};

export default Autocomplete;
