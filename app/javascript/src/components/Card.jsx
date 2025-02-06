import React from "react";
import "./card.scss";

export const Card = ({ className = "", ...rest }) => (
  <div className={`card fpc-card ${className}`} {...rest} />
);

Card.Image = ({ className = "", ...rest }) => (
  <div className={`card-img-top ${className}`} {...rest} />
);
Card.Image.displayName = "Card.Image";

Card.Body = ({ className = "", ...rest }) => <div className={`card-body ${className}`} {...rest} />;
Card.Body.displayName = "Card.Body";

Card.Title = ({ className = "", ...rest }) => (
  <p className={`h5 card-title ${className}`} {...rest} />
);
Card.Title.displayName = "Card.Title";

Card.Text = ({ className = "", ...rest }) => <p className={`card-text ${className}`} {...rest} />;
Card.Text.displayName = "Card.Text";
