import { useWithListState } from "../../listState";

export const ActionsCell = ({ id }) => {
  const withListState = useWithListState();
  return (
    <div className="actions">
      <a
        className="btn btn-secondary"
        title="edit"
        href={withListState(`/collected_pens/${id}/edit`)}
      >
        <i className="fa fa-pencil" />
      </a>
      <a
        className="btn btn-secondary"
        title="archive"
        href={withListState(`/collected_pens/${id}/archive`)}
        data-method="post"
      >
        <i className="fa fa-archive" />
      </a>
    </div>
  );
};
