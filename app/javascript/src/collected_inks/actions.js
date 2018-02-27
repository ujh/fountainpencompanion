import { get } from "src/fetch";

export const DATA_RECEIVED = "DATA_RECEIVED";
export const LOADING_DATA = "LOADING_DATA";

export const dataReceived = data => ({type: DATA_RECEIVED, data});
export const loadingData = () => ({type: LOADING_DATA});

export const fetchData = () => dispatch => {
  dispatch(loadingData());
  return get("/collected_inks").then(
    response => response.json()
  ).then(
    json => dispatch(dataReceived(json))
  )
}
