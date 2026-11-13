import { useWithListState } from "../../listState";

/**
 * @param {{ name: string; id: string; archived: boolean }} props
 */
export const DeleteButton = ({ name, id, archived }) => {
  const withListState = useWithListState();
  if (archived) {
    return (
      <span>
        <a
          className="btn btn-danger"
          title={`Delete ${name}`}
          href={withListState(`/collected_inks/${id}`)}
          data-method="delete"
          data-confirm="Really delete entry?"
        >
          <i className="fa fa-trash" />
        </a>
      </span>
    );
  } else {
    return null;
  }
};
