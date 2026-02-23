import React from "react";

/**
 * @param {{ value?: string; row: { original: { ink_id?: string } } }} props
 */
export const InkWithLink = ({ value, row }) => {
  const ink_id = row?.original?.ink_id;

  if (ink_id) {
    return (
      <>
        {value}
        <a href={`/inks/${ink_id}`}>
          &nbsp;
          <i className="fa fa-external-link" />
        </a>
      </>
    );
  }
  return <>{value}</>;
};
