import React from "react";

/**
 * @param {{ value?: string; row: { original: { ink_id?: string; ink_name?: string } } }} props
 */
export const InkWithLink = ({ value, row }) => {
  const inkName = value || row?.original?.ink_name;
  const inkId = row?.original?.ink_id;

  if (inkId) {
    return (
      <>
        {inkName}
        <a href={`/inks/${inkId}`}>
          &nbsp;
          <i className="fa fa-external-link" />
        </a>
      </>
    );
  }
  return <>{inkName}</>;
};
