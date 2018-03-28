import { createStore, applyMiddleware } from "redux";
import thunk from "redux-thunk";
import { composeWithDevTools } from "redux-devtools-extension";
import reducer from "./reducer";

const composeEnhancers = composeWithDevTools({ name: "Collected Inks" });

export default function store() {
  return createStore(
    reducer,
    composeEnhancers(applyMiddleware(thunk))
  );
}
