import { formatDistanceStrict, formatISO, isValid, parseISO, startOfToday } from "date-fns";
import { useMemo, useState } from "react";

export const RelativeDate = ({ date, relativeAsDefault = true }) => {
  const relativeDate = useMemo(() => relativeDateString(date), [date]);
  const [showRelative, setShowRelative] = useState(relativeAsDefault);

  if (!date) return;

  if (!isValid(parseISO(date))) return <span>{date}</span>;

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
  if (!isValid(parsedDate)) return;

  const today = startOfToday();
  if (parsedDate.getTime() == today.getTime()) return "today";
  return formatDistanceStrict(parsedDate, today, {
    addSuffix: true
  });
};
