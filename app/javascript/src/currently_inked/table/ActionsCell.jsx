import { useWithListState } from "../../listState";
import { UsageButton } from "../components/UsageButton";

export const ActionsCell = ({ id, refillable, ink_name, used_today, onUsageRecorded }) => {
  const withListState = useWithListState();
  return (
    <div className="actions">
      <UsageButton id={id} used={used_today} onUsageRecorded={onUsageRecorded} />
      {refillable && (
        <a
          className="btn btn-secondary"
          title="Refill this pen"
          href={withListState(`/currently_inked/${id}/refill`)}
          data-method="post"
          data-confirm={`Really refill ${ink_name}?`}
        >
          <i className="fa fa-rotate-right"></i>
        </a>
      )}
      <a
        className="btn btn-secondary"
        title="edit"
        href={withListState(`/currently_inked/${id}/edit`)}
      >
        <i className="fa fa-pencil" />
      </a>
      <a
        className="btn btn-secondary"
        title="archive"
        href={withListState(`/currently_inked/${id}/archive`)}
        data-method="post"
      >
        <i className="fa fa-archive" />
      </a>
    </div>
  );
};
