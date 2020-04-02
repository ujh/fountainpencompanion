import _ from "lodash";

import {
  ADD_MACRO_CLUSTER,
  ASSIGN_TO_MACRO_CLUSTER,
  NEXT,
  PREVIOUS,
  REMOVE_MICRO_CLUSTER,
  SET_MACRO_CLUSTERS,
  SET_MICRO_CLUSTERS,
  UPDATE_SELECTED_BRANDS,
  UPDATING,
  UPDATE_MACRO_CLUSTER,
  NEXT_MACRO_CLUSTER,
  PREVIOUS_MACRO_CLUSTER
} from "./actions";

export const initalState = {
  activeCluster: null,
  index: 0,
  loadingMacroClusters: true,
  loadingMicroClusters: true,
  macroClusters: [],
  microClusters: [],
  selectedBrands: [],
  selectedMacroClusterIndex: 0,
  selectedMicroClusters: [],
  updateCounter: 0,
  updating: false
};

export const reducer = (state, action) => {
  const newState = updateActiveCluster(actualReducer(state, action));
  console.log(action.type, { action, state, newState });
  return newState;
};

const actualReducer = (state, { type, payload }) => {
  switch (type) {
    case ADD_MACRO_CLUSTER:
      return {
        ...state,
        macroClusters: [...state.macroClusters, payload],
        updateCounter: state.updateCounter + 1,
        updating: false
      };
    case ASSIGN_TO_MACRO_CLUSTER:
      return {
        ...state,
        macroClusters: state.macroClusters.map(mc => {
          if (mc.id == payload.macro_cluster.id) {
            return {
              ...mc,
              micro_clusters: [...mc.micro_clusters, payload]
            };
          } else {
            return mc;
          }
        }),
        updateCounter: state.updateCounter + 1,
        updating: false
      };
    case NEXT:
      return changeIndex(state, state.index + 1);
    case NEXT_MACRO_CLUSTER:
      return changeSelectedMacroClusterIndex(
        state,
        state.selectedMacroClusterIndex + 1
      );
    case PREVIOUS:
      return changeIndex(state, state.index - 1);
    case PREVIOUS_MACRO_CLUSTER:
      return changeSelectedMacroClusterIndex(
        state,
        state.selectedMacroClusterIndex - 1
      );
    case REMOVE_MICRO_CLUSTER:
      return removeMicroCluster(state, payload);
    case SET_MACRO_CLUSTERS:
      return { ...state, macroClusters: payload, loadingMacroClusters: false };
    case SET_MICRO_CLUSTERS: {
      const microClusters = _.reverse(
        _.sortBy(payload, "collected_inks.length")
      );
      return {
        ...state,
        microClusters,
        selectedMicroClusters: selectMicroClusters(
          state.selectedBrands,
          microClusters
        ),
        loadingMicroClusters: false
      };
    }
    case UPDATE_MACRO_CLUSTER:
      return {
        ...state,
        macroClusters: state.macroClusters.map(c => {
          if (c.id == payload.id) return payload;
          return c;
        })
      };
    case UPDATE_SELECTED_BRANDS:
      return updateSelectedBrands(state, payload);
    case UPDATING:
      return { ...state, updating: true };
    default:
      return state;
  }
};

const changeSelectedMacroClusterIndex = (state, newIndex) => {
  if (newIndex < 0 || newIndex >= state.macroClusters.length) return state;
  return { ...state, selectedMacroClusterIndex: newIndex };
};

const updateActiveCluster = state => {
  let index = state.index;
  if (index >= state.selectedMicroClusters.length) index = 0;
  const activeCluster = state.selectedMicroClusters[index];
  let selectedMacroClusterIndex = state.selectedMacroClusterIndex;
  if (activeCluster && state.activeCluster) {
    if (activeCluster.id != state.activeCluster.id)
      selectedMacroClusterIndex = 0;
  }
  return { ...state, index, activeCluster, selectedMacroClusterIndex };
};

const removeMicroCluster = (state, payload) => {
  let selectedBrands;
  const microClusters = withoutElement(payload, state.microClusters);
  let selectedMicroClusters = withoutElement(
    payload,
    state.selectedMicroClusters
  );
  if (selectedMicroClusters.length > 0) {
    selectedBrands = selectedBrands;
  } else {
    selectedBrands = [];
    selectedMicroClusters = microClusters;
  }
  return {
    ...state,
    microClusters,
    selectedMicroClusters,
    selectedBrands
  };
};

const updateSelectedBrands = (state, newSelectedBrands) => {
  const selectedBrands = newSelectedBrands || [];
  return {
    ...state,
    selectedBrands,
    selectedMicroClusters: selectMicroClusters(
      selectedBrands,
      state.microClusters
    )
  };
};

const changeIndex = (state, newIndex) => {
  const length = state.selectedMicroClusters.length;
  if (newIndex < 0) {
    return { ...state, index: length + newIndex };
  }
  return { ...state, index: newIndex % length };
};

const withoutElement = (element, clusters) => {
  return clusters.filter(c => !(c.id == element.id && c.type == element.type));
};

const selectMicroClusters = (selectedBrands, microClusters) => {
  if (selectedBrands.length) {
    const filtered = _.reverse(
      _.sortBy(
        microClusters.filter(c =>
          selectedBrands.map(s => s.value).includes(c.simplified_brand_name)
        ),
        "collected_inks.length"
      )
    );
    return filtered.length ? filtered : microClusters;
  } else {
    return microClusters;
  }
};
