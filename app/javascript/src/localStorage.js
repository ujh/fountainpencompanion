/**
 * @param {string} key
 * @returns {unknown | null}
 */
export function getItem(key) {
  try {
    return localStorage.getItem(key);
  } catch (e) {
    // In private browsing interacting with localStorage may raise an error in certain browsers.
    // Err on the side of caution and return null as if no value was found.
    return null;
  }
}

/**
 * @param {string} key
 * @param {unknown} value
 */
export function setItem(key, value) {
  try {
    return localStorage.setItem(key, value);
  } catch (e) {
    // In private browsing interacting with localStorage may raise an error in certain browsers.
    // Err on the side of caution.
  }
}
