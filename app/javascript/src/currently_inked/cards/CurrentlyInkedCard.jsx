import React from "react";
import { Card } from "../../components/Card";
import { UsageButton } from "../components/UsageButton";
import { RelativeDate } from "../../components/RelativeDate";
import "./currently-inked-card.scss";

/**
 * @param {{
 *   hiddenFields: string[];
 *   id: string;
 *   archived: boolean;
 *   archived_on?: string | null;
 *   comment?: string;
 *   daily_usage?: number;
 *   ink_name: string;
 *   ink_color?: string;
 *   inked_on: string;
 *   last_used_on?: string | null;
 *   pen_name: string;
 *   refillable: boolean;
 *   unarchivable?: boolean;
 *   used_today: boolean;
 *   collected_ink: {
 *      archived?: boolean;
 *      brand_name?: string;
 *      color: string;
 *      id: string;
 *      ink_name?: string;
 *      line_name?: string;
 *   };
 *   collected_pen: {
 *      archived?: boolean;
 *      brand?: string;
 *      color?: string;
 *      id: string;
 *      model?: string;
 *      nib?: string;
 *   };
 * }} props
 */
export const CurrentlyInkedCard = (props) => {
  const {
    hiddenFields,
    id,
    comment,
    ink_name,
    inked_on,
    last_used_on,
    daily_usage,
    pen_name,
    refillable,
    used_today,
    collected_ink: {
      color,
      micro_cluster: { macro_cluster }
    },
    collected_pen: { model_variant_id }
  } = props;

  const isVisible = (field) => props[field] && !hiddenFields.includes(field);

  return (
    <Card className="fpc-currently-inked-card">
      <Card.Image className="fpc-currently-inked-card__swab" style={{ "--swab-color": color }} />
      <Card.Body>
        <Card.Title>
          {ink_name}
          {macro_cluster && (
            <>
              {" "}
              <a href={`/inks/${macro_cluster.id}`}>
                <i className="fa fa-external-link"></i>
              </a>
            </>
          )}
        </Card.Title>
        {isVisible("comment") ? <Card.Text>{comment}</Card.Text> : null}
        {isVisible("pen_name") ? (
          <>
            <div className="small text-secondary">Pen</div>
            <Card.Text>
              {pen_name}
              {model_variant_id && (
                <>
                  {" "}
                  <a href={`/pen_variants/${model_variant_id}`}>
                    <i className="fa fa-external-link"></i>
                  </a>
                </>
              )}
            </Card.Text>
          </>
        ) : null}
        {isVisible("inked_on") ? (
          <>
            <div className="small text-secondary">Inked</div>
            <Card.Text>
              <RelativeDate date={inked_on} relativeAsDefault={false} />
            </Card.Text>
          </>
        ) : null}
        {isVisible("last_used_on") ? (
          <>
            <div className="small text-secondary">Last used</div>
            <Card.Text>
              <RelativeDate date={last_used_on} />
            </Card.Text>
          </>
        ) : null}
        {isVisible("daily_usage") ? (
          <>
            <div className="small text-secondary">Usage</div>
            <Card.Text>{daily_usage}</Card.Text>
          </>
        ) : null}
        <div className="fpc-currently-inked-card__footer">
          <div className="fpc-currently-inked-card__actions">
            <UsageButton id={id} used={used_today} />
            {refillable && (
              <a
                className="btn btn-secondary ms-2"
                title="Refill this pen"
                href={`/currently_inked/${id}/refill`}
                data-method="post"
                data-confirm={`Really refill ${ink_name}?`}
              >
                <i className="fa fa-rotate-right"></i>
              </a>
            )}
            <a
              className="btn btn-secondary  ms-2"
              title="edit"
              href={`/currently_inked/${id}/edit`}
            >
              <i className="fa fa-pencil" />
            </a>
            <a
              className="btn btn-secondary ms-2"
              title="archive"
              href={`/currently_inked/${id}/archive`}
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
