import * as React from "react";
import { createRoot } from "react-dom/client";

import App from "./app";

const renderPublicInks = (el) => {
  const root = createRoot(el);
  root.render(<App />);
};

export default renderPublicInks;
