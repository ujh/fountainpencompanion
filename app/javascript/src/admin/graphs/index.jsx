import React from "react";
import { createRoot } from "react-dom/client";

import { SignUps } from "./SignUps";
import { CollectedInks } from "./CollectedInks";
import { CollectedPens } from "./CollectedPens";
import { CurrentlyInked } from "./CurrentlyInked";
import { UsageRecords } from "./UsageRecords";
import { BotSignUps } from "./BotSignUps";
import { Spam } from "./Spam";
import { UserAgents } from "./UserAgents";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("signups-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<SignUps />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("user-agents-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<UserAgents />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("bot-signups-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<BotSignUps />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("spam-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<Spam />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("collected-inks-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<CollectedInks />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("collected-pens-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<CollectedPens />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("currently-inked-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<CurrentlyInked />);
  }
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("usage-records-graph");
  if (el) {
    const root = createRoot(el);
    root.render(<UsageRecords />);
  }
});
