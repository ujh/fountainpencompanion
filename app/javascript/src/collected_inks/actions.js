import { deleteRequest, getRequest, postRequest, putRequest } from "src/fetch";

export const BRANDS_DATA_RECEIVED = "BRANDS_DATA_RECEIVED";
export const DATA_RECEIVED = "DATA_RECEIVED";
export const DELETE_ENTRY = "DELETE_ENTRY";
export const FILTER_DATA = "FILTER_DATA";
export const LOADING_DATA = "LOADING_DATA";
export const TOGGLE_FIELD = "TOGGLE_FIELD";
export const UPDATE_FIELD = "UPDATE_FIELD";
export const UPDATE_FILTER = "UPDATE_FILTER";
export const UPDATE_SUGGESTIONS = "UPDATE_SUGGESTIONS";

export const filterData = () => ({type: FILTER_DATA});
export const loadingData = () => ({type: LOADING_DATA});
export const updateFilter = (data) => ({
  type: UPDATE_FILTER,
  ...data
});
export const updateSuggestions = () => ({type: UPDATE_SUGGESTIONS});

export const brandsDataReceived = data => (dispatch) => {
  dispatch({type: BRANDS_DATA_RECEIVED, data});
  dispatch(updateSuggestions());
}

export const dataReceived = data => (dispatch) => {
  dispatch({type: DATA_RECEIVED, data});
  dispatch(updateSuggestions());
}

export const deleteEntry = (id) => dispatch => {
  dispatch({type: DELETE_ENTRY, id});
  deleteRequest(`/collected_inks/${id}`);
  dispatch(filterData());
}
export const fetchData = () => dispatch => {
  dispatch(loadingData());
  dispatch(fetchAutocompleteData())
  return getRequest("/collected_inks").then(
    response => response.json()
  ).then(
    json => dispatch(dataReceived(json))
  )
}

export const fetchAutocompleteData = () => dispatch => {
  return getRequest("/brands").then(
    response => response.json()
  ).then(
    json => {
      setTimeout(() => fetchAutocompleteData()(dispatch), 1000*30);
      return dispatch(brandsDataReceived(json));
    }
  )
}

export const toggleField = (fieldName, id) => (dispatch, getState) => {
  dispatch({type: TOGGLE_FIELD, fieldName, id});
  updateEntryOnServer(id, getState);
};

export const toggleArchived = (id) => (dispatch, getState) => {
  const previouslyArchived = getEntry(id, getState).attributes.archived;
  dispatch(toggleField("archived", id));
  dispatch(filterData());
  const url = `/collected_inks/${id}/archive`;
  if (previouslyArchived) {
    return deleteRequest(url);
  } else {
    return postRequest(url);
  }
}

export const togglePrivacy = (id) => dispatch => {
  dispatch(toggleField("private", id));
  dispatch(filterData());
}

export const toggleSwabbed = (id) => dispatch => {
  dispatch(toggleField("swabbed", id));
  dispatch(filterData());
}

export const toggleUsed = (id) => dispatch => {
  dispatch(toggleField("used", id));
  dispatch(filterData());
}

export const updateField = (id, fieldName, value) => (dispatch, getState) => {
  dispatch({type: UPDATE_FIELD, id, fieldName, value});
  updateEntryOnServer(id, getState);
}

export const updateBrand = (id, value) => (dispatch, getState) => {
  dispatch(updateField(id, "brand_name", value));
  dispatch(updateSuggestions());
  dispatch(filterData());
}

export const updateColor = (id, value) => (dispatch, getState) => {
  dispatch(updateField(id, "color", value));
  dispatch(filterData());
}

export const updateComment = (id, value) => (dispatch, getState) => {
  dispatch(updateField(id, "comment", value));
  dispatch(filterData());
}

export const updateInk = (id, value) => (dispatch, getState) => {
  dispatch(updateField(id, "ink_name", value));
  dispatch(updateSuggestions());
  dispatch(filterData());
}

export const updateKind = (id, value) => (dispatch, getState) => {
  dispatch(updateField(id, "kind", value));
  dispatch(filterData());
}

export const updateLine = (id, value) => (dispatch, getState) => {
  dispatch(updateField(id, "line_name", value));
  dispatch(updateSuggestions());
  dispatch(filterData());
}

export const updateFilterAndRecalculate = (data) => dispatch => {
  dispatch(updateFilter(data));
  dispatch(filterData());
}

const getEntry = (id, getState) => getState().entries.find(e => e.id == id);

const updateEntryOnServer = (id, getState) => {
  const entry = getEntry(id, getState);
  putRequest(`/collected_inks/${id}`, {data: entry})
}
