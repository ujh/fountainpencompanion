import React, { useState, useMemo } from "react";
import { computeAverageColor } from "./color-utils";

export function App({
  colors,
  ignoredColors: initialIgnored,
  submitUrl,
  cancelUrl,
  currentColor,
  csrfToken
}) {
  const [ignoredSet, setIgnoredSet] = useState(() => new Set(initialIgnored));

  const allIgnoredColors = useMemo(() => {
    return [...new Set([...initialIgnored, ...ignoredSet])];
  }, [initialIgnored, ignoredSet]);

  // Stale colors: in ignored list but not in current collected ink colors
  const staleColors = useMemo(() => {
    return allIgnoredColors.filter((c) => !colors.includes(c));
  }, [allIgnoredColors, colors]);

  const keptColors = colors.filter((c) => !ignoredSet.has(c));
  const activeIgnoredColors = colors.filter((c) => ignoredSet.has(c));

  const previewColor = useMemo(() => computeAverageColor(keptColors), [keptColors]);

  const isLastKeptColor = keptColors.length === 1;

  const toggleColor = (color) => {
    // Prevent ignoring the last kept color
    if (!ignoredSet.has(color) && isLastKeptColor) return;

    setIgnoredSet((prev) => {
      const next = new Set(prev);
      if (next.has(color)) {
        next.delete(color);
      } else {
        next.add(color);
      }
      return next;
    });
  };

  const allIgnored = [...ignoredSet, ...staleColors.filter((c) => !ignoredSet.has(c))];

  return (
    <div>
      <div className="fpc-edit-colors__section">
        <h3 className="h4">Colors to keep</h3>
        <div className="fpc-edit-colors__grid">
          {keptColors.map((c) => (
            <div
              key={c}
              className={`fpc-edit-colors__tile${isLastKeptColor ? " fpc-edit-colors__tile--disabled" : " fpc-edit-colors__tile--clickable"}`}
              style={{ backgroundColor: c }}
              onClick={() => toggleColor(c)}
              title={isLastKeptColor ? `${c} (cannot ignore last color)` : `Click to ignore ${c}`}
            />
          ))}
          {keptColors.length === 0 && <p className="text-muted">No colors kept</p>}
        </div>
      </div>

      <div className="fpc-edit-colors__section">
        <h3 className="h4">Colors to ignore</h3>
        <div className="fpc-edit-colors__grid">
          {activeIgnoredColors.map((c) => (
            <div
              key={c}
              className="fpc-edit-colors__tile fpc-edit-colors__tile--clickable"
              style={{ backgroundColor: c }}
              onClick={() => toggleColor(c)}
              title={`Click to keep ${c}`}
            />
          ))}
          {staleColors.map((c) => (
            <div
              key={c}
              className="fpc-edit-colors__tile fpc-edit-colors__tile--stale"
              style={{ backgroundColor: c }}
              title={`${c} (no longer in collected inks)`}
            />
          ))}
          {activeIgnoredColors.length === 0 && staleColors.length === 0 && (
            <p className="text-muted">No colors ignored</p>
          )}
        </div>
      </div>

      <div className="fpc-edit-colors__preview">
        <h3 className="h4">Color preview</h3>
        <div className="fpc-edit-colors__preview-row">
          {currentColor && (
            <div className="fpc-edit-colors__preview-item">
              <div
                className="fpc-edit-colors__preview-swatch"
                style={{ backgroundColor: currentColor }}
              />
              <span className="small text-muted">Current</span>
            </div>
          )}
          {previewColor && (
            <div className="fpc-edit-colors__preview-item">
              <div
                className="fpc-edit-colors__preview-swatch"
                style={{ backgroundColor: previewColor }}
              />
              <span className="small text-muted">New</span>
            </div>
          )}
          {!previewColor && (
            <div className="fpc-edit-colors__preview-item">
              <span className="small text-muted">No colors to average</span>
            </div>
          )}
        </div>
      </div>

      <form action={submitUrl} method="post">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        {allIgnored.map((c) => (
          <input key={c} type="hidden" name="macro_cluster[ignored_colors][]" value={c} />
        ))}
        {allIgnored.length === 0 && (
          <input type="hidden" name="macro_cluster[ignored_colors][]" value="" />
        )}
        <button type="submit" className="btn btn-success">
          Save
        </button>{" "}
        <a href={cancelUrl} className="btn btn-secondary">
          Cancel
        </a>
      </form>
    </div>
  );
}
