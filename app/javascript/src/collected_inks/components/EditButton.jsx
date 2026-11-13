import { useWithListState } from "../../listState";

/**
 * @param {{ name: string; id: string; archived: boolean }} props
 */
export const EditButton = ({ className, name, id, archived }) => {
  const withListState = useWithListState();
  let href = `/collected_inks/${id}/edit`;
  if (archived) href += "?search[archive]=true";
  return (
    <span className={className}>
      <a className="btn btn-secondary" href={withListState(href)} title={`Edit ${name}`}>
        <i className="fa fa-pencil" />
      </a>
    </span>
  );
};
