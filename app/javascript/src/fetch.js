export function getRequest(path) {
  return request(path, "GET");
}

export function deleteRequest(path) {
  return request(path, "DELETE");
}

function request(path, method) {
  return fetch(path, {
    credentials: "same-origin",
    method: method,
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-Requested-With": "XMLHttpRequest",
      "X-CSRF-Token": csrfToken(),
    }
  })
}

const csrfToken = () => {
  const tokenElement = document.querySelector("meta[name='csrf-token']");
  return tokenElement ? tokenElement.getAttribute("content") : null;
};
