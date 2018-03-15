import { get } from "src/fetch";

export const DATA_RECEIVED = "DATA_RECEIVED";
export const DELETE_ENTRY = "DELETE_ENTRY";
export const FILTER_DATA = "FILTER_DATA";
export const LOADING_DATA = "LOADING_DATA";
export const UPDATE_FILTER = "UPDATE_FILTER";

export const dataReceived = data => ({type: DATA_RECEIVED, data});
export const filterData = () => ({type: FILTER_DATA});
export const loadingData = () => ({type: LOADING_DATA});
export const updateFilter = (data) => ({
  type: UPDATE_FILTER,
  ...data
});

export const deleteEntry = (id) => dispatch => {
  dispatch({type: DELETE_ENTRY, id});
  // TODO: Sync with server
  dispatch(filterData());
}
export const fetchData = () => dispatch => {
  dispatch(loadingData());
  return get("/collected_inks").then(
    response => response.json()
  ).then(
    json => dispatch(dataReceived(json))
  )
}

export const updateFilterAndRecalculate = (data) => dispatch => {
  dispatch(updateFilter(data));
  dispatch(filterData());
}
