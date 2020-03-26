import {
  NEXT,
  PREVIOUS,
  SET_MICRO_CLUSTERS,
  UPDATE_SELECTED_BRANDS,
  REMOVE_MICRO_CLUSTER
} from "./actions";

export const initalState = {
  selectedBrands: [],
  microClusters: {
    data: [],
    included: []
  },
  selectedMicroClusters: {
    data: [],
    included: []
  },
  index: 0,
  direction: "next"
};

export const reducer = (state, { type, payload }) => {
  let max;
  switch (type) {
    case NEXT:
      max = state.selectedMicroClusters.data.length;
      return {
        ...state,
        direction: "next",
        index: state.index < max - 1 ? state.index + 1 : 0
      };
    case PREVIOUS:
      max = state.selectedMicroClusters.data.length;
      return {
        ...state,
        direction: "prev",
        index: state.index > 0 ? state.index - 1 : max - 1
      };
    case REMOVE_MICRO_CLUSTER:
      return {
        ...state,
        microClusters: withoutElement(payload, state.microClusters),
        selectedMicroClusters: withoutElement(
          payload,
          state.selectedMicroClusters
        )
      };
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

const withoutElement = (element, clusters) => {
  return {
    ...clusters,
    data: clusters.data.filter(
      c => !(c.id == element.id && c.type == element.type)
    )
  };
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
