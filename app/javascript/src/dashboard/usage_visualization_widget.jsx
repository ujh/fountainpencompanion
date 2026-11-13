import convert from "color-convert";
import { useCallback, useContext, useEffect, useRef, useState } from "react";
import { getRequest, putRequest } from "../fetch";
import * as storage from "../localStorage";
import { Widget, WidgetDataContext } from "./widgets";

const RANGE_OPTIONS = [
  { value: "1m", label: "1 month" },
  { value: "3m", label: "3 months" },
  { value: "6m", label: "6 months" },
  { value: "1y", label: "1 year" },
  { value: "all", label: "All time" }
];
const VALID_RANGES = RANGE_OPTIONS.map((o) => o.value);
const VALID_SPEEDS = ["slow", "medium", "fast"];

let accountPreferencesPromise = null;

function getAccountPreferences() {
  if (!accountPreferencesPromise) {
    accountPreferencesPromise = getRequest("/account")
      .then(async (response) => {
        if (!response.ok) return {};
        const json = await response.json();
        return json.data.attributes.preferences || {};
      })
      .catch(() => ({}));
  }
  return accountPreferencesPromise;
}

async function savePreference(key, value) {
  try {
    await putRequest("/account", {
      user: { preferences: { [key]: value } }
    });
  } catch {
    // Silently fail — local state is already correct
  }
}

function useSyncedPreference(storageKey, apiKey, validValues, defaultValue) {
  const [value, setValueState] = useState(() => {
    const stored = storage.getItem(storageKey);
    return stored && validValues.includes(stored) ? stored : defaultValue;
  });

  useEffect(() => {
    let cancelled = false;

    async function syncWithServer() {
      const preferences = await getAccountPreferences();
      if (cancelled) return;

      const serverValue = preferences[apiKey];
      if (serverValue && validValues.includes(serverValue)) {
        storage.setItem(storageKey, serverValue);
        setValueState(serverValue);
      } else {
        const local = storage.getItem(storageKey);
        if (local && validValues.includes(local)) savePreference(apiKey, local);
      }
    }

    syncWithServer();
    return () => {
      cancelled = true;
    };
  }, [storageKey, apiKey, validValues, defaultValue]);

  const setValue = useCallback(
    (newValue) => {
      setValueState(newValue);
      storage.setItem(storageKey, newValue);
      savePreference(apiKey, newValue);
    },
    [storageKey, apiKey]
  );

  return [value, setValue];
}

export const UsageVisualizationWidget = ({ renderWhenInvisible }) => {
  const [range, setRange] = useSyncedPreference(
    "fpc-usage-viz-range",
    "usage_visualization_range",
    VALID_RANGES,
    "1y"
  );
  const [speed, setSpeed] = useSyncedPreference(
    "fpc-usage-viz-speed",
    "usage_visualization_speed",
    VALID_SPEEDS,
    "fast"
  );
  const path = `/dashboard/widgets/usage_visualization.json?range=${range}`;

  return (
    <Widget header="Usage visualization" path={path} renderWhenInvisible={renderWhenInvisible}>
      <UsageVisualizationWidgetContent
        range={range}
        setRange={setRange}
        speed={speed}
        setSpeed={setSpeed}
      />
    </Widget>
  );
};

const GRID_SIZE = 140;
const SWAP_RADIUS = 15;
const BLUR_RADIUS = 2;
const RENDER_SCALE = 2;

export function buildGrid(entries, cols, rows) {
  const totalPixels = cols * rows;
  const totalCount = entries.reduce((sum, e) => sum + e.count, 0);
  if (totalCount === 0) return { grid: [], inkInfo: [] };

  const shares = entries.map((entry) => (entry.count / totalCount) * totalPixels);
  const counts = shares.map(Math.floor);
  let unassigned = totalPixels - counts.reduce((sum, c) => sum + c, 0);
  const byRemainder = shares
    .map((share, i) => i)
    .sort((a, b) => shares[b] - counts[b] - (shares[a] - counts[a]));
  for (let k = 0; unassigned > 0; k++, unassigned--) counts[byRemainder[k]]++;

  const pixels = [];
  const inkInfo = [];
  entries.forEach((entry, i) => {
    const info = { name: entry.ink_name, inkId: entry.ink_id || null };
    for (let j = 0; j < counts[i]; j++) {
      pixels.push(entry.color);
      inkInfo.push(info);
    }
  });

  // Fisher-Yates shuffle
  for (let i = pixels.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    swap(pixels, i, j);
    swap(inkInfo, i, j);
  }

  return { grid: pixels, inkInfo };
}

function swap(array, i, j) {
  const tmp = array[i];
  array[i] = array[j];
  array[j] = tmp;
}

function toroidalDist(r1, c1, r2, c2, rows, cols) {
  let dr = Math.abs(r1 - r2);
  let dc = Math.abs(c1 - c2);
  if (dr > rows / 2) dr = rows - dr;
  if (dc > cols / 2) dc = cols - dc;
  return Math.sqrt(dr * dr + dc * dc);
}

function countSameNeighbors(grid, idx, cols, rows) {
  const color = grid[idx];
  const row = Math.floor(idx / cols);
  const col = idx % cols;
  let count = 0;

  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      const nr = (row + dr + rows) % rows;
      const nc = (col + dc + cols) % cols;
      if (grid[nr * cols + nc] === color) count++;
    }
  }
  return count;
}

function colorDistance(hexA, hexB) {
  const [h1, s1, v1] = convert.hex.hsv(hexA);
  const [h2, s2, v2] = convert.hex.hsv(hexB);
  // Circular hue distance (0-180)
  const dh = Math.min(Math.abs(h1 - h2), 360 - Math.abs(h1 - h2));
  const ds = Math.abs(s1 - s2);
  const dv = Math.abs(v1 - v2);
  return Math.sqrt(dh * dh + ds * ds + dv * dv);
}

const SIMILARITY_BLEND = 1.5; // How much similar colors pull toward each other

function angleTable(period) {
  const sin = new Float64Array(period);
  const cos = new Float64Array(period);
  for (let i = 0; i < period; i++) {
    const theta = (i / period) * 2 * Math.PI;
    sin[i] = Math.sin(theta);
    cos[i] = Math.cos(theta);
  }
  return { sin, cos };
}

function circularMean(sinSum, cosSum, period) {
  const theta = Math.atan2(sinSum, cosSum);
  return ((theta / (2 * Math.PI)) * period + period) % period;
}

export function createPalette(entries) {
  const colors = [...new Set(entries.map((e) => e.color))];
  const index = new Map(colors.map((color, i) => [color, i]));
  return { colors, toCells: (grid) => Int32Array.from(grid, (color) => index.get(color)) };
}

export function computeColorWeights(colors) {
  const n = colors.length;
  const weights = new Float64Array(n * n);
  for (let a = 0; a < n; a++) {
    for (let b = 0; b < n; b++) {
      if (a !== b) weights[a * n + b] = 1 / (1 + colorDistance(colors[a], colors[b]) / 15);
    }
  }
  return weights;
}

function wrapDelta(d, period) {
  if (d > period / 2) return d - period;
  if (d < -period / 2) return d + period;
  return d;
}

export function computeCenters(cells, cols, numColors, colorWeights) {
  const rows = cells.length / cols;
  const rowAngles = angleTable(rows);
  const colAngles = angleTable(cols);
  const rowSin = new Float64Array(numColors);
  const rowCos = new Float64Array(numColors);
  const colSin = new Float64Array(numColors);
  const colCos = new Float64Array(numColors);
  const present = new Uint8Array(numColors);
  for (let i = 0; i < cells.length; i++) {
    const color = cells[i];
    const r = Math.floor(i / cols);
    const c = i % cols;
    present[color] = 1;
    rowSin[color] += rowAngles.sin[r];
    rowCos[color] += rowAngles.cos[r];
    colSin[color] += colAngles.sin[c];
    colCos[color] += colAngles.cos[c];
  }

  // Raw centers of mass using circular mean (torus-aware)
  const rawR = new Float64Array(numColors);
  const rawC = new Float64Array(numColors);
  for (let color = 0; color < numColors; color++) {
    if (!present[color]) continue;
    rawR[color] = circularMean(rowSin[color], rowCos[color], rows);
    rawC[color] = circularMean(colSin[color], colCos[color], cols);
  }

  // Blended centers: pulled toward similar colors
  const blendedR = new Float64Array(numColors);
  const blendedC = new Float64Array(numColors);
  for (let color = 0; color < numColors; color++) {
    if (!present[color]) continue;
    let pullR = 0;
    let pullC = 0;
    let totalWeight = 0;
    for (let other = 0; other < numColors; other++) {
      if (other === color || !present[other]) continue;
      const weight = colorWeights[color * numColors + other];
      pullR += wrapDelta(rawR[other] - rawR[color], rows) * weight;
      pullC += wrapDelta(rawC[other] - rawC[color], cols) * weight;
      totalWeight += weight;
    }
    if (totalWeight > 0) {
      blendedR[color] =
        (((rawR[color] + (pullR / totalWeight) * SIMILARITY_BLEND) % rows) + rows) % rows;
      blendedC[color] =
        (((rawC[color] + (pullC / totalWeight) * SIMILARITY_BLEND) % cols) + cols) % cols;
    } else {
      blendedR[color] = rawR[color];
      blendedC[color] = rawC[color];
    }
  }

  return { rawR, rawC, blendedR, blendedC };
}

const SPEED_OPTIONS = [
  { value: "slow", label: "Slow", fps: 15, multiplier: 1 },
  { value: "medium", label: "Medium", fps: 30, multiplier: 3 },
  { value: "fast", label: "Fast", fps: 30, multiplier: 6 }
];

const MAX_ATTEMPTS_PER_SWAP = 300;
const CONVERGED_SWAP_RATIO = 1 / 3;

export function simulationTick(cells, inkInfo, cols, rows, centers, multiplier) {
  const { rawR, rawC, blendedR, blendedC } = centers;
  const totalPixels = cells.length;
  const targetSwaps = Math.floor(totalPixels * 0.005 * multiplier);
  const maxAttempts = targetSwaps * MAX_ATTEMPTS_PER_SWAP;
  let attempts = 0;
  let successes = 0;

  while (successes < targetSwaps && attempts < maxAttempts) {
    attempts++;
    const a = Math.floor(Math.random() * totalPixels);

    const colorA = cells[a];
    const rowA = Math.floor(a / cols);
    const colA = a % cols;

    // Random swap partner within local radius — prevents teleporting noise
    const offsetR = Math.floor(Math.random() * (SWAP_RADIUS * 2 + 1)) - SWAP_RADIUS;
    const offsetC = Math.floor(Math.random() * (SWAP_RADIUS * 2 + 1)) - SWAP_RADIUS;
    const bRow = (((rowA + offsetR) % rows) + rows) % rows;
    const bCol = (((colA + offsetC) % cols) + cols) % cols;
    const b = bRow * cols + bCol;

    if (a === b || colorA === cells[b]) continue;

    const colorB = cells[b];
    const rowB = Math.floor(b / cols);
    const colB = b % cols;

    const happyA = countSameNeighbors(cells, a, cols, rows);
    const happyB = countSameNeighbors(cells, b, cols, rows);

    // Compactness: does swap move pixels closer to their own raw center?
    const compactA =
      toroidalDist(rowA, colA, rawR[colorA], rawC[colorA], rows, cols) -
      toroidalDist(rowB, colB, rawR[colorA], rawC[colorA], rows, cols);
    const compactB =
      toroidalDist(rowB, colB, rawR[colorB], rawC[colorB], rows, cols) -
      toroidalDist(rowA, colA, rawR[colorB], rawC[colorB], rows, cols);

    // Drift: does swap move pixels closer to their blended center?
    const driftA =
      toroidalDist(rowA, colA, blendedR[colorA], blendedC[colorA], rows, cols) -
      toroidalDist(rowB, colB, blendedR[colorA], blendedC[colorA], rows, cols);
    const driftB =
      toroidalDist(rowB, colB, blendedR[colorB], blendedC[colorB], rows, cols) -
      toroidalDist(rowA, colA, blendedR[colorB], blendedC[colorB], rows, cols);

    const centerPull = (compactA + compactB) * 0.5 + (driftA + driftB) * 4.5;

    swap(cells, a, b);
    const newHappyA = countSameNeighbors(cells, a, cols, rows);
    const newHappyB = countSameNeighbors(cells, b, cols, rows);

    const localImprovement = (newHappyA + newHappyB - happyA - happyB) * 0.8;
    // Combined score: local happiness + strong drift
    const score = localImprovement + centerPull;

    let doSwap;
    if (score > 0) {
      doSwap = true;
    } else if (score > -0.5) {
      doSwap = Math.random() < 0.005;
    } else {
      doSwap = false;
    }

    if (doSwap) {
      swap(inkInfo, a, b);
      successes++;
    } else {
      swap(cells, a, b);
    }
  }

  return { converged: successes < targetSwaps * CONVERGED_SWAP_RATIO };
}

export function gaussianKernel(radius) {
  const sigma = radius / 2;
  const size = radius * 2 + 1;
  const kernel = new Float32Array(size);
  let sum = 0;
  for (let i = 0; i < size; i++) {
    const x = i - radius;
    kernel[i] = Math.exp(-(x * x) / (2 * sigma * sigma));
    sum += kernel[i];
  }
  for (let i = 0; i < size; i++) kernel[i] /= sum;
  return kernel;
}

// Paints each output pixel with the color whose Gaussian-blurred presence is strongest
// there. Blur and bilinear upsampling only read the cells around a pixel, so a frame
// only recomputes what is near the cells that changed, whatever the number of inks.
export function createVoronoiRenderer(colors, cols, rows, scale, kernel) {
  const colorRgb = colors.map((hex) => convert.hex.rgb(hex));
  const radius = (kernel.length - 1) / 2;
  const taps = kernel.length * kernel.length;
  const totalCells = cols * rows;
  const renderW = cols * scale;
  const renderH = rows * scale;
  const gridIdx = new Int32Array(totalCells).fill(-1);
  const cellColors = new Int32Array(totalCells * taps);
  const cellWeights = new Float64Array(totalCells * taps);
  const cellCounts = new Uint8Array(totalCells);
  const acc = new Float64Array(colors.length);
  const touched = new Int32Array(taps * 4);
  const staleCells = createWorkList(totalCells);
  const staleBlocks = createWorkList(totalCells);

  function wrap(row, col) {
    return ((row + rows) % rows) * cols + ((col + cols) % cols);
  }

  function blurCell(cell) {
    const row = Math.floor(cell / cols);
    const col = cell % cols;
    let n = 0;
    for (let i = -radius; i <= radius; i++) {
      const ki = kernel[i + radius];
      for (let j = -radius; j <= radius; j++) {
        const c = gridIdx[wrap(row + i, col + j)];
        if (acc[c] === 0) touched[n++] = c;
        acc[c] += ki * kernel[j + radius];
      }
    }
    const base = cell * taps;
    for (let t = 0; t < n; t++) {
      const c = touched[t];
      cellColors[base + t] = c;
      cellWeights[base + t] = acc[c];
      acc[c] = 0;
    }
    cellCounts[cell] = n;
  }

  function addCell(cell, weight, n) {
    const base = cell * taps;
    const count = cellCounts[cell];
    for (let t = 0; t < count; t++) {
      const c = cellColors[base + t];
      if (acc[c] === 0) touched[n++] = c;
      acc[c] += cellWeights[base + t] * weight;
    }
    return n;
  }

  function paintBlock(block, data) {
    const y0 = Math.floor(block / cols);
    const x0 = block % cols;
    const c00 = block;
    const c01 = wrap(y0, x0 + 1);
    const c10 = wrap(y0 + 1, x0);
    const c11 = wrap(y0 + 1, x0 + 1);
    for (let sy = 0; sy < scale; sy++) {
      const fy = sy / scale;
      for (let sx = 0; sx < scale; sx++) {
        const fx = sx / scale;
        let n = addCell(c00, (1 - fx) * (1 - fy), 0);
        if (fx > 0) n = addCell(c01, fx * (1 - fy), n);
        if (fy > 0) n = addCell(c10, (1 - fx) * fy, n);
        if (fx > 0 && fy > 0) n = addCell(c11, fx * fy, n);
        let maxVal = -1;
        let maxIdx = 0;
        for (let t = 0; t < n; t++) {
          const c = touched[t];
          if (acc[c] > maxVal || (acc[c] === maxVal && c < maxIdx)) {
            maxVal = acc[c];
            maxIdx = c;
          }
          acc[c] = 0;
        }
        const rgb = colorRgb[maxIdx];
        const off = ((y0 * scale + sy) * renderW + x0 * scale + sx) * 4;
        data[off] = rgb[0];
        data[off + 1] = rgb[1];
        data[off + 2] = rgb[2];
        data[off + 3] = 255;
      }
    }
  }

  function render(cells, data) {
    for (let cell = 0; cell < totalCells; cell++) {
      const c = cells[cell];
      if (c === gridIdx[cell]) continue;
      gridIdx[cell] = c;
      const row = Math.floor(cell / cols);
      const col = cell % cols;
      for (let i = -radius; i <= radius; i++) {
        for (let j = -radius; j <= radius; j++) staleCells.add(wrap(row + i, col + j));
      }
    }
    for (let t = 0; t < staleCells.size; t++) {
      const cell = staleCells.items[t];
      blurCell(cell);
      const row = Math.floor(cell / cols);
      const col = cell % cols;
      staleBlocks.add(cell);
      staleBlocks.add(wrap(row - 1, col));
      staleBlocks.add(wrap(row, col - 1));
      staleBlocks.add(wrap(row - 1, col - 1));
    }
    for (let t = 0; t < staleBlocks.size; t++) paintBlock(staleBlocks.items[t], data);
    const changed = staleBlocks.size > 0;
    staleCells.clear();
    staleBlocks.clear();
    return changed;
  }

  return { render, width: renderW, height: renderH };
}

function createWorkList(capacity) {
  const seen = new Uint8Array(capacity);
  const list = {
    items: new Int32Array(capacity),
    size: 0,
    add(i) {
      if (seen[i]) return;
      seen[i] = 1;
      list.items[list.size++] = i;
    },
    clear() {
      for (let t = 0; t < list.size; t++) seen[list.items[t]] = 0;
      list.size = 0;
    }
  };
  return list;
}

function renderHighlight(mainCtx, canvasSize, lockedInk, inkInfo, cols, rows, renderScale) {
  if (!lockedInk) return;

  const matchFn =
    lockedInk.inkId != null
      ? (i) => inkInfo[i].inkId === lockedInk.inkId
      : (i) => inkInfo[i].name === lockedInk.name;

  const cellW = canvasSize / cols;
  const cellH = canvasSize / rows;

  mainCtx.save();
  mainCtx.strokeStyle = "rgba(255, 255, 255, 0.9)";
  mainCtx.lineWidth = Math.max(1, renderScale);
  for (let i = 0; i < cols * rows; i++) {
    if (!matchFn(i)) continue;
    const col = i % cols;
    const row = Math.floor(i / cols);
    const x = col * cellW;
    const y = row * cellH;
    if (col === 0 || !matchFn(i - 1)) {
      mainCtx.beginPath();
      mainCtx.moveTo(x, y);
      mainCtx.lineTo(x, y + cellH);
      mainCtx.stroke();
    }
    if (col === cols - 1 || !matchFn(i + 1)) {
      mainCtx.beginPath();
      mainCtx.moveTo(x + cellW, y);
      mainCtx.lineTo(x + cellW, y + cellH);
      mainCtx.stroke();
    }
    if (row === 0 || !matchFn(i - cols)) {
      mainCtx.beginPath();
      mainCtx.moveTo(x, y);
      mainCtx.lineTo(x + cellW, y);
      mainCtx.stroke();
    }
    if (row === rows - 1 || !matchFn(i + cols)) {
      mainCtx.beginPath();
      mainCtx.moveTo(x, y + cellH);
      mainCtx.lineTo(x + cellW, y + cellH);
      mainCtx.stroke();
    }
  }
  mainCtx.restore();
}

const UsageVisualizationWidgetContent = ({ range, setRange, speed, setSpeed }) => {
  const { data } = useContext(WidgetDataContext);
  const entries = data.attributes.entries;
  const source = data.attributes.source;
  const canvasRef = useRef(null);
  const inkInfoRef = useRef(null);
  const runningRef = useRef(true);
  const visibleRef = useRef(false);
  const speedRef = useRef(speed);
  const animIdRef = useRef(null);
  const resumeRef = useRef(null);
  const redrawRef = useRef(null);
  const lockedInkRef = useRef("");
  const lastTouchRef = useRef(0);
  const hasEntries = entries.length > 0;
  const [running, setRunning] = useState(true);
  const [restartKey, setRestartKey] = useState(0);

  // Restart simulation when new data loads (e.g. range change)
  const [prevEntries, setPrevEntries] = useState(entries);
  if (entries !== prevEntries) {
    setPrevEntries(entries);
    if (hasEntries) setRunning(true);
  }

  useEffect(() => {
    runningRef.current = running;
  }, [running]);

  useEffect(() => {
    speedRef.current = speed;
  }, [speed]);

  // Restart animation loop when running changes to true
  useEffect(() => {
    if (running) resumeRef.current?.();
  }, [running]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        visibleRef.current = entry.isIntersecting;
        if (entry.isIntersecting) resumeRef.current?.();
      },
      { threshold: 0 }
    );
    observer.observe(canvas);
    return () => observer.disconnect();
  }, [hasEntries]);

  useEffect(() => {
    if (!hasEntries) return;

    const cols = GRID_SIZE;
    const rows = GRID_SIZE;
    const canvasSize = GRID_SIZE * RENDER_SCALE;
    const canvas = canvasRef.current;
    if (!canvas) return;

    canvas.width = canvasSize;
    canvas.height = canvasSize;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    runningRef.current = true;

    const { grid, inkInfo } = buildGrid(entries, cols, rows);
    inkInfoRef.current = inkInfo;
    const palette = createPalette(entries);
    const numColors = palette.colors.length;
    const cells = palette.toCells(grid);
    const colorWeights = computeColorWeights(palette.colors);

    const renderer = createVoronoiRenderer(
      palette.colors,
      cols,
      rows,
      RENDER_SCALE,
      gaussianKernel(BLUR_RADIUS)
    );
    const imageData = ctx.createImageData(renderer.width, renderer.height);

    function redraw() {
      ctx.putImageData(imageData, 0, 0);
      renderHighlight(ctx, canvasSize, lockedInkRef.current, inkInfo, cols, rows, RENDER_SCALE);
    }

    redrawRef.current = redraw;
    renderer.render(cells, imageData.data);
    redraw();

    let lastFrame = performance.now();
    let autoStopped = false;

    function animate(now) {
      if (!runningRef.current || !visibleRef.current) {
        animIdRef.current = null;
        return;
      }

      const currentSpeed = SPEED_OPTIONS.find((o) => o.value === speedRef.current);
      const frameInterval = 1000 / (currentSpeed ? currentSpeed.fps : 30);

      if (now - lastFrame >= frameInterval) {
        lastFrame = now;
        const { converged } = simulationTick(
          cells,
          inkInfo,
          cols,
          rows,
          computeCenters(cells, cols, numColors, colorWeights),
          currentSpeed ? currentSpeed.multiplier : 3
        );
        if (renderer.render(cells, imageData.data)) redraw();
        // Auto-stop once when converged
        if (!autoStopped && converged) {
          autoStopped = true;
          runningRef.current = false;
          setRunning(false);
        }
      }

      animIdRef.current = requestAnimationFrame(animate);
    }

    resumeRef.current = () => {
      if (!animIdRef.current && runningRef.current && visibleRef.current) {
        lastFrame = performance.now();
        animIdRef.current = requestAnimationFrame(animate);
      }
    };

    animIdRef.current = requestAnimationFrame(animate);

    return () => {
      resumeRef.current = null;
      redrawRef.current = null;
      if (animIdRef.current) cancelAnimationFrame(animIdRef.current);
    };
  }, [entries, hasEntries, restartKey]);

  const [hoveredInk, setHoveredInk] = useState(null);
  const [lockedInk, setLockedInk] = useState(null);

  useEffect(() => {
    lockedInkRef.current = lockedInk;
    if (redrawRef.current) redrawRef.current();
  }, [lockedInk]);

  const getInkAtPoint = useCallback((clientX, clientY) => {
    const canvas = canvasRef.current;
    const inkInfo = inkInfoRef.current;
    if (!canvas || !inkInfo) return null;

    const rect = canvas.getBoundingClientRect();
    const col = Math.floor(((clientX - rect.left) * GRID_SIZE) / rect.width);
    const row = Math.floor(((clientY - rect.top) * GRID_SIZE) / rect.height);

    if (col >= 0 && col < GRID_SIZE && row >= 0 && row < GRID_SIZE) {
      return inkInfo[row * GRID_SIZE + col] || null;
    }
    return null;
  }, []);

  const handleMouseMove = useCallback(
    (e) => {
      if (Date.now() - lastTouchRef.current < 500) return;
      if (!lockedInkRef.current) {
        const ink = getInkAtPoint(e.clientX, e.clientY);
        setHoveredInk(ink || null);
      }
    },
    [getInkAtPoint]
  );

  const toggleLock = useCallback(
    (clientX, clientY) => {
      const ink = getInkAtPoint(clientX, clientY);
      if (!ink) return;
      setLockedInk((prev) => {
        const isSame =
          prev && prev.inkId != null ? prev.inkId === ink.inkId : prev?.name === ink.name;
        if (isSame) {
          lockedInkRef.current = null;
          return null;
        }
        runningRef.current = false;
        setRunning(false);
        lockedInkRef.current = ink;
        return ink;
      });
      setHoveredInk(ink);
    },
    [getInkAtPoint]
  );

  const handleClick = useCallback(
    (e) => {
      if (Date.now() - lastTouchRef.current < 500) return;
      toggleLock(e.clientX, e.clientY);
    },
    [toggleLock]
  );

  const handleTouchStart = useCallback(
    (e) => {
      e.preventDefault();
      lastTouchRef.current = Date.now();
      const touch = e.touches[0];
      if (touch) toggleLock(touch.clientX, touch.clientY);
    },
    [toggleLock]
  );

  const displayedInk = lockedInk || hoveredInk || { name: "", inkId: null };

  return (
    <>
      <div className="d-flex align-items-center gap-2 mb-2">
        <RangePicker range={range} setRange={setRange} />
        {hasEntries && (
          <>
            <SpeedPicker speed={speed} setSpeed={setSpeed} />
            <button
              type="button"
              className="btn btn-outline-secondary btn-sm ms-auto"
              onClick={() => {
                setLockedInk(null);
                setHoveredInk(null);
                setRunning((r) => !r);
              }}
            >
              <i className={`fa fa-${running ? "stop" : "play"}`} />
            </button>
            <button
              type="button"
              className="btn btn-outline-secondary btn-sm"
              onClick={() => {
                setLockedInk(null);
                setHoveredInk(null);
                setRunning(true);
                runningRef.current = true;
                setRestartKey((k) => k + 1);
              }}
            >
              <i className="fa fa-refresh" />
            </button>
          </>
        )}
      </div>
      {source === "currently_inked" && (
        <p className="text-muted small mb-2">
          Based on currently inked pens (not enough usage records).
        </p>
      )}
      {hasEntries ? (
        <>
          <canvas
            ref={canvasRef}
            className="fpc-usage-visualization__canvas"
            onMouseMove={handleMouseMove}
            onMouseLeave={() => {
              if (!lockedInkRef.current) setHoveredInk(null);
            }}
            onClick={handleClick}
            onTouchStart={handleTouchStart}
          />
          <div className="fpc-usage-visualization__label">
            {displayedInk.name ? (
              <>
                <span className="fpc-usage-visualization__label-name">{displayedInk.name}</span>
                {displayedInk.inkId && (
                  <a href={`/inks/${displayedInk.inkId}`} target="_blank" rel="noreferrer">
                    <i className="fa fa-external-link" />
                  </a>
                )}
              </>
            ) : (
              "\u00A0"
            )}
          </div>
        </>
      ) : (
        <div className="fpc-usage-visualization__empty">
          Not enough usage data yet. Start logging daily usage on your currently inked pens to see
          this visualization.
        </div>
      )}
    </>
  );
};

const RangePicker = ({ range, setRange }) => (
  <select
    className="form-select form-select-sm"
    style={{ width: "auto" }}
    value={range}
    onChange={(e) => setRange(e.target.value)}
  >
    {RANGE_OPTIONS.map((option) => (
      <option key={option.value} value={option.value}>
        {option.label}
      </option>
    ))}
  </select>
);

const SpeedPicker = ({ speed, setSpeed }) => (
  <select
    className="form-select form-select-sm"
    style={{ width: "auto" }}
    value={speed}
    onChange={(e) => setSpeed(e.target.value)}
  >
    {SPEED_OPTIONS.map((option) => (
      <option key={option.value} value={option.value}>
        {option.label}
      </option>
    ))}
  </select>
);
