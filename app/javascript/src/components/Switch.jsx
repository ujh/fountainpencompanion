import React, { useId } from "react";

/**
 * @see https://getbootstrap.com/docs/5.3/forms/checks-radios/#switches
 * @param {{ checked: boolean; children: import("react").ReactNode; onChange: import("react").ChangeEventHandler<HTMLInputElement>; }} props
 */
export const Switch = ({ checked, children, onChange }) => {
  const id = useId();

  return (
    <div className="form-check form-switch">
      <input
        type="checkbox"
        role="switch"
        className="form-check-input"
        id={id}
        checked={checked}
        onChange={onChange}
      />
      <label className="form-check-label" htmlFor={id}>
        {children}
      </label>
    </div>
  );
};
