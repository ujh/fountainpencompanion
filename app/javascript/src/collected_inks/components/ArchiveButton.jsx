import { useWithListState } from "../../listState";

/**
 * @param {{ name: string; id: string; archived: boolean }} props
 */
export const ArchiveButton = ({ className, name, id, archived }) => {
  const withListState = useWithListState();
  if (archived) {
    return (
      <span className={className}>
        <a
          className="btn btn-secondary"
          title={`Unarchive ${name}`}
          href={withListState(`/collected_inks/${id}/unarchive`)}
          data-method="post"
        >
          <i className="fa fa-folder-open" />
        </a>
      </span>
    );
  } else {
    return (
      <span className={className}>
        <a
          className="btn btn-secondary"
          title={`Archive ${name}`}
          href={withListState(`/collected_inks/${id}/archive`)}
          data-method="post"
        >
          <i className="fa fa-archive" />
        </a>
      </span>
    );
  }
};
