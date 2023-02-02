import convert from "color-convert";

/**
 *
 * @param {string} colorARGB
 * @param {string} colorBRGB
 * @returns {number}
 */
export const colorSort = (colorARGB, colorBRGB) => {
  if (!colorARGB) return 1;
  if (!colorBRGB) return -1;
  const colorA = hexToSortArray(colorARGB);
  const colorB = hexToSortArray(colorBRGB);
  let r = sortByElement(colorA, colorB, 0);
  if (r) return r;
  r = sortByElement(colorA, colorB, 1);
  if (r) return r;
  return sortByElement(colorA, colorB, 2);
};

const sortByElement = (arrayA, arrayB, i) => {
  if (arrayA[i] == arrayB[i]) return 0;
  return arrayA[i] < arrayB[i] ? -1 : 1;
};

// See https://www.alanzucconi.com/2015/09/30/colour-sorting/
const hexToSortArray = (hex) => {
  const repetitions = 8;
  const [r, g, b] = convert.hex.rgb(hex);
  const lum = Math.sqrt(0.241 * r + 0.691 * g + 0.068 * b);
  // eslint-disable-next-line no-unused-vars
  const [h, s, v] = convert.hex.hsv(hex);
  const h2 = Math.round(h * repetitions);
  let lum2 = Math.round(lum * repetitions);
  let v2 = Math.round(v * repetitions);
  if (h2 % 2 == 1) {
    v2 = repetitions - v2;
    lum2 = repetitions - lum2;
  }
  return [h2, lum2, v2];
};
