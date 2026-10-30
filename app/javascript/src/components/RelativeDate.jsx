import { formatDistanceStrict, formatISO, isValid, parseISO, startOfToday } from "date-fns";
import { useMemo, useState } from "react";

export const RelativeDate = ({ date, relativeAsDefault = true }) => {
  const parsedDate = useMemo(() => (date ? parseISO(date) : null), [date]);
  const relativeDate = useMemo(() => relativeDateString(parsedDate), [parsedDate]);
  const [showRelative, setShowRelative] = useState(relativeAsDefault);

  if (!date) return;

  if (!isValid(parsedDate)) return <span>{date}</span>;

  if (showRelative) {
    return (
      <span title={date} onClick={() => setShowRelative(false)}>
        {relativeDate}
      </span>
    );
  } else {
    return (
      <span title={relativeDate} onClick={() => setShowRelative(true)}>
        {formatISO(parsedDate, { representation: "date" })}
      </span>
    );
  }
};

const relativeDateString = (parsedDate) => {
  if (!isValid(parsedDate)) return;

  const today = startOfToday();
  if (parsedDate.getTime() == today.getTime()) return "today";
  return formatDistanceStrict(parsedDate, today, {
    addSuffix: true
  });
};
