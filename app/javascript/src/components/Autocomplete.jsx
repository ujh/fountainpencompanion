import PropTypes from "prop-types";
import { useCallback, useEffect, useRef, useState } from "react";
import "./autocomplete.scss";

/**
 * Autocomplete component that enhances an existing input element with autocomplete functionality.
 * This component renders a dropdown of suggestions below the target input.
 *
 * When the first suggestion that starts with the typed text arrives, the rest of it is filled
 * into the input as a selection (inline completion). Moving out of the field (e.g. with Tab)
 * accepts it, typing replaces it, and Backspace/Delete removes only the completion.
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
  // What the user actually typed, without any inline completion
  const typedValueRef = useRef("");
  // The suggestion currently shown as inline completion, if any
  const completionRef = useRef(null);
  // Set after the user deletes text so that the completion doesn't immediately reappear
  const suppressCompletionRef = useRef(false);
  const composingRef = useRef(false);
  const requestIdRef = useRef(0);

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

  // Show the remainder of the suggestion after the typed text as a selection
  const showCompletion = useCallback((suggestion) => {
    const input = inputRef.current;
    const typed = typedValueRef.current;
    input.value = typed + suggestion.slice(typed.length);
    input.setSelectionRange(typed.length, input.value.length);
    completionRef.current = suggestion;
  }, []);

  // Remove the inline completion, leaving only what the user typed
  const clearCompletion = useCallback(() => {
    if (!completionRef.current) return;

    completionRef.current = null;
    const input = inputRef.current;
    const typed = typedValueRef.current;
    input.value = typed;
    input.setSelectionRange(typed.length, typed.length);
  }, []);

  // Fill in the inline completion with the suggestion's original casing
  const acceptCompletion = useCallback(() => {
    const suggestion = completionRef.current;
    if (!suggestion) return;

    completionRef.current = null;
    const input = inputRef.current;
    // The user may have edited the text without triggering an input event (e.g. via the caret)
    if (input.value.toLowerCase() !== suggestion.toLowerCase()) return;

    typedValueRef.current = suggestion;
    justSelectedRef.current = true;
    input.value = suggestion;
    input.dispatchEvent(new Event("change", { bubbles: true }));
    input.dispatchEvent(new Event("input", { bubbles: true }));
  }, []);

  // Whether a completion may be inserted into the input right now
  const canComplete = useCallback(() => {
    const input = inputRef.current;
    if (!input || document.activeElement !== input) return false;
    if (suppressCompletionRef.current || composingRef.current) return false;
    if (completionRef.current) return true;

    // Only complete when the caret is at the end of the text
    const length = input.value.length;
    return input.selectionStart === length && input.selectionEnd === length;
  }, []);

  // Fetch suggestions from source
  const fetchSuggestions = useCallback(
    async (term) => {
      const requestId = ++requestIdRef.current;

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

        // Ignore responses that arrive after a newer request was started
        if (requestId !== requestIdRef.current) return;

        if (Array.isArray(results)) {
          setSuggestions(results);
          setIsOpen(results.length > 0);

          const index = canComplete()
            ? results.findIndex((s) => isCompletionFor(s, typedValueRef.current))
            : -1;
          if (index >= 0) {
            showCompletion(results[index]);
          } else {
            clearCompletion();
          }
          setHighlightedIndex(index);
        }
      } catch (error) {
        console.error("Autocomplete fetch error:", error);
        setSuggestions([]);
        setIsOpen(false);
      }
    },
    [source, getDependencies, canComplete, showCompletion, clearCompletion]
  );

  // Debounced input handler
  const handleInputChange = useCallback(
    (value) => {
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
    completionRef.current = null;
    typedValueRef.current = suggestion;

    if (inputRef.current) {
      inputRef.current.value = suggestion;
      inputRef.current.dispatchEvent(new Event("change", { bubbles: true }));
      inputRef.current.dispatchEvent(new Event("input", { bubbles: true }));
    }
    setSuggestions([]);
    setIsOpen(false);
    setHighlightedIndex(-1);
  }, []);

  // Highlight a suggestion and show it as inline completion if it matches the typed text
  const highlightSuggestion = useCallback(
    (index) => {
      setHighlightedIndex(index);
      const suggestion = suggestions[index];
      if (suggestion && isCompletionFor(suggestion, typedValueRef.current)) {
        showCompletion(suggestion);
      } else {
        clearCompletion();
      }
    },
    [suggestions, showCompletion, clearCompletion]
  );

  // Handle keyboard navigation
  const handleKeyDown = useCallback(
    (e) => {
      if (!isOpen) {
        if (e.key === "Enter" || e.key === "Tab") {
          acceptCompletion();
        }
        return;
      }

      switch (e.key) {
        case "ArrowDown":
          e.preventDefault();
          highlightSuggestion(
            highlightedIndex < suggestions.length - 1 ? highlightedIndex + 1 : highlightedIndex
          );
          break;
        case "ArrowUp":
          e.preventDefault();
          highlightSuggestion(highlightedIndex > 0 ? highlightedIndex - 1 : -1);
          break;
        case "Enter":
          e.preventDefault();
          if (highlightedIndex >= 0 && highlightedIndex < suggestions.length) {
            selectSuggestion(suggestions[highlightedIndex]);
          }
          break;
        case "Escape":
          clearCompletion();
          setIsOpen(false);
          setHighlightedIndex(-1);
          break;
        case "Tab":
          acceptCompletion();
          setIsOpen(false);
          setHighlightedIndex(-1);
          break;
      }
    },
    [
      isOpen,
      highlightedIndex,
      suggestions,
      selectSuggestion,
      highlightSuggestion,
      acceptCompletion,
      clearCompletion
    ]
  );

  // Attach event listeners to the input
  useEffect(() => {
    const input = inputRef.current;
    if (!input) return;

    const onInput = (e) => {
      // Skip events we dispatched ourselves after filling in a suggestion
      if (justSelectedRef.current) {
        justSelectedRef.current = false;
        return;
      }

      const value = e.target.value;
      const previousCompletion = completionRef.current;
      typedValueRef.current = value;
      completionRef.current = null;
      // Deleting (e.g. Backspace removing the completion) shouldn't bring the completion back
      suppressCompletionRef.current = Boolean(e.inputType && e.inputType.startsWith("delete"));

      // Keep showing the completion while the user types along with it
      if (previousCompletion && isCompletionFor(previousCompletion, value) && canComplete()) {
        showCompletion(previousCompletion);
      }

      handleInputChange(value);
      updatePosition();
    };

    const onCompositionStart = () => {
      composingRef.current = true;
    };

    const onCompositionEnd = () => {
      composingRef.current = false;
    };

    const onFocus = () => {
      updatePosition();
      if (input.value && suggestions.length > 0) {
        setIsOpen(true);
      }
    };

    const onBlur = () => {
      acceptCompletion();
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
    input.addEventListener("compositionstart", onCompositionStart);
    input.addEventListener("compositionend", onCompositionEnd);

    return () => {
      input.removeEventListener("input", onInput);
      input.removeEventListener("focus", onFocus);
      input.removeEventListener("blur", onBlur);
      input.removeEventListener("keydown", onKeyDown);
      input.removeEventListener("compositionstart", onCompositionStart);
      input.removeEventListener("compositionend", onCompositionEnd);
    };
  }, [
    handleInputChange,
    handleKeyDown,
    updatePosition,
    suggestions.length,
    acceptCompletion,
    canComplete,
    showCompletion
  ]);

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
      // Keep focus in the input so clicking a suggestion doesn't count as leaving the field
      onMouseDown={(e) => e.preventDefault()}
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

// Whether the suggestion extends the typed text (case-insensitively)
const isCompletionFor = (suggestion, typed) =>
  typed.length > 0 &&
  suggestion.length > typed.length &&
  suggestion.toLowerCase().startsWith(typed.toLowerCase());

Autocomplete.propTypes = {
  inputSelector: PropTypes.string.isRequired,
  source: PropTypes.oneOfType([PropTypes.string, PropTypes.func]).isRequired,
  getDependencies: PropTypes.func
};

export default Autocomplete;
