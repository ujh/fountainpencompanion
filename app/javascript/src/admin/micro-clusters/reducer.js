import { UPDATE_SELECTED_BRANDS } from "./actions";

export const initalState = { selectedBrands: [] };

export const reducer = (state, { type, payload }) => {
  switch (type) {
    case UPDATE_SELECTED_BRANDS:
      return {
        ...state,
        selectedBrands: payload || []
      };
    default:
      return state;
  }
};
