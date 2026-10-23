import { useMemo, useState } from "react";
import { ArrowDownWideNarrow, ArrowUpNarrowWide } from "lucide-react";

/* Ascending / descending sorting for any list page.

   const SORTS = [
     { key: "date", label: "Date", type: "date", get: (s) => s.sale_date },
     { key: "total", label: "Amount", type: "number", get: (s) => s.total },
     { key: "name", label: "Customer", type: "text", get: (s) => s.customer_name },
   ];
   const sort = useSort("sales", SORTS, { key: "date", dir: "desc" });
   const rows = sort.apply(filtered);
   <SortControl sort={sort} />

   Empty values always go last, whichever direction. The choice is remembered
   per page in this browser. */

function remembered(storageKey, fallback) {
  try {
    const saved = JSON.parse(localStorage.getItem(`sort_${storageKey}`) || "null");
    if (saved && typeof saved.key === "string" && (saved.dir === "asc" || saved.dir === "desc")) return saved;
  } catch { /* private window / bad value: use the default */ }
  return fallback;
}

function comparable(value, type) {
  if (value === null || value === undefined || value === "") return null;
  if (type === "number") {
    const n = parseFloat(value);
    return Number.isFinite(n) ? n : null;
  }
  if (type === "date") {
    const t = Date.parse(value);
    return Number.isFinite(t) ? t : null;
  }
  return String(value).toLocaleLowerCase();
}

export function useSort(storageKey, options, fallback) {
  const [state, setState] = useState(() => {
    const saved = remembered(storageKey, fallback);
    return options.some((o) => o.key === saved.key) ? saved : fallback;
  });

  const save = (next) => {
    setState(next);
    try { localStorage.setItem(`sort_${storageKey}`, JSON.stringify(next)); } catch { /* not saved: fine */ }
  };

  const option = options.find((o) => o.key === state.key) || options[0];

  const apply = (rows) => {
    if (!option || !Array.isArray(rows)) return rows;
    const sign = state.dir === "asc" ? 1 : -1;
    return rows
      .map((row, index) => ({ row, index, value: comparable(option.get(row), option.type) }))
      .sort((a, b) => {
        if (a.value === null && b.value === null) return a.index - b.index;
        if (a.value === null) return 1;
        if (b.value === null) return -1;
        if (a.value < b.value) return -sign;
        if (a.value > b.value) return sign;
        return a.index - b.index;     // stable: equal values keep their order
      })
      .map((x) => x.row);
  };

  return {
    options,
    key: option?.key,
    dir: state.dir,
    setKey: (key) => save({ key, dir: state.dir }),
    toggleDir: () => save({ key: state.key, dir: state.dir === "asc" ? "desc" : "asc" }),
    apply,
  };
}

/* Memoised variant of sort.apply for big lists. */
export function useSorted(sort, rows) {
  // eslint-disable-next-line react-hooks/exhaustive-deps
  return useMemo(() => sort.apply(rows), [rows, sort.key, sort.dir]);
}

export default function SortControl({ sort, className = "" }) {
  const asc = sort.dir === "asc";
  const Icon = asc ? ArrowUpNarrowWide : ArrowDownWideNarrow;
  return (
    <div className={`flex items-center gap-1.5 ${className}`}>
      <label className="text-xs text-navy-500 whitespace-nowrap" htmlFor={`sort-${sort.options.map((o) => o.key).join("-")}`}>
        Sort by
      </label>
      <select
        id={`sort-${sort.options.map((o) => o.key).join("-")}`}
        value={sort.key}
        onChange={(e) => sort.setKey(e.target.value)}
        className="rounded-lg border border-navy-700 bg-navy-800 px-2 py-1.5 text-xs text-white focus:border-orange-500 focus:outline-none"
      >
        {sort.options.map((o) => <option key={o.key} value={o.key}>{o.label}</option>)}
      </select>
      <button
        type="button"
        onClick={sort.toggleDir}
        title={asc ? "Ascending — tap for descending" : "Descending — tap for ascending"}
        aria-label={asc ? "Sorted ascending" : "Sorted descending"}
        className="flex items-center gap-1 rounded-lg border border-navy-700 bg-navy-800 px-2 py-1.5 text-xs font-semibold text-navy-200 hover:border-orange-500 hover:text-white"
      >
        <Icon className="h-3.5 w-3.5" />
        {asc ? "Asc" : "Desc"}
      </button>
    </div>
  );
}
