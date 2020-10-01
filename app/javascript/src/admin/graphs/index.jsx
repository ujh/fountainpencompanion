import React from "react";
import ReactDOM from "react-dom";

import { SignUps } from "./SignUps";
import { CollectedInks } from "./CollectedInks";
import { CollectedPens } from "./CollectedPens";
import { CurrentlyInked } from "./CurrentlyInked";
import { UsageRecords } from "./UsageRecords";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("signups-graph");
  if (el) ReactDOM.render(<SignUps />, el);
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("collected-inks-graph");
  if (el) ReactDOM.render(<CollectedInks />, el);
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("collected-pens-graph");
  if (el) ReactDOM.render(<CollectedPens />, el);
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("currently-inked-graph");
  if (el) ReactDOM.render(<CurrentlyInked />, el);
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("usage-records-graph");
  if (el) ReactDOM.render(<UsageRecords />, el);
});
