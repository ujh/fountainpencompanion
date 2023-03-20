import React from "react";
import { Card } from "../../components/Card";
import "./pen-card.scss";

/**
 * @param {{
 *   hiddenFields: string[];
 *   id: string;
 *   brand: string;
 *   model: string;
 *   nib?: string;
 *   color?: string;
 *   comment?: string;
 *   usage?: number;
 *   daily_usage?: number;
 *   last_inked?: string | null;
 *   last_cleaned?: string | null;
 *   last_used_on?: string | null;
 * }} props
 */
export const PenCard = (props) => {
  const {
    hiddenFields,
    id,
    brand,
    model,
    nib,
    color,
    comment,
    usage,
    daily_usage
  } = props;

  const fullName = `${brand} ${model}`;
  const isVisible = (field) => props[field] && !hiddenFields.includes(field);
  const hasUsage = isVisible("usage") || isVisible("daily_usage");

  return (
    <Card className="fpc-pen-card">
      <Card.Body>
        <Card.Title>{fullName}</Card.Title>
        {isVisible("comment") ? <Card.Text>{comment}</Card.Text> : null}
        {isVisible("color") ? (
          <>
            <div className="small text-secondary">Color</div>
            <Card.Text>{color}</Card.Text>
          </>
        ) : null}
        {isVisible("nib") ? (
          <>
            <div className="small text-secondary">Nib</div>
            <Card.Text>{nib}</Card.Text>
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
        <div className="fpc-pen-card__footer">
          <div className="fpc-pen-card__actions">
            <a
              className="btn btn-secondary me-2"
              title="edit"
              href={`/collected_pens/${id}/edit`}
            >
              <i className="fa fa-pencil" />
            </a>
            <a
              className="btn btn-secondary"
              title="archive"
              href={`/collected_pens/${id}/archive`}
              data-method="post"
            >
              <i className="fa fa-archive" />
            </a>
          </div>
        </div>
      </Card.Body>
    </Card>
  );
};
