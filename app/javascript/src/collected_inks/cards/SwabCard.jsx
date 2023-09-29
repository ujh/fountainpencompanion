import React from "react";
import { RelativeDate } from "../../components/RelativeDate";
import { Card } from "../../components";
import { ArchiveButton, EditButton, DeleteButton } from "../components";
import "./swab-card.scss";

/**
 * @param {{
 *    hiddenFields: string[];
 *    archived: boolean;
 *    id: string;
 *    ink_id?: string;
 *    private?: boolean;
 *    brand_name: string;
 *    line_name?: string;
 *    ink_name: string;
 *    maker?: string;
 *    kind?: "bottle" | "sample" | "cartridge" | "swab";
 *    color?: string;
 *    swabbed?: boolean;
 *    used?: boolean;
 *    usage?: number;
 *    daily_usage?: number;
 *    last_used_on?: string;
 *    comment?: string;
 *    private_comment?: string;
 *    created_at?: string;
 *    tags?: Array<{ id: string; name: string }>;
 * }} props
 */
export const SwabCard = (props) => {
  const {
    archived,
    id,
    ink_id,
    private: isPrivate = false,
    maker,
    kind,
    color,
    usage = 0,
    daily_usage = 0,
    comment,
    private_comment,
    tags,
    last_used_on,
    created_at,
    hiddenFields
  } = props;

  const fullName = ["brand_name", "line_name", "ink_name"]
    .map((a) => props[a])
    .join(" ");

  const isVisible = (field) => props[field] && !hiddenFields.includes(field);
  const hasUsage =
    isVisible("usage") || isVisible("daily_usage") || isVisible("last_used_on");

  return (
    <Card className="fpc-swab-card">
      {color ? (
        <Card.Image
          className="fpc-swab-card__swab"
          style={{ "--swab-color": color }}
        />
      ) : null}
      <Card.Body>
        <Card.Title>
          {fullName}
          {ink_id ? (
            <>
              &nbsp;
              <a href={`/inks/${ink_id}`}>
                <i className="fa fa-external-link" />
              </a>
            </>
          ) : null}
        </Card.Title>
        {isVisible("comment") ? <Card.Text>{comment}</Card.Text> : null}
        {isVisible("private_comment") ? (
          <>
            <div className="small text-secondary">Private comment</div>
            <Card.Text>{private_comment}</Card.Text>
          </>
        ) : null}
        {isVisible("maker") ? (
          <>
            <div className="small text-secondary">Maker</div>
            <Card.Text>{maker}</Card.Text>
          </>
        ) : null}
        {hasUsage ? (
          <>
            <div className="small text-secondary">Usage</div>
            <Card.Text data-testid="usage">
              {String(usage)} inked -{" "}
              <LastUsageDisplay last_used_on={last_used_on} /> (
              {String(daily_usage)} daily usages)
            </Card.Text>
          </>
        ) : null}
        {isVisible("created_at") ? (
          <>
            <div className="small text-secondary">Added On</div>
            <Card.Text>
              {<RelativeDate date={created_at} relativeAsDefault={false} />}
            </Card.Text>
          </>
        ) : null}
        <div className="fpc-swab-card__footer">
          <div className="fpc-swab-card__badges">
            {isPrivate ? (
              <span className="badge text-bg-info">Private</span>
            ) : null}
            {isVisible("swabbed") ? (
              <span className="badge text-bg-success">Swabbed</span>
            ) : null}
            {isVisible("used") ? (
              <span className="badge text-bg-success">Used</span>
            ) : null}
            {isVisible("kind") ? (
              <span className="badge text-bg-secondary">{kind}</span>
            ) : null}
            {isVisible("tags") && Array.isArray(tags)
              ? tags.map(({ id, name }) => (
                  <span
                    key={`ink-tag-${id}`}
                    className="tag badge text-bg-secondary"
                  >
                    {name}
                  </span>
                ))
              : null}
          </div>
          <div className="fpc-swab-card__actions">
            <EditButton
              className="me-2"
              name={fullName}
              id={id}
              archived={archived}
            />
            <ArchiveButton
              className="me-2"
              name={fullName}
              id={id}
              archived={archived}
            />
            <DeleteButton name={fullName} id={id} archived={archived} />
          </div>
        </div>
      </Card.Body>
    </Card>
  );
};

const LastUsageDisplay = ({ last_used_on }) => {
  if (last_used_on) {
    return (
      <>
        last used <RelativeDate date={last_used_on} />
      </>
    );
  } else {
    return <>never used</>;
  }
};
