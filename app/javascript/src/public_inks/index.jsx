import * as React from "react";
import * as ReactDOM from "react-dom";

import App from "./app";

const renderPublicInks = (el) => {
    ReactDOM.render(<App />, el)
}

export default renderPublicInks;
