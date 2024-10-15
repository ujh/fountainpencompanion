import jstz from "jstz";
import { putRequest } from "./fetch";

export default function setTimeZone() {
  const tz = findTimeZone();
  putRequest("/account.json", { user: { time_zone: tz } });
}

function findTimeZone() {
  const oldIntl = window.Intl;
  try {
    window.Intl = undefined;
    const tz = jstz.determine().name();
    window.Intl = oldIntl;
    return tz;
  } catch {
    // sometimes (on android) you can't override intl
    return jstz.determine().name();
  }
}
