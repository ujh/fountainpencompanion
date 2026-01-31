import React from "react";
import { createRoot } from "react-dom/client";
import { Autocomplete } from "../components/Autocomplete";

const CollectedPensAutocomplete = () => {
  // Simple fetch function for endpoints that return an array directly
  const fetchSimple = (url) => async (term) => {
    const response = await fetch(`${url}?term=${encodeURIComponent(term)}`);
    const data = await response.json();
    return data;
  };

  return (
    <>
      <Autocomplete inputSelector="#collected_pen_brand" source={fetchSimple("/pens/brands")} />
      <Autocomplete inputSelector="#collected_pen_model" source={fetchSimple("/pens/models")} />
      <Autocomplete inputSelector="#collected_pen_nib" source={fetchSimple("/pens/nibs")} />
    </>
  );
};

document.addEventListener("DOMContentLoaded", () => {
  // Only initialize if the collected pen form exists
  const brandInput = document.getElementById("collected_pen_brand");
  if (!brandInput) return;

  // Create a container for the autocomplete components
  const container = document.createElement("div");
  container.id = "collected-pens-autocomplete-container";
  document.body.appendChild(container);

  const root = createRoot(container);
  root.render(<CollectedPensAutocomplete />);
});
