import { reducer, initalState } from "./reducer";
import {
  ADD_MACRO_CLUSTER,
  ASSIGN_TO_MACRO_CLUSTER,
  NEXT,
  NEXT_MACRO_CLUSTER,
  PREVIOUS,
  PREVIOUS_MACRO_CLUSTER,
  REMOVE_MICRO_CLUSTER,
  SET_LOADING_PERCENTAGE,
  SET_MACRO_CLUSTERS,
  SET_MICRO_CLUSTERS,
  UPDATE_MACRO_CLUSTER,
  UPDATE_SELECTED_BRANDS,
  UPDATING
} from "./actions";

describe("reducer", () => {
  describe("ADD_MACRO_CLUSTER", () => {
    const action = {
      type: ADD_MACRO_CLUSTER,
      payload: { id: 1, type: "macro_cluster" }
    };

    it("adds the new macro cluster", () => {
      const newState = reducer(initalState, action);
      expect(newState.macroClusters).toStrictEqual([
        { id: 1, type: "macro_cluster" }
      ]);
    });

    it("increments the counter", () => {
      const newState = reducer(initalState, action);
      expect(newState.updateCounter).toBe(1);
    });
  });

  describe("ASSIGN_TO_MACRO_CLUSTER", () => {
    const state = {
      ...initalState,
      macroClusters: [
        { id: 1, type: "macro_cluster", micro_clusters: [] },
        { id: 2, type: "macro_cluster", micro_clusters: [] }
      ]
    };
    const action = {
      type: ASSIGN_TO_MACRO_CLUSTER,
      payload: { id: 41, type: "micro_cluster", macro_cluster: { id: 2 } }
    };

    it("assigns micro cluster to the correct macro cluster", () => {
      const newState = reducer(state, action);
      expect(newState.macroClusters).toStrictEqual([
        { id: 1, type: "macro_cluster", micro_clusters: [] },
        {
          id: 2,
          type: "macro_cluster",
          micro_clusters: [
            { id: 41, type: "micro_cluster", macro_cluster: { id: 2 } }
          ]
        }
      ]);
    });

    it("increments the counter", () => {
      const newState = reducer(state, action);
      expect(newState.updateCounter).toBe(1);
    });
  });

  describe("NEXT", () => {
    it("increments the index by one", () => {
      const state = { index: 0, selectedMicroClusters: [1, 2, 3] };
      const newState = reducer(state, { type: NEXT });
      expect(newState.index).toBe(1);
    });

    it("wraps around when reaching the end", () => {
      const state = { index: 2, selectedMicroClusters: [1, 2, 3] };
      const newState = reducer(state, { type: NEXT });
      expect(newState.index).toBe(0);
    });
  });

  describe("NEXT_MACRO_CLUSTER", () => {
    it("increments the index by one", () => {
      const state = {
        ...initalState,
        selectedMacroClusterIndex: 0,
        macroClusters: [1, 2, 3]
      };
      const newState = reducer(state, { type: NEXT_MACRO_CLUSTER });
      expect(newState.selectedMacroClusterIndex).toBe(1);
    });

    it("does nothing when on the last entry", () => {
      const state = {
        ...initalState,
        selectedMacroClusterIndex: 2,
        macroClusters: [1, 2, 3]
      };
      const newState = reducer(state, { type: NEXT_MACRO_CLUSTER });
      expect(newState.selectedMacroClusterIndex).toBe(2);
    });
  });

  describe("PREVIOUS", () => {
    it("decrements the index by one", () => {
      const state = { index: 1, selectedMicroClusters: [1, 2, 3] };
      const newState = reducer(state, { type: PREVIOUS });
      expect(newState.index).toBe(0);
    });

    it("wraps around when reaching the beginning", () => {
      const state = { index: 0, selectedMicroClusters: [1, 2, 3] };
      const newState = reducer(state, { type: PREVIOUS });
      expect(newState.index).toBe(2);
    });
  });

  describe("PREVIOUS_MACRO_CLUSTER", () => {
    it("decrements the index by one", () => {
      const state = {
        ...initalState,
        selectedMacroClusterIndex: 1,
        macroClusters: [1, 2, 3]
      };
      const newState = reducer(state, { type: PREVIOUS_MACRO_CLUSTER });
      expect(newState.selectedMacroClusterIndex).toBe(0);
    });

    it("does nothing when on the first entry", () => {
      const state = {
        ...initalState,
        selectedMacroClusterIndex: 0,
        macroClusters: [1, 2, 3]
      };
      const newState = reducer(state, { type: PREVIOUS_MACRO_CLUSTER });
      expect(newState.selectedMacroClusterIndex).toBe(0);
    });
  });

  describe("REMOVE_MICRO_CLUSTER", () => {
    it("removes the cluster from microClusters", () => {
      const state = {
        ...initalState,
        microClusters: [
          { id: 1, type: "micro_cluster" },
          { id: 2, type: "micro_cluster" }
        ]
      };
      const newState = reducer(state, {
        type: REMOVE_MICRO_CLUSTER,
        payload: { id: 1, type: "micro_cluster" }
      });
      expect(newState.microClusters).toStrictEqual([
        { id: 2, type: "micro_cluster" }
      ]);
    });

    it("removes the cluster from selectedMicroClusters", () => {
      const state = {
        ...initalState,
        selectedMicroClusters: [
          { id: 1, type: "micro_cluster" },
          { id: 2, type: "micro_cluster" }
        ]
      };
      const newState = reducer(state, {
        type: REMOVE_MICRO_CLUSTER,
        payload: { id: 1, type: "micro_cluster" }
      });
      expect(newState.selectedMicroClusters).toStrictEqual([
        { id: 2, type: "micro_cluster" }
      ]);
    });

    it("resets selection when last selected micro clusters removed", () => {
      const state = {
        ...initalState,
        selectedBrands: ["selected brands"],
        selectedMicroClusters: [{ id: 1, type: "micro_cluster" }],
        microClusters: [{ id: 2, type: "micro_cluster" }]
      };
      const newState = reducer(state, {
        type: REMOVE_MICRO_CLUSTER,
        payload: { id: 1, type: "micro_cluster" }
      });
      expect(newState.selectedBrands).toStrictEqual([]);
      expect(newState.selectedMicroClusters).toStrictEqual([
        { id: 2, type: "micro_cluster" }
      ]);
    });

    it("does not reset the select when selected micro clusters present", () => {
      const state = {
        ...initalState,
        selectedBrands: ["selected brands"],
        selectedMicroClusters: [{ id: 1, type: "micro_cluster" }],
        microClusters: [{ id: 2, type: "micro_cluster" }]
      };
      const newState = reducer(state, {
        type: REMOVE_MICRO_CLUSTER,
        payload: { id: 2, type: "micro_cluster" }
      });
      expect(newState.selectedBrands).toStrictEqual(["selected brands"]);
      expect(newState.selectedMicroClusters).toStrictEqual([
        { id: 1, type: "micro_cluster" }
      ]);
    });
  });

  describe("SET_MACRO_CLUSTERS", () => {
    it("sets the clusters", () => {
      const state = { ...initalState, macroClusters: [] };
      const newState = reducer(state, {
        type: SET_MACRO_CLUSTERS,
        payload: [{ id: 1, type: "macro_cluster" }]
      });
      expect(newState.macroClusters).toStrictEqual([
        { id: 1, type: "macro_cluster" }
      ]);
    });

    it("sets loadingMacroClusters to false", () => {
      const state = { ...initalState, loadingMacroClusters: true };
      const newState = reducer(state, {
        type: SET_MACRO_CLUSTERS,
        payload: [{ id: 1, type: "macro_cluster" }]
      });
      expect(newState.loadingMacroClusters).toBe(false);
    });
  });

  describe("SET_MICRO_CLUSTERS", () => {
    it("sets the clusters", () => {
      const state = { ...initalState, microClusters: [] };
      const newState = reducer(state, {
        type: SET_MICRO_CLUSTERS,
        payload: [{ id: 1, type: "micro_cluster", entries: [] }]
      });
      expect(newState.microClusters).toStrictEqual([
        { id: 1, type: "micro_cluster", entries: [] }
      ]);
    });

    it("sorts the clusters by number of entries", () => {
      const state = { ...initalState, microClusters: [] };
      const newState = reducer(state, {
        type: SET_MICRO_CLUSTERS,
        payload: [
          { id: 1, type: "micro_cluster", entries: [1] },
          { id: 2, type: "micro_cluster", entries: [1, 1] }
        ]
      });
      expect(newState.microClusters).toStrictEqual([
        { id: 2, type: "micro_cluster", entries: [1, 1] },
        { id: 1, type: "micro_cluster", entries: [1] }
      ]);
    });

    it("sets the selected clusters", () => {
      const state = { ...initalState, selectedMicroClusters: [] };
      const newState = reducer(state, {
        type: SET_MICRO_CLUSTERS,
        payload: [
          { id: 1, type: "micro_cluster", entries: [1] },
          { id: 2, type: "micro_cluster", entries: [1, 1] }
        ]
      });
      expect(newState.selectedMicroClusters).toStrictEqual([
        { id: 2, type: "micro_cluster", entries: [1, 1] },
        { id: 1, type: "micro_cluster", entries: [1] }
      ]);
    });

    it("filters the selected clusters by brand", () => {
      const state = {
        ...initalState,
        selectedMicroClusters: [],
        selectedBrands: [{ value: "aaa" }]
      };
      const newState = reducer(state, {
        type: SET_MICRO_CLUSTERS,
        payload: [
          {
            id: 1,
            type: "micro_cluster",
            entries: [],
            simplified_brand_name: "aaa"
          },
          {
            id: 2,
            type: "micro_cluster",
            entries: [],
            simplified_brand_name: "bbb"
          }
        ]
      });
      expect(newState.selectedMicroClusters).toStrictEqual([
        {
          id: 1,
          type: "micro_cluster",
          entries: [],
          simplified_brand_name: "aaa"
        }
      ]);
    });

    it("sets the loading flag to false", () => {
      const state = { ...initalState, loadingMicroClusters: true };
      const newState = reducer(state, {
        type: SET_MICRO_CLUSTERS,
        payload: [{ id: 1, type: "micro_cluster", entries: [] }]
      });
      expect(newState.loadingMicroClusters).toBe(false);
    });
  });

  describe("SET_LOADING_PERCENTAGE", () => {
    it("sets loadingPercentage", () => {
      const state = { ...initalState, loadingPercentage: 0 };
      const newState = reducer(state, {
        type: SET_LOADING_PERCENTAGE,
        payload: 100
      });
      expect(newState.loadingPercentage).toBe(100);
    });
  });

  describe("UPDATE_MACRO_CLUSTER", () => {
    it("updates the supplied cluster", () => {
      const state = {
        ...initalState,
        macroClusters: [
          { id: 1, type: "macro_cluster", value: 1 },
          { id: 2, type: "macro_cluster", value: 2 }
        ]
      };
      const newState = reducer(state, {
        type: UPDATE_MACRO_CLUSTER,
        payload: { id: 2, type: "macro_cluster", value: 10 }
      });
      expect(newState.macroClusters).toStrictEqual([
        { id: 1, type: "macro_cluster", value: 1 },
        { id: 2, type: "macro_cluster", value: 10 }
      ]);
    });
  });

  describe("UPDATE_SELECTED_BRANDS", () => {
    const state = {
      ...initalState,
      selectedMicroClusters: [],
      microClusters: [
        {
          id: 1,
          type: "micro_cluster",
          entries: [],
          simplified_brand_name: "aaa"
        },
        {
          id: 2,
          type: "micro_cluster",
          entries: [],
          simplified_brand_name: "bbb"
        }
      ]
    };
    const action = {
      type: UPDATE_SELECTED_BRANDS,
      payload: [{ value: "aaa" }]
    };

    it("updates the selected brands", () => {
      const newState = reducer(state, action);
      expect(newState.selectedBrands).toStrictEqual([{ value: "aaa" }]);
    });

    it("updates the selected micro clusters", () => {
      const newState = reducer(state, action);
      expect(newState.selectedMicroClusters).toStrictEqual([
        {
          id: 1,
          type: "micro_cluster",
          entries: [],
          simplified_brand_name: "aaa"
        }
      ]);
    });
  });

  describe("UPDATING", () => {
    it("sets updating to true", () => {
      const state = { ...initalState, updating: false };
      const newState = reducer(state, { type: UPDATING });
      expect(newState.updating).toBe(true);
    });
  });
});
