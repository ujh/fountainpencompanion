import { createRoot } from "react-dom/client";
import { ErrorBoundary } from "../ErrorBoundary";
import App from "./app";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("new-public-inks");
  if (el) {
    const root = createRoot(el);
    root.render(
      <ErrorBoundary>
        <App loggedIn={"loggedIn" in el.dataset} />
      </ErrorBoundary>
    );
  }
});
