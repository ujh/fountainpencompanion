import {
  DATA_RECEIVED,
  LOADING_DATA,
} from "./actions";

const defaultState = {
  active: [],
  archived: [],
  loading: true,
};

export default function reducer(state = defaultState, action) {
  switch(action.type) {
    case DATA_RECEIVED:
      return {
        ...state,
        active: activeEntries(action.data),
        archived: archivedEntries(action.data),
        loading: false,
      }
    case LOADING_DATA:
      return { ...state, loading: true};
    default:
      return state;
  }
}

const activeEntries = (data) => {
  const entries = data.data.filter(entry => !entry.attributes.archived)
  return entries;
}

const archivedEntries = (data) => {
  const entries = data.data.filter(entry => entry.attributes.archived)
  return entries;
}
