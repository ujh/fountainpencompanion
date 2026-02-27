import React, { useState, useEffect, useMemo } from "react";
import Jsona from "jsona";
import Select from "react-select";
import { getRequest } from "../fetch";

const formatter = new Jsona();

const fetchAllCurrentlyInked = async (filterArchived) => {
  let all = [];
  let page = 1;
  do {
    const params = new URLSearchParams({ "page[number]": page });
    if (filterArchived !== undefined) {
      params.set("filter[archived]", filterArchived);
    }
    const response = await getRequest(`/api/v1/currently_inked.json?${params}`);
    const json = await response.json();
    const items = formatter.deserialize(json);
    all.push(...items);
    page = json.meta.pagination.next_page;
  } while (page);
  return all;
};

const formatDate = (dateStr) => {
  if (!dateStr) return null;
  return dateStr;
};

const todayString = () => {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const csrfToken = () => {
  const el = document.querySelector("meta[name='csrf-token']");
  return el ? el.getAttribute("content") : null;
};

export const UsageRecordForm = () => {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [includeArchived, setIncludeArchived] = useState(false);
  const [loadingArchived, setLoadingArchived] = useState(false);
  const [selectedId, setSelectedId] = useState("");
  const [usedOn, setUsedOn] = useState("");

  useEffect(() => {
    async function loadEntries() {
      try {
        const active = await fetchAllCurrentlyInked("false");

        const sortByInkedOn = (a, b) => {
          if (a.inked_on < b.inked_on) return -1;
          if (a.inked_on > b.inked_on) return 1;
          return 0;
        };

        active.sort(sortByInkedOn);

        setEntries(active.map((e) => ({ ...e, group: "active" })));
      } finally {
        setLoading(false);
      }
    }
    loadEntries();
  }, []);

  useEffect(() => {
    if (!includeArchived) {
      setEntries((prev) => {
        const activeOnly = prev.filter((e) => e.group === "active");
        setSelectedId((prevId) => {
          const entry = prev.find((e) => String(e.id) === String(prevId));
          return entry && entry.group === "archived" ? "" : prevId;
        });
        return activeOnly;
      });
      return;
    }

    let cancelled = false;
    async function loadArchived() {
      setLoadingArchived(true);
      try {
        const archived = await fetchAllCurrentlyInked("true");

        const sortByInkedOn = (a, b) => {
          if (a.inked_on < b.inked_on) return -1;
          if (a.inked_on > b.inked_on) return 1;
          return 0;
        };

        archived.sort(sortByInkedOn);

        if (!cancelled) {
          setEntries((prev) => [
            ...prev.filter((e) => e.group === "active"),
            ...archived.map((e) => ({ ...e, group: "archived" }))
          ]);
        }
      } finally {
        if (!cancelled) setLoadingArchived(false);
      }
    }
    loadArchived();
    return () => {
      cancelled = true;
    };
  }, [includeArchived]);

  const selectedEntry = useMemo(() => {
    if (!selectedId) return null;
    return entries.find((e) => String(e.id) === String(selectedId));
  }, [entries, selectedId]);

  const minDate = selectedEntry ? formatDate(selectedEntry.inked_on) : undefined;
  const maxDate = selectedEntry
    ? selectedEntry.archived_on
      ? formatDate(selectedEntry.archived_on)
      : todayString()
    : undefined;

  const activeEntries = entries.filter((e) => e.group === "active");
  const archivedEntries = entries.filter((e) => e.group === "archived");

  const selectOptions = [
    ...(activeEntries.length > 0
      ? [
          {
            label: "Active",
            options: activeEntries.map((e) => ({
              value: String(e.id),
              label: `${e.ink_name} - ${e.pen_name}`
            }))
          }
        ]
      : []),
    ...(archivedEntries.length > 0
      ? [
          {
            label: "Archived",
            options: archivedEntries.map((e) => ({
              value: String(e.id),
              label: `${e.ink_name} - ${e.pen_name} (${e.inked_on} – ${e.archived_on})`
            }))
          }
        ]
      : [])
  ];

  const selectedOption =
    selectOptions.flatMap((group) => group.options).find((opt) => opt.value === selectedId) || null;

  const handleSelectChange = (option) => {
    setSelectedId(option ? option.value : "");
    setUsedOn("");
  };

  const formAction = selectedId ? `/currently_inked/${selectedId}/usage_record` : "#";

  if (loading) {
    return <div className="mb-3 text-muted">Loading currently inked entries...</div>;
  }

  if (entries.length === 0) {
    return null;
  }

  return (
    <form action={formAction} method="post" className="card mb-3">
      <div className="card-body">
        <h5 className="card-title">Add usage record</h5>
        <input type="hidden" name="authenticity_token" value={csrfToken() || ""} />
        <input type="hidden" name="used_on" value={usedOn} />
        <div className="row g-3 align-items-start">
          <div className="col-12 col-md-5">
            <label htmlFor="usage-record-currently-inked" className="form-label">
              Currently inked
            </label>
            <Select
              inputId="usage-record-currently-inked"
              options={selectOptions}
              value={selectedOption}
              onChange={handleSelectChange}
              isClearable
              placeholder="Select an entry..."
              isLoading={loadingArchived}
            />
            <div className="form-check mt-1">
              <input
                id="usage-record-include-archived"
                type="checkbox"
                className="form-check-input"
                checked={includeArchived}
                onChange={(e) => setIncludeArchived(e.target.checked)}
              />
              <label htmlFor="usage-record-include-archived" className="form-check-label">
                Include archived entries
              </label>
            </div>
          </div>
          <div className="col-12 col-md-4">
            <label htmlFor="usage-record-date" className="form-label">
              Date
            </label>
            <input
              id="usage-record-date"
              type="date"
              className="form-control"
              value={usedOn}
              onChange={(e) => setUsedOn(e.target.value)}
              disabled={!selectedId}
              min={minDate}
              max={maxDate}
            />
          </div>
          <div className="col-12 col-md-3">
            <label className="form-label d-none d-md-block">&nbsp;</label>
            <button
              type="submit"
              className="btn btn-success w-100"
              disabled={!selectedId || !usedOn}
            >
              Add record
            </button>
          </div>
        </div>
      </div>
    </form>
  );
};
