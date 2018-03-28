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
  return fetch(path, {
    credentials: "same-origin",
    method: method,
    body: JSON.stringify(body),
    headers: {
      "Accept": "application/vnd.api+json",
      "Content-Type": "application/vnd.api+json",
      "X-CSRF-Token": csrfToken(),
    }
  })
}

const csrfToken = () => {
  const tokenElement = document.querySelector("meta[name='csrf-token']");
  return tokenElement ? tokenElement.getAttribute("content") : null;
};
