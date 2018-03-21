import * as React from "react";

const ActionButtons = ({deletable, onArchiveClick, onDeleteClick}) => <span className="actions">
  <ArchiveButton onClick={onArchiveClick}/>
  <DeleteButton deletable={deletable} onClick={onDeleteClick}/>
</span>;

const ArchiveButton = ({onClick}) => <a className="btn btn-default" onClick={onClick}>
  <i className="fa fa-archive" />
</a>;

const DeleteButton = ({deletable, onClick}) => {
  if (!deletable) return null;
  return <a onClick={onClick} className="btn btn-default"><i className="fa fa-trash" /></a>;
}

export default ActionButtons;
