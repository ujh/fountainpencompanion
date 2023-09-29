import React, { useMemo, useState } from "react";
import {
  startOfToday,
  parseISO,
  formatDistanceStrict,
  formatISO
} from "date-fns";

export const RelativeDate = ({ date, relativeAsDefault = true }) => {
  const relativeDate = useMemo(() => relativeDateString(date), [date]);
  const [showRelative, setShowRelative] = useState(relativeAsDefault);

  if (!date) return;

  if (showRelative) {
    return (
      <span title={date} onClick={() => setShowRelative(false)}>
        {relativeDate}
      </span>
    );
  } else {
    return (
      <span title={relativeDate} onClick={() => setShowRelative(true)}>
        {formatISO(parseISO(date), { representation: "date" })}
      </span>
    );
  }
};

const relativeDateString = (date) => {
  if (!date) return;

  const parsedDate = parseISO(date);
  const today = startOfToday();
  if (parsedDate.getTime() == today.getTime()) return "today";
  return formatDistanceStrict(parsedDate, today, {
    addSuffix: true
  });
};
