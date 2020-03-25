import { SET_MICRO_CLUSTERS, UPDATE_SELECTED_BRANDS } from "./actions";

export const initalState = {
  selectedBrands: [],
  microClusters: {
    data: [],
    included: []
  },
  selectedMicroClusters: {
    data: [],
    included: []
  }
};

export const reducer = (state, { type, payload }) => {
  switch (type) {
    case SET_MICRO_CLUSTERS:
      return {
        ...state,
        microClusters: payload,
        selectedMicroClusters: selectMicroClusters(
          state.selectedBrands,
          payload
        )
      };
    case UPDATE_SELECTED_BRANDS:
      const selectedBrands = payload || [];
      return {
        ...state,
        selectedBrands,
        selectedMicroClusters: selectMicroClusters(
          selectedBrands,
          state.microClusters
        )
      };
    default:
      return state;
  }
};

const selectMicroClusters = (selectedBrands, microClusters) => {
  if (selectedBrands.length) {
    return {
      included: microClusters.included,
      data: microClusters.data.filter(c =>
        state.selectedBrands
          .map(s => s.value)
          .includes(c.attributes.simplified_brand_name)
      )
    };
  } else {
    return microClusters;
  }
};
