import {
  BRANDS_DATA_RECEIVED,
  DATA_RECEIVED,
  DELETE_ENTRY,
  FILTER_DATA,
  LINES_DATA_RECEIVED,
  LOADING_DATA,
  TOGGLE_FIELD,
  UPDATE_SUGGESTIONS,
  UPDATE_FIELD,
  UPDATE_FILTER,
} from "./actions";

const defaultState = {
  active: [],
  archived: [],
  brands: [],
  entries: [],
  filters: {},
  lines: [],
  loading: true,
  inks: [],
  suggestions: {
    brands: [],
    lines: [],
    inks: [],
  }
};

export default function reducer(state = defaultState, action) {
  switch(action.type) {
    case BRANDS_DATA_RECEIVED:
      return {
        ...state,
        brands: action.data.data
      }
    case LINES_DATA_RECEIVED:
      return {
        ...state,
        lines: action.data
      }
    case DATA_RECEIVED:
      return filterData({
        ...state,
        entries: action.data.data,
        loading: false,
      });
    case DELETE_ENTRY:
      return {
        ...state,
        entries: state.entries.filter(entry => entry.id != action.id)
      }
    case FILTER_DATA:
      return filterData(state);
    case LOADING_DATA:
      return { ...state, loading: true};
    case TOGGLE_FIELD:
      return {
        ...state,
        entries: state.entries.map(entry => toggleField(entry, action.fieldName, action.id))
      }
    case UPDATE_FIELD:
    return {
      ...state,
      entries: state.entries.map(entry => updateField(entry, action.fieldName, action.value, action.id))
    }
    case UPDATE_FILTER:
      const newFilter = { ...state.filters[action.filterName]};
      newFilter[action.filterField] = action.filterValue;
      const newFilters = { ...state.filters };
      newFilters[action.filterName] = newFilter;
      return { ...state, filters: newFilters };
    case UPDATE_SUGGESTIONS:
      return {
        ...state,
        suggestions: updateSuggestions(state)
      }
    default:
      return state;
  }
}

const updateField = (entry, fieldName, value, id) => {
  if (entry.id != id) return entry;
  return {
    ...entry,
    attributes: {
      ...entry.attributes,
      [fieldName]: value
    }
  }
}

const toggleField = (entry, fieldName, id) => {
  if (entry.id != id) return entry;
  return {
    ...entry,
    attributes: {
      ...entry.attributes,
      [fieldName]: !entry.attributes[fieldName]
    }
  }
}

const filterData = (state) => ({
  ...state,
  active: activeEntries(state.entries, state.filters.active),
  archived: archivedEntries(state.entries, state.filters.archived)
});

const activeEntries = (data, filters) => {
  const entries = data.filter(entry => !entry.attributes.archived)
  const filteredEntries = filterEntries(entries, filters);
  sortInks(filteredEntries);
  return {
    entries: filteredEntries,
    stats: calculateStats(filteredEntries),
    brands: calculateListOfBrands(entries),
  };
}

const archivedEntries = (data, filters) => {
  const entries = data.filter(entry => entry.attributes.archived)
  const filteredEntries = filterEntries(entries, filters);
  sortInks(filteredEntries);
  return {
    entries: filteredEntries,
    stats: calculateStats(filteredEntries),
    brands: calculateListOfBrands(entries),
  };
}

const filterEntries = (entries, filter = {}) => {
  let filteredEntries = [...entries];
  Object.entries(filter).forEach(([key, value]) => {
    filteredEntries = filteredEntries.filter(entry => {
      if (value) {
        return entry.attributes[key] == value;
      } else {
        return true;
      }
    })
  })
  return filteredEntries;
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

const updateSuggestions = (args) => {
  return {
    brands: brandSuggestions(args),
    lines: lineSuggestions(args),
    inks: inkSuggestions(args)
  }
}

const brandSuggestions = ({brands, entries}) => {
  const brand_names = brands.map(b => b.attributes.popular_name);
  const user_brand_names = entries.map(e => e.attributes.brand_name);
  const brand_suggestions = [...(new Set([...brand_names, ...user_brand_names]))];
  brand_suggestions.sort();
  return brand_suggestions;
}

const lineSuggestions = ({lines, entries}) => {
  const user_line_names = entries.map(e => e.attributes.line_name);
  const line_suggestions = [...(new Set([...lines, ...user_line_names]))];
  line_suggestions.sort();
  return line_suggestions;
}

const inkSuggestions = ({inks, entries}) => {
  const ink_names = inks.map(i => i.attributes.popular_name);
  const user_ink_names = entries.map(e => e.attributes.ink_name);
  const ink_suggestions = [...(new Set([...ink_names, ...user_ink_names]))];
  ink_suggestions.sort();
  return ink_suggestions;
}
