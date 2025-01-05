import "whatwg-fetch";

export function deleteRequest(path, timeout = 30) {
  return request(path, "DELETE", undefined, timeout);
}

export function getRequest(path, timeout = 30) {
  return request(path, "GET", undefined, timeout);
}

export function postRequest(path, body, timeout = 30) {
  return request(path, "POST", body, timeout);
}

export function putRequest(path, body, timeout = 30) {
  return request(path, "PUT", body, timeout);
}

function request(path, method, body, timeout) {
  return req(path, method, body, timeout);
}

async function req(path, method, body, timeout, retries = 5) {
  let response;
  let failed;
  try {
    let extra = {};
    try {
      extra = { signal: AbortSignal.timeout(timeout * 1000) };
    } catch (_e) {
      // Ignore the error
    }
    response = await fetch(path, {
      credentials: "same-origin",
      method: method,
      body: JSON.stringify(body),
      headers: {
        Accept: "application/vnd.api+json",
        "Content-Type": "application/vnd.api+json",
        "X-CSRF-Token": csrfToken()
      },
      ...extra
    });
  } catch (e) {
    console.error("Failed to fetch", e);
    failed = true;
  }
  const failure = failed || !response.ok;
  if (method === "GET" && failure && retries > 0) {
    console.log("Retrying", path, method, body, retries);
    return req(path, method, body, timeout, retries - 1);
  } else {
    return response;
  }
}

const csrfToken = () => {
  const tokenElement = document.querySelector("meta[name='csrf-token']");
  return tokenElement ? tokenElement.getAttribute("content") : null;
};
