import { useState, useRef, useLayoutEffect, useEffect } from "react";
import { createPortal } from "react-dom";
import { Calendar, ChevronLeft, ChevronRight, X } from "lucide-react";
import { useAppSettings } from "../../context/AppSettingsContext";
import {
  adToBS, bsToAD, formatBS, getBSMonthADDates, bsMonthStartWeekday,
  BS_MONTH_NAMES_EN, BS_MONTH_NAMES_NE, toNepaliDigits,
} from "../../utils/nepaliDate";
import { useEscToClose } from "../../hooks/useEscToClose";

const AD_MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const WEEKDAYS_EN = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
const WEEKDAYS_NE = ["आ", "सो", "मं", "बु", "बि", "शु", "श"];

// BS_MONTH_DAYS in nepaliDate.js only has real data for these years —
// clamping BS navigation to this range keeps every rendered day accurate
// instead of silently falling back to a guessed 30-day month outside it.
const BS_MIN_YEAR = 2000; // matches BS_MONTH_DAYS in utils/nepaliDate.js
const BS_MAX_YEAR = 2099;

function localISO(d) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function parseISO(iso) {
  if (!iso) return null;
  const [y, m, d] = iso.split("-").map(Number);
  if (!y || !m || !d) return null;
  return new Date(y, m - 1, d);
}

/**
 * A real calendar picker — not just a plain browser `<input type="date">` —
 * with its own AD/BS toggle so a viewer can navigate and pick in whichever
 * calendar they think in, independent of the app-wide Settings > date
 * format preference (which only sets this picker's *starting* mode).
 * Always reports the picked date back as a plain AD "YYYY-MM-DD" string
 * via onChange, since that's what every date field in the backend expects —
 * BS is purely a navigation/display mode layered on top.
 */
export default function DatePicker({ value, onChange, placeholder = "Select date", className = "", disabled = false, clearable = false }) {
  const { dateMode, language } = useAppSettings();
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState(dateMode === "BS" ? "BS" : "AD");
  const selectedDate = parseISO(value);

  // Which month is on screen — AD terms when mode is AD, BS terms when BS.
  const initial = selectedDate || new Date();
  const [adView, setAdView] = useState({ year: initial.getFullYear(), month: initial.getMonth() + 1 });
  const initialBS = adToBS(initial);
  const [bsView, setBsView] = useState({ year: initialBS.year, month: initialBS.month });

  const rootRef = useRef(null);
  const triggerRef = useRef(null);
  const panelRef = useRef(null);
  const [rect, setRect] = useState(null);

  const close = () => setOpen(false);
  useEscToClose(close);

  useLayoutEffect(() => {
    if (!open) return;
    const updateRect = () => { if (triggerRef.current) setRect(triggerRef.current.getBoundingClientRect()); };
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
      if (rootRef.current && !rootRef.current.contains(e.target) && panelRef.current && !panelRef.current.contains(e.target)) {
        close();
      }
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  // Re-anchor the visible month to whatever's selected (or today) each time
  // the picker opens, so it doesn't reopen wherever it was last left.
  const handleOpen = () => {
    if (disabled) return;
    const base = selectedDate || new Date();
    setAdView({ year: base.getFullYear(), month: base.getMonth() + 1 });
    const bs = adToBS(base);
    setBsView({ year: bs.year, month: bs.month });
    setOpen(true);
  };

  const pick = (adDate) => {
    onChange(localISO(adDate));
    setOpen(false);
  };

  const toggleMode = () => {
    if (mode === "AD") {
      const bs = adToBS(new Date(adView.year, adView.month - 1, 15));
      setBsView({ year: Math.min(BS_MAX_YEAR, Math.max(BS_MIN_YEAR, bs.year)), month: bs.month });
      setMode("BS");
    } else {
      const ad = bsToAD(bsView.year, bsView.month, 15);
      setAdView({ year: ad.getFullYear(), month: ad.getMonth() + 1 });
      setMode("AD");
    }
  };

  const shiftAdMonth = (delta) => {
    let { year, month } = adView;
    month += delta;
    if (month < 1) { month = 12; year--; }
    if (month > 12) { month = 1; year++; }
    setAdView({ year, month });
  };

  const shiftBsMonth = (delta) => {
    let { year, month } = bsView;
    month += delta;
    if (month < 1) { month = 12; year--; }
    if (month > 12) { month = 1; year++; }
    if (year < BS_MIN_YEAR || year > BS_MAX_YEAR) return;
    setBsView({ year, month });
  };

  const displayLabel = () => {
    if (!selectedDate) return null;
    if (dateMode === "BS" || mode === "BS") {
      return formatBS(adToBS(selectedDate), language);
    }
    return `${String(selectedDate.getDate()).padStart(2, "0")} ${AD_MONTH_NAMES[selectedDate.getMonth()].slice(0, 3)} ${selectedDate.getFullYear()}`;
  };

  // ── AD grid ──
  const renderADGrid = () => {
    const { year, month } = adView;
    const firstOfMonth = new Date(year, month - 1, 1);
    const daysInMonth = new Date(year, month, 0).getDate();
    const startWeekday = firstOfMonth.getDay();
    const cells = [];
    for (let i = 0; i < startWeekday; i++) cells.push(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month - 1, d));

    return (
      <>
        <div className="flex items-center justify-between px-3 py-2">
          <button type="button" onClick={() => shiftAdMonth(-1)} className="rounded-lg p-1 text-navy-400 hover:bg-navy-800 hover:text-white">
            <ChevronLeft className="h-4 w-4" />
          </button>
          <span className="text-xs font-semibold text-white">{AD_MONTH_NAMES[month - 1]} {year}</span>
          <button type="button" onClick={() => shiftAdMonth(1)} className="rounded-lg p-1 text-navy-400 hover:bg-navy-800 hover:text-white">
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>
        <div className="grid grid-cols-7 gap-0.5 px-2 pb-1 text-center text-[10px] font-semibold text-navy-500">
          {WEEKDAYS_EN.map((w) => <div key={w}>{w}</div>)}
        </div>
        <div className="grid grid-cols-7 gap-0.5 px-2 pb-2">
          {cells.map((d, i) => {
            if (!d) return <div key={i} />;
            const iso = localISO(d);
            const isSelected = value === iso;
            const isToday = iso === localISO(new Date());
            return (
              <button
                key={i} type="button" onClick={() => pick(d)}
                className={`aspect-square rounded-lg text-xs transition ${
                  isSelected ? "bg-orange-500 font-bold text-white"
                  : isToday ? "border border-orange-500/50 text-orange-400"
                  : "text-navy-300 hover:bg-navy-800"
                }`}
              >
                {d.getDate()}
              </button>
            );
          })}
        </div>
      </>
    );
  };

  // ── BS grid ──
  const renderBSGrid = () => {
    const { year, month } = bsView;
    const monthDates = getBSMonthADDates(year, month);
    const startWeekday = bsMonthStartWeekday(year, month);
    const monthNames = language === "ne" ? BS_MONTH_NAMES_NE : BS_MONTH_NAMES_EN;
    const weekdays = language === "ne" ? WEEKDAYS_NE : WEEKDAYS_EN;
    const fmtDay = (n) => (language === "ne" ? toNepaliDigits(n) : n);

    return (
      <>
        <div className="flex items-center justify-between px-3 py-2">
          <button type="button" onClick={() => shiftBsMonth(-1)} disabled={year <= BS_MIN_YEAR && month === 1}
            className="rounded-lg p-1 text-navy-400 hover:bg-navy-800 hover:text-white disabled:opacity-30">
            <ChevronLeft className="h-4 w-4" />
          </button>
          <span className="text-xs font-semibold text-white">{monthNames[month - 1]} {fmtDay(year)}</span>
          <button type="button" onClick={() => shiftBsMonth(1)} disabled={year >= BS_MAX_YEAR && month === 12}
            className="rounded-lg p-1 text-navy-400 hover:bg-navy-800 hover:text-white disabled:opacity-30">
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>
        <div className="grid grid-cols-7 gap-0.5 px-2 pb-1 text-center text-[10px] font-semibold text-navy-500">
          {weekdays.map((w, i) => <div key={i}>{w}</div>)}
        </div>
        <div className="grid grid-cols-7 gap-0.5 px-2 pb-2">
          {Array.from({ length: startWeekday }).map((_, i) => <div key={`pad-${i}`} />)}
          {monthDates.map(({ bsDay, adDate }) => {
            const iso = localISO(adDate);
            const isSelected = value === iso;
            const isToday = iso === localISO(new Date());
            return (
              <button
                key={bsDay} type="button" onClick={() => pick(adDate)}
                className={`aspect-square rounded-lg text-xs transition ${
                  isSelected ? "bg-orange-500 font-bold text-white"
                  : isToday ? "border border-orange-500/50 text-orange-400"
                  : "text-navy-300 hover:bg-navy-800"
                }`}
              >
                {fmtDay(bsDay)}
              </button>
            );
          })}
        </div>
      </>
    );
  };

  return (
    <div ref={rootRef} className={`relative ${className}`}>
      <button
        ref={triggerRef}
        type="button"
        disabled={disabled}
        onClick={() => (open ? close() : handleOpen())}
        className="flex w-full items-center gap-2 rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-left text-sm text-white outline-none transition focus:border-orange-500 disabled:opacity-50"
      >
        <Calendar className="h-4 w-4 shrink-0 text-navy-500" />
        <span className={`flex-1 truncate ${selectedDate ? "" : "text-navy-500"}`}>{displayLabel() || placeholder}</span>
        {clearable && selectedDate && (
          <span
            role="button"
            tabIndex={-1}
            onClick={(e) => { e.stopPropagation(); onChange(""); }}
            className="shrink-0 rounded p-0.5 text-navy-500 hover:text-white"
          >
            <X className="h-3.5 w-3.5" />
          </span>
        )}
      </button>

      {open && rect && createPortal(
        <div
          ref={panelRef}
          style={{ position: "fixed", top: rect.bottom + 4, left: rect.left, width: Math.max(rect.width, 260) }}
          className="z-50 rounded-xl border border-navy-700 bg-navy-900 shadow-2xl"
        >
          <div className="flex items-center justify-between border-b border-navy-800 px-3 py-1.5">
            <button
              type="button" onClick={() => pick(new Date())}
              className="text-[10px] font-semibold text-orange-400 hover:text-orange-300"
            >
              Today
            </button>
            <div className="flex overflow-hidden rounded-lg border border-navy-700">
              <button
                type="button" onClick={() => mode !== "AD" && toggleMode()}
                className={`px-2.5 py-1 text-[10px] font-bold transition ${mode === "AD" ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}
              >
                AD
              </button>
              <button
                type="button" onClick={() => mode !== "BS" && toggleMode()}
                className={`px-2.5 py-1 text-[10px] font-bold transition ${mode === "BS" ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"}`}
              >
                BS
              </button>
            </div>
          </div>
          {mode === "AD" ? renderADGrid() : renderBSGrid()}
        </div>,
        document.body
      )}
    </div>
  );
}
