import "whatwg-fetch";

export function deleteRequest(path) {
  return request(path, "DELETE");
}

export function getRequest(path) {
  return request(path, "GET");
}

export function postRequest(path, body) {
  return request(path, "POST", body);
}

export function putRequest(path, body) {
  return request(path, "PUT", body);
}

function request(path, method, body) {
  return req(path, method, body);
}

async function req(path, method, body, retries = 5, csrfRefreshed = false) {
  let response;
  try {
    response = await fetch(path, {
      credentials: "same-origin",
      method: method,
      body: JSON.stringify(body),
      headers: {
        Accept: "application/vnd.api+json",
        "Content-Type": "application/vnd.api+json",
        "X-CSRF-Token": csrfToken()
      }
    });
  } catch (error) {
    if (method === "GET" && retries > 0) {
      console.log("Retrying after network error", path, method, retries);
      return req(path, method, body, retries - 1);
    }
    throw error;
  }
  if (response.status === 401) {
    window.location.href = "/users/sign_in";
    return;
  }
  // The page's CSRF token goes stale when the session changes underneath it
  // (e.g. the session cookie expired and the user got logged back in via
  // remember-me). Fetch a fresh token and retry once instead of failing.
  if (!csrfRefreshed && (await isInvalidCsrfToken(response)) && (await refreshCsrfToken())) {
    return req(path, method, body, retries, true);
  }
  const failure = !response.ok;
  if (method === "GET" && failure && retries > 0) {
    console.log("Retrying", path, method, body, retries);
    return req(path, method, body, retries - 1);
  } else {
    return response;
  }
}

const csrfTokenElement = () => document.querySelector("meta[name='csrf-token']");

const csrfToken = () => {
  const tokenElement = csrfTokenElement();
  return tokenElement ? tokenElement.getAttribute("content") : null;
};

const isInvalidCsrfToken = async (response) => {
  if (response.status !== 422) return false;
  try {
    const json = await response.clone().json();
    return json.errors?.some((error) => error.code === "invalid_csrf_token") ?? false;
  } catch {
    return false;
  }
};

// Requests failing at the same time share one refresh. Each refresh can start a
// new session, so parallel refreshes could leave the page with a token that
// doesn't match the session cookie the browser ended up keeping.
let pendingCsrfRefresh = null;

const refreshCsrfToken = () => {
  pendingCsrfRefresh ??= fetchCsrfToken().finally(() => {
    pendingCsrfRefresh = null;
  });
  return pendingCsrfRefresh;
};

const fetchCsrfToken = async () => {
  const tokenElement = csrfTokenElement();
  if (!tokenElement) return false;
  try {
    const response = await fetch("/csrf_token", {
      credentials: "same-origin",
      headers: { Accept: "application/json" }
    });
    if (!response.ok) return false;
    const { token } = await response.json();
    if (!token) return false;
    tokenElement.setAttribute("content", token);
    return true;
  } catch {
    return false;
  }
};
