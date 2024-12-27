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

async function req(path, method, body, retries = 3) {
  const response = await fetch(path, {
    credentials: "same-origin",
    method: method,
    body: JSON.stringify(body),
    headers: {
      Accept: "application/vnd.api+json",
      "Content-Type": "application/vnd.api+json",
      "X-CSRF-Token": csrfToken()
    }
  });
  if (method === "GET" && response.status >= 500 && retries > 0) {
    console.log("Retrying", path, method, body, retries);
    return req(path, method, body, retries - 1);
  } else {
    return response;
  }
}

const csrfToken = () => {
  const tokenElement = document.querySelector("meta[name='csrf-token']");
  return tokenElement ? tokenElement.getAttribute("content") : null;
};
