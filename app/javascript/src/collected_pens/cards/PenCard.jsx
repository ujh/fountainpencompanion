import React from "react";
import { Card } from "../../components/Card";
import "./pen-card.scss";
import { RelativeDate } from "../../components/RelativeDate";

/**
 * @param {{
 *   hiddenFields: string[];
 *   id: string;
 *   brand: string;
 *   model: string;
 *   nib?: string;
 *   color?: string;
 *   material?: string;
 *   trim_color?: string;
 *   filling_system?: string
 *   price?: string;
 *   comment?: string;
 *   usage?: number;
 *   daily_usage?: number;
 *   last_inked?: string | null;
 *   last_cleaned?: string | null;
 *   last_used_on?: string | null;
 *   created_at?: string;
 * }} props
 */
export const PenCard = (props) => {
  const {
    hiddenFields,
    id,
    brand,
    model,
    model_id,
    nib,
    color,
    material,
    trim_color,
    filling_system,
    price,
    comment,
    usage,
    daily_usage,
    last_used_on,
    created_at
  } = props;

  const fullName = `${brand} ${model}`;
  const isVisible = (field) => props[field] && !hiddenFields.includes(field);
  const hasUsage =
    isVisible("usage") || isVisible("daily_usage") || isVisible("last_used_on");

  return (
    <Card className="fpc-pen-card">
      <Card.Body>
        <Card.Title>
          {fullName}
          {model_id && (
            <>
              {" "}
              <a href={`/pen_models/${model_id}`}>
                <i className="fa fa-external-link"></i>
              </a>
            </>
          )}
        </Card.Title>
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
        {isVisible("material") ? (
          <>
            <div className="small text-secondary">Material</div>
            <Card.Text>{material}</Card.Text>
          </>
        ) : null}
        {isVisible("trim_color") ? (
          <>
            <div className="small text-secondary">Trim Color</div>
            <Card.Text>{trim_color}</Card.Text>
          </>
        ) : null}
        {isVisible("filling_system") ? (
          <>
            <div className="small text-secondary">Filling System</div>
            <Card.Text>{filling_system}</Card.Text>
          </>
        ) : null}
        {isVisible("price") ? (
          <>
            <div className="small text-secondary">Price</div>
            <Card.Text>{price}</Card.Text>
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
