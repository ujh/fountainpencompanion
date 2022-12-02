import React, { useState, useEffect } from "react";
import { createRoot } from "react-dom/client";
import { ChromePicker } from "react-color";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.getElementsByClassName("color-picker");
  Array.from(elements).forEach((el) => {
    const input = document.getElementById(el.getAttribute("data-input"));
    const root = createRoot(el);
    root.render(<ColorPicker input={input} />);
  });
});

const ColorPicker = ({ input }) => {
  const [color, setColor] = useState(input.value);
  useEffect(() => {
    const listener = (event) => {
      setColor(event.target.value);
    };
    input.addEventListener("change", listener);
    return () => {
      input.removeEventListener(listener);
    };
  }, [input]);
  return (
    <div className="row">
      <div className="col-xs-8 col-sm-7">
        <ChromePicker
          color={color}
          disableAlpha={true}
          onChange={(color) => {
            input.value = color.hex;
            setColor(color.hex);
          }}
        />
      </div>
      <div
        className="col-xs-4 col-sm-5"
        style={{ height: "225px", backgroundColor: color }}
      ></div>
    </div>
  );
};
