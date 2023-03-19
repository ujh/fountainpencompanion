import React from "react";
import { Card } from "./Card";

export const CardPlaceholder = () => (
  <Card>
    <div className="placeholder-glow">
      <Card.Body>
        <Card.Title>
          <span className="placeholder col-12" />
        </Card.Title>
        <Card.Text>
          <span className="placeholder col-12" />
          <span className="placeholder col-12" />
        </Card.Text>
        <div className="d-flex justify-content-between">
          <span className="placeholder col-4 bg-primary" />
          <span className="placeholder col-2 bg-secondary" />
        </div>
      </Card.Body>
    </div>
  </Card>
);
