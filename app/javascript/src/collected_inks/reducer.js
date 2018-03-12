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
  sortInks(entries);
  return {entries, stats: calculateStats(entries), brands: calculateListOfBrands(entries)};
}

const archivedEntries = (data) => {
  const entries = data.data.filter(entry => entry.attributes.archived)
  sortInks(entries);
  return {entries, stats: calculateStats(entries), brands: calculateListOfBrands(entries)};
}

function sortInks(inks) {
  inks.sort((a, b) => {
    const keya = ["brand_name", "line_name", "ink_name"].map(n => a.attributes[n]).join();
    const keyb = ["brand_name", "line_name", "ink_name"].map(n => b.attributes[n]).join();
    return keya.localeCompare(keyb);
  })
}

function calculateStats(inks) {
  const stats = {};
  stats.inks = inks.length;
  stats.bottles = inks.filter(ink => ink.attributes.kind == "bottle").length;
  stats.samples = inks.filter(ink => ink.attributes.kind == "sample").length;
  stats.cartridges = inks.filter(ink => ink.attributes.kind == "cartridge").length;
  stats.brands = (new Set(inks.map(ink => ink.attributes.brand_name))).size;
  return stats;
}

function calculateListOfBrands(inks) {
  const brands = [...(new Set(inks.map(ink => ink.attributes.brand_name)))];
  brands.sort()
  return ["", ...brands];
}
