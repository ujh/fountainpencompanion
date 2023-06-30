import React, { useMemo, useState } from "react";
import { formatDistance, startOfToday, parseISO } from "date-fns";

export const RelativeDate = ({ date, relativeAsDefault = true }) => {
  const relativeDate = useMemo(() => relativeDateString(date), [date]);
  const [showRelative, setShowRelative] = useState(relativeAsDefault);

  if (showRelative) {
    return (
      <span title={date} onClick={() => setShowRelative(false)}>
        {relativeDate}
      </span>
    );
  } else {
    return (
      <span title={relativeDate} onClick={() => setShowRelative(true)}>
        {date}
      </span>
    );
  }
};

const relativeDateString = (date) => {
  if (!date) return;

  const parsedDate = parseISO(date);
  const today = startOfToday();
  if (parsedDate.getTime() == today.getTime()) return "today";
  return formatDistance(parsedDate, today, {
    addSuffix: true
  });
};
