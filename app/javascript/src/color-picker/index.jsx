import React, { useState, useEffect } from "react";
import ReactDOM from "react-dom";
import { ChromePicker } from "react-color";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.getElementsByClassName("color-picker");
  Array.from(elements).forEach(el => {
    const input = document.getElementById(el.getAttribute("data-input"));
    ReactDOM.render(<ColorPicker input={input} />, el);
  });
});

const ColorPicker = ({ input }) => {
  const [color, setColor] = useState(input.value);
  useEffect(() => {
    const listener = event => {
      setColor(event.target.value);
    };
    input.addEventListener("change", listener);
    return () => {
      input.removeEventListener(listener);
    };
  }, [input]);
  return (
    <div>
      <ChromePicker
        color={color}
        disableAlpha={true}
        onChange={color => {
          input.value = color.hex;
          setColor(color.hex);
        }}
      />
    </div>
  );
};
