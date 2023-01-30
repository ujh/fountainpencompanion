import React from "react";
import { Card } from "../../components";
import { ArchiveButton, EditButton } from "../components";
import "./swab-card.scss";

/**
 * @param {{
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
 *    comment?: string;
 *    private_comment?: string;
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
    swabbed = false,
    used = false,
    usage = 0,
    daily_usage = 0,
    comment,
    private_comment,
    tags
  } = props;

  const fullName = ["brand_name", "line_name", "ink_name"]
    .map((a) => props[a])
    .join(" ");

  const hasUsage = usage || daily_usage;

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
        {comment ? <Card.Text>{comment}</Card.Text> : null}
        {private_comment ? (
          <>
            <div className="small text-secondary">Private comment</div>
            <Card.Text>{private_comment}</Card.Text>
          </>
        ) : null}
        {maker ? (
          <>
            <div className="small text-secondary">Maker</div>
            <Card.Text>{maker}</Card.Text>
          </>
        ) : null}
        {hasUsage ? (
          <>
            <div className="small text-secondary">Usage</div>
            <Card.Text>
              {String(usage)} inked ({String(daily_usage)} daily usages)
            </Card.Text>
          </>
        ) : null}
        <div className="fpc-swab-card__footer">
          <div className="fpc-swab-card__badges">
            {isPrivate ? (
              <span className="badge text-bg-info">Private</span>
            ) : null}
            {swabbed ? (
              <span className="badge text-bg-success">Swabbed</span>
            ) : null}
            {used ? <span className="badge text-bg-success">Used</span> : null}
            {kind ? (
              <span className="badge text-bg-secondary">{kind}</span>
            ) : null}
            {Array.isArray(tags)
              ? tags.map(({ id, name }) => (
                  <span
                    key={`ink-tag-${id}`}
                    className="badge text-bg-secondary"
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
            <ArchiveButton name={fullName} id={id} archived={archived} />
          </div>
        </div>
      </Card.Body>
    </Card>
  );
};
