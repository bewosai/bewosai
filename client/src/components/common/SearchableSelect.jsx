import { useState, useRef, useEffect, useMemo, useLayoutEffect } from "react";
import { createPortal } from "react-dom";
import { Search, Plus, Check } from "lucide-react";

/**
 * Type-to-filter dropdown for picking one item from a list that's too long
 * for a plain <select> to be usable (products, parties, etc.). Shows
 * `recentIds` first when the search box is empty, matching the "recently
 * used" pattern most POS/invoicing apps use so the common case — reusing
 * whatever you picked a moment ago — doesn't need typing at all.
 *
 * The dropdown is rendered through a portal into document.body instead of
 * as a normal absolutely-positioned child: every place this is used sits
 * inside a scrollable modal body, and a plain `position: absolute` panel
 * gets silently clipped by that ancestor's overflow — the menu would open
 * but render invisible below the visible edge of the items table.
 *
 * Barcode scanners act as a keyboard emulator: they "type" the code's
 * characters far faster than any human, then send Enter. When `options`
 * carries a `code` on each item, the trigger button itself listens for
 * that burst pattern (even while collapsed — a scan is a single
 * deterministic action, not a thing you browse for) and selects the exact
 * match immediately without ever opening the dropdown.
 */
export default function SearchableSelect({
  options, // [{ id, label, sublabel?, code? }]
  value,
  onChange,
  onAddNew,
  addNewLabel = "+ Add New",
  placeholder = "Search...",
  recentIds = [],
  className = "",
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [highlight, setHighlight] = useState(0);
  const scanBufferRef = useRef("");
  const lastKeyTimeRef = useRef(0);
  const [rect, setRect] = useState(null);
  const rootRef = useRef(null);
  const triggerRef = useRef(null);
  const panelRef = useRef(null);
  const inputRef = useRef(null);

  const selected = options.find((o) => String(o.id) === String(value));

  useEffect(() => {
    if (!open) setQuery("");
  }, [open]);

  // Recomputed on open and whenever the trigger might have moved — e.g. the
  // modal body scrolling, since that scroll happens on an inner container
  // and doesn't bubble to window in the normal (non-capture) phase.
  useLayoutEffect(() => {
    if (!open) return;
    const updateRect = () => {
      if (triggerRef.current) setRect(triggerRef.current.getBoundingClientRect());
    };
    updateRect();
    window.addEventListener("scroll", updateRect, true);
    window.addEventListener("resize", updateRect);
    return () => {
      window.removeEventListener("scroll", updateRect, true);
      window.removeEventListener("resize", updateRect);
    };
  }, [open]);

  useEffect(() => {
    function onClickOutside(e) {
      if (
        rootRef.current && !rootRef.current.contains(e.target) &&
        panelRef.current && !panelRef.current.contains(e.target)
      ) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) {
      // Nothing typed yet — lead with recently used items (most recent
      // first), then the rest of the list so it's still fully browsable.
      const recentSet = new Set(recentIds.map(String));
      const recent = recentIds
        .map((id) => options.find((o) => String(o.id) === String(id)))
        .filter(Boolean);
      const rest = options.filter((o) => !recentSet.has(String(o.id)));
      return [...recent, ...rest].slice(0, 30);
    }
    return options
      .filter((o) => o.label?.toLowerCase().includes(q) || o.sublabel?.toLowerCase().includes(q) || o.code?.toLowerCase().includes(q))
      .slice(0, 30);
  }, [query, options, recentIds]);

  const showRecentDivider = !query.trim() && recentIds.length > 0;

  const pick = (opt) => {
    onChange(opt.id);
    setOpen(false);
    setQuery("");
  };

  // Runs on the collapsed trigger button — catches a scan before the
  // dropdown ever opens. Human keystrokes on a focused button are rare and
  // slow (>60ms apart); a scanner's are a solid burst, so a gap resets the
  // buffer and only a fast, complete, exact barcode match auto-selects.
  const handleTriggerKeyDown = (e) => {
    const now = Date.now();
    if (now - lastKeyTimeRef.current > 60) scanBufferRef.current = "";
    lastKeyTimeRef.current = now;

    if (e.key === "Enter") {
      const code = scanBufferRef.current.trim();
      scanBufferRef.current = "";
      const match = code && options.find((o) => o.code && o.code === code);
      if (match) {
        e.preventDefault();
        pick(match);
        return;
      }
      // No buffered scan (or no match) — an ordinary Enter press opens the
      // dropdown, same as before.
      setOpen(true);
      e.preventDefault();
      return;
    }
    if (e.key === "ArrowDown") {
      scanBufferRef.current = "";
      setOpen(true);
      e.preventDefault();
      return;
    }
    if (e.key.length === 1) {
      scanBufferRef.current += e.key;
    } else if (e.key !== "Shift") {
      scanBufferRef.current = "";
    }
  };

  const handleKeyDown = (e) => {
    if (!open) {
      if (e.key === "ArrowDown" || e.key === "Enter") { setOpen(true); e.preventDefault(); }
      return;
    }
    const itemCount = filtered.length + (onAddNew ? 1 : 0);
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setHighlight((h) => Math.min(h + 1, itemCount - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setHighlight((h) => Math.max(h - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (onAddNew && highlight === filtered.length) {
        onAddNew();
        setOpen(false);
      } else if (filtered[highlight]) {
        pick(filtered[highlight]);
      }
    } else if (e.key === "Escape") {
      setOpen(false);
    }
  };

  return (
    <div ref={rootRef} className={`relative ${className}`}>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => { setOpen((o) => !o); setHighlight(0); setTimeout(() => inputRef.current?.focus(), 0); }}
        onKeyDown={handleTriggerKeyDown}
        className="w-full flex items-center gap-1.5 rounded-md bg-navy-800 border border-navy-700 px-2 py-1.5 text-xs text-left text-white focus:border-orange-500 focus:outline-none"
      >
        <span className="flex-1 truncate">{selected?.label || <span className="text-navy-500">{placeholder}</span>}</span>
      </button>

      {open && rect && createPortal(
        <div
          ref={panelRef}
          style={{ position: "fixed", top: rect.bottom + 4, left: rect.left, width: Math.max(rect.width, 220) }}
          className="z-50 rounded-lg border border-navy-700 bg-navy-900 shadow-xl"
        >
          <div className="relative border-b border-navy-800 p-1.5">
            <Search className="absolute left-4 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-navy-500" />
            <input
              ref={inputRef}
              autoFocus
              value={query}
              onChange={(e) => { setQuery(e.target.value); setHighlight(0); }}
              onKeyDown={handleKeyDown}
              placeholder={placeholder}
              className="w-full rounded-md bg-navy-800 py-1.5 pl-8 pr-2 text-xs text-white placeholder-navy-500 outline-none"
            />
          </div>
          <div className="max-h-56 overflow-y-auto py-1">
            {onAddNew && (
              <button
                type="button"
                onMouseEnter={() => setHighlight(filtered.length)}
                onClick={() => { onAddNew(); setOpen(false); }}
                className={`flex w-full items-center gap-1.5 px-3 py-1.5 text-left text-xs font-medium text-orange-400 ${highlight === filtered.length ? "bg-navy-800" : ""}`}
              >
                <Plus className="h-3 w-3" /> {addNewLabel}
              </button>
            )}
            {showRecentDivider && (
              <p className="px-3 py-1 text-[10px] font-semibold uppercase tracking-wide text-navy-500">Recently used</p>
            )}
            {filtered.length === 0 ? (
              <p className="px-3 py-3 text-center text-xs text-navy-500">No matches</p>
            ) : (
              filtered.map((opt, i) => (
                <button
                  key={opt.id}
                  type="button"
                  onMouseEnter={() => setHighlight(i)}
                  onClick={() => pick(opt)}
                  className={`flex w-full items-center justify-between gap-2 px-3 py-1.5 text-left text-xs text-white ${i === highlight ? "bg-navy-800" : ""}`}
                >
                  <span className="min-w-0 flex-1">
                    <span className="block truncate">{opt.label}</span>
                    {opt.sublabel && <span className="block truncate text-[10px] text-navy-500">{opt.sublabel}</span>}
                  </span>
                  {String(opt.id) === String(value) && <Check className="h-3 w-3 shrink-0 text-orange-400" />}
                </button>
              ))
            )}
          </div>
        </div>,
        document.body
      )}
    </div>
  );
}
