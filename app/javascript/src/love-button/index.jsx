import { createRoot } from "react-dom/client";
import { ErrorBoundary } from "../ErrorBoundary";
import { LoveButton } from "./LoveButton";

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".fpc-love-button").forEach((el) => {
    createRoot(el).render(
      <ErrorBoundary>
        <LoveButton
          url={el.dataset.url}
          initialLoved={el.dataset.loved === "true"}
          initialCount={Number(el.dataset.count)}
        />
      </ErrorBoundary>
    );
  });
});
