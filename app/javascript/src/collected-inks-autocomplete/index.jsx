import React from "react";
import { createRoot } from "react-dom/client";
import { Autocomplete } from "../components/Autocomplete";

const CollectedInksAutocomplete = () => {
  // Fetch brand names from API
  const fetchBrands = async (term) => {
    const response = await fetch(`/api/v1/brands?term=${encodeURIComponent(term)}`);
    const data = await response.json();
    return data.data.map((e) => e.attributes.name);
  };

  // Fetch line names from API
  const fetchLines = async (term, { brandName }) => {
    const params = new URLSearchParams({
      term: term,
      brand_name: brandName || ""
    });
    const response = await fetch(`/api/v1/lines?${params.toString()}`);
    const data = await response.json();
    return data.data.map((e) => e.attributes.line_name);
  };

  // Fetch ink names from API
  const fetchInks = async (term, { brandName }) => {
    const params = new URLSearchParams({
      term: term,
      brand_name: brandName || ""
    });
    const response = await fetch(`/api/v1/inks?${params.toString()}`);
    const data = await response.json();
    return data.data.map((e) => e.attributes.ink_name);
  };

  // Get the current brand name value for dependent autocompletes
  const getBrandName = () => {
    const brandInput = document.getElementById("collected_ink_brand_name");
    return { brandName: brandInput ? brandInput.value : "" };
  };

  return (
    <>
      <Autocomplete inputSelector="#collected_ink_brand_name" source={fetchBrands} />
      <Autocomplete
        inputSelector="#collected_ink_line_name"
        source={fetchLines}
        getDependencies={getBrandName}
      />
      <Autocomplete
        inputSelector="#collected_ink_ink_name"
        source={fetchInks}
        getDependencies={getBrandName}
      />
    </>
  );
};

document.addEventListener("DOMContentLoaded", () => {
  // Only initialize if the collected ink form exists
  const brandInput = document.getElementById("collected_ink_brand_name");
  if (!brandInput) return;

  // Create a container for the autocomplete components
  const container = document.createElement("div");
  container.id = "collected-inks-autocomplete-container";
  document.body.appendChild(container);

  const root = createRoot(container);
  root.render(<CollectedInksAutocomplete />);
});
