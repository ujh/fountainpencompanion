/**
 * Compute the average color using quadratic mean (RMS) of RGB channels.
 * Matches the Ruby MacroCluster#recalculate_color algorithm.
 */
export function computeAverageColor(hexColors) {
  if (hexColors.length === 0) return null;

  const rgbColors = hexColors.map(parseHex);

  const avg = (channel) => {
    const sum = rgbColors.reduce((acc, c) => acc + c[channel] ** 2, 0);
    return Math.round(Math.sqrt(sum / rgbColors.length));
  };

  const r = avg("r");
  const g = avg("g");
  const b = avg("b");

  return toHex(r, g, b);
}

function parseHex(hex) {
  const h = hex.replace("#", "");
  return {
    r: parseInt(h.substring(0, 2), 16),
    g: parseInt(h.substring(2, 4), 16),
    b: parseInt(h.substring(4, 6), 16)
  };
}

function toHex(r, g, b) {
  const comp = (v) => v.toString(16).padStart(2, "0");
  return `#${comp(r)}${comp(g)}${comp(b)}`;
}
