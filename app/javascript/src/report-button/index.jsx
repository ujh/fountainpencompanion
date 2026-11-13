import { createRoot } from "react-dom/client";
import { ErrorBoundary } from "../ErrorBoundary";
import { ReportButton } from "./ReportButton";

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".fpc-report-button").forEach((el, index) => {
    createRoot(el, { identifierPrefix: `report-button-${index}-` }).render(
      <ErrorBoundary>
        <ReportButton
          url={el.dataset.url}
          heading={el.dataset.heading}
          label={el.dataset.label}
          icon={el.dataset.icon === "true"}
        />
      </ErrorBoundary>
    );
  });
});
