import { useState, useEffect, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, ChevronRight, AlertTriangle, Megaphone, X } from "lucide-react";
import { reports as reportsApi, sales as salesApi, superadmin as adminApi } from "../../api";
import { useAppSettings, usePrivateAmount } from "../../context/AppSettingsContext";
import { useEscToClose } from "../../hooks/useEscToClose";
import { dateStr } from "../../utils/dates";

// Announcements have no server-side "read" state (they're a broadcast, not
// per-user), so a viewer's dismissals are tracked locally — otherwise a
// notice they've already seen would sit in the badge count forever.
const DISMISSED_KEY = "bw_dismissed_announcements";

// A bill still owing money gets flagged here on its own, once it's been
// outstanding this many days — even if the user never set a manual
// "Set Reminder" date on it (that's the separate dueReminders list below).
const OVERDUE_AFTER_DAYS = 5;

function loadDismissed() {
  try {
    const saved = JSON.parse(localStorage.getItem(DISMISSED_KEY));
    return Array.isArray(saved) ? saved : [];
  } catch {
    return [];
  }
}

/**
 * The app's one notification center, living in the Topbar so it follows the
 * user to every screen: payment-collection nudges, due follow-up reminders,
 * low-stock alerts, and platform announcements — everything that used to be
 * scattered across Dashboard banners (or, for announcements, not surfaced
 * to end users at all) now funnels through this single bell.
 */
export default function ReminderBell() {
  const navigate = useNavigate();
  const { language } = useAppSettings();
  const fmt = usePrivateAmount();

  const [totalReceivable, setTotalReceivable] = useState(0);
  const [debtors, setDebtors] = useState(null);
  const [dueReminders, setDueReminders] = useState([]);
  const [overdueBills, setOverdueBills] = useState([]);
  const [lowStockCount, setLowStockCount] = useState(0);
  const [announcements, setAnnouncements] = useState([]);
  const [dismissed, setDismissed] = useState(loadDismissed);
  const [open, setOpen] = useState(false);
  const panelRef = useRef(null);

  useEffect(() => {
    reportsApi.dashboard()
      .then((r) => {
        setTotalReceivable(r.data?.total_receivable || 0);
        setLowStockCount(r.data?.low_stock_count || 0);
      })
      .catch(() => {});

    salesApi.list({ reminder_enabled: true, status: "CONFIRMED", page_size: 50 })
      .then((r) => {
        const now = new Date();
        const results = r.data?.results ?? r.data ?? [];
        setDueReminders(
          results.filter((s) =>
            s.reminder_at && new Date(s.reminder_at) <= now && parseFloat(s.due_amount || 0) > 0
          )
        );
      })
      .catch(() => setDueReminders([]));

    const cutoff = new Date(Date.now() - OVERDUE_AFTER_DAYS * 24 * 60 * 60 * 1000);
    salesApi.list({
      status: "CONFIRMED", has_due: true,
      date_to: dateStr(cutoff),
      ordering: "sale_date", page_size: 50,
    })
      .then((r) => setOverdueBills(r.data?.results ?? r.data ?? []))
      .catch(() => setOverdueBills([]));

    adminApi.activeAnnouncements()
      .then((r) => setAnnouncements(r.data || []))
      .catch(() => setAnnouncements([]));
  }, []);

  useEffect(() => {
    if (!totalReceivable || totalReceivable <= 0) return;
    reportsApi.receivableAging()
      .then((r) => setDebtors(r.data?.top_debtors || []))
      .catch(() => setDebtors(null));
  }, [totalReceivable]);

  const close = useCallback(() => setOpen(false), []);
  useEscToClose(close);

  useEffect(() => {
    if (!open) return;
    const onClick = (e) => { if (panelRef.current && !panelRef.current.contains(e.target)) close(); };
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, [open, close]);

  const dismissAnnouncement = (id) => {
    const next = [...dismissed, id];
    setDismissed(next);
    try { localStorage.setItem(DISMISSED_KEY, JSON.stringify(next)); } catch {}
  };

  const visibleAnnouncements = announcements.filter((a) => !dismissed.includes(a.id));
  // A bill with its own manually-set reminder already shows up in
  // dueReminders — don't also list it here, or it'd count (and appear)
  // twice just for being both overdue and reminder-enabled.
  const dueReminderIds = new Set(dueReminders.map((s) => s.id));
  const unremindedOverdueBills = overdueBills.filter((s) => !dueReminderIds.has(s.id));
  const hasReceivable = totalReceivable > 0;
  const hasLowStock = lowStockCount > 0;
  const count = dueReminders.length + unremindedOverdueBills.length + (hasReceivable ? 1 : 0) + (hasLowStock ? 1 : 0) + visibleAnnouncements.length;
  const goTo = (path) => { close(); navigate(path); };

  return (
    <div className="relative" ref={panelRef}>
      <button
        onClick={() => setOpen((o) => !o)}
        title={language === "ne" ? "सूचनाहरू" : "Notifications"}
        className="relative rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 transition hover:text-orange-400"
      >
        <Bell className="h-4 w-4" />
        {count > 0 && (
          <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-orange-500 px-1 text-[9px] font-bold text-white">
            {count > 9 ? "9+" : count}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 top-full z-40 mt-2 w-80 max-w-[90vw] rounded-2xl border border-navy-800 bg-navy-900 shadow-2xl">
          <div className="border-b border-navy-800 px-4 py-3">
            <p className="text-sm font-semibold text-white">
              {language === "ne" ? "सूचनाहरू" : "Notifications"}
            </p>
          </div>

          <div className="max-h-96 overflow-y-auto">
            {count === 0 ? (
              <p className="px-4 py-8 text-center text-sm text-navy-500">
                {language === "ne" ? "अहिलेको लागि कुनै सूचना छैन" : "You're all caught up"}
              </p>
            ) : (
              <>
                {visibleAnnouncements.map((a) => (
                  <div key={a.id} className="border-b border-navy-800 px-4 py-3">
                    <div className="flex items-start gap-2.5">
                      <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-purple-500/15">
                        <Megaphone className="h-3.5 w-3.5 text-purple-400" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-semibold text-white">{a.title}</p>
                        {a.body && <p className="mt-0.5 text-xs text-navy-400">{a.body}</p>}
                      </div>
                      <button
                        onClick={() => dismissAnnouncement(a.id)}
                        title={language === "ne" ? "हटाउनुहोस्" : "Dismiss"}
                        className="shrink-0 text-navy-600 hover:text-navy-300"
                      >
                        <X className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                ))}

                {hasLowStock && (
                  <button
                    onClick={() => goTo("/inventory/low-stock")}
                    className="flex w-full items-start gap-2.5 border-b border-navy-800 px-4 py-3 text-left hover:bg-navy-800/40"
                  >
                    <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-red-500/15">
                      <AlertTriangle className="h-3.5 w-3.5 text-red-400" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-semibold text-white">
                        {lowStockCount} {language === "ne" ? "वस्तु कम स्टकमा" : "items low on stock"}
                      </p>
                      <p className="mt-0.5 text-xs text-navy-500">{language === "ne" ? "स्टक पुनः अर्डर गर्नुहोस्" : "Reorder to avoid stockouts"}</p>
                    </div>
                  </button>
                )}

                {hasReceivable && (
                  <div className="border-b border-navy-800 px-4 py-3">
                    <p className="text-sm font-semibold text-white">
                      {language === "ne" ? "तपाईंले पाउनुपर्ने रकम बाँकी छ" : "You have money pending to receive"}
                      {" — "}
                      <span className="text-orange-400">{fmt(totalReceivable)}</span>
                    </p>
                    {debtors && debtors.length > 0 && (
                      <div className="mt-2.5 space-y-1.5">
                        {debtors.slice(0, 3).map((d) => (
                          <button
                            key={d.customer_id ?? d.customer__name}
                            onClick={() => goTo("/payments")}
                            className="flex w-full items-center justify-between gap-2 rounded-lg px-2 py-1 text-left text-xs text-navy-300 hover:bg-navy-800/60"
                          >
                            <span className="truncate">
                              {d.customer__name || "Cash Sales"} · {d.invoice_count} invoice{d.invoice_count !== 1 ? "s" : ""}
                            </span>
                            <span className="shrink-0 font-semibold text-orange-300">{fmt(d.total_due)}</span>
                          </button>
                        ))}
                      </div>
                    )}
                    <button
                      onClick={() => goTo("/payments")}
                      className="mt-2.5 flex items-center gap-1 text-xs font-semibold text-orange-400 hover:text-orange-300"
                    >
                      {language === "ne" ? "हेर्नुहोस् र संकलन गर्नुहोस्" : "View & Collect"} <ChevronRight className="h-3.5 w-3.5" />
                    </button>
                  </div>
                )}

                {dueReminders.length > 0 && (
                  <div className={`px-4 py-3 ${unremindedOverdueBills.length > 0 ? "border-b border-navy-800" : ""}`}>
                    <p className="text-sm font-semibold text-white">
                      {language === "ne"
                        ? `${dueReminders.length} फलोअप रिमाइन्डर बाँकी छ`
                        : `${dueReminders.length} follow-up reminder${dueReminders.length !== 1 ? "s" : ""} due`}
                    </p>
                    <div className="mt-2.5 space-y-1.5">
                      {dueReminders.slice(0, 5).map((s) => (
                        <button
                          key={s.id}
                          onClick={() => goTo(`/sales?view=${s.id}`)}
                          className="flex w-full items-center justify-between gap-2 rounded-lg px-2 py-1 text-left text-xs text-navy-300 hover:bg-navy-800/60"
                        >
                          <span className="truncate">
                            {s.invoice_number} · {s.customer_name || s.party_name || "Cash Sales"}
                          </span>
                          <span className="shrink-0 font-semibold text-blue-300">Rs. {parseFloat(s.due_amount).toFixed(0)}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {unremindedOverdueBills.length > 0 && (
                  <div className="px-4 py-3">
                    <p className="text-sm font-semibold text-white">
                      {language === "ne"
                        ? `${unremindedOverdueBills.length} बिल ${OVERDUE_AFTER_DAYS}+ दिनदेखि बाँकी छ`
                        : `${unremindedOverdueBills.length} bill${unremindedOverdueBills.length !== 1 ? "s" : ""} pending ${OVERDUE_AFTER_DAYS}+ days`}
                    </p>
                    <p className="mt-0.5 text-xs text-navy-500">
                      {language === "ne" ? "भुक्तानी संकलन गर्ने समय भयो" : "Time to collect payment"}
                    </p>
                    <div className="mt-2.5 space-y-1.5">
                      {unremindedOverdueBills.slice(0, 5).map((s) => (
                        <button
                          key={s.id}
                          onClick={() => goTo(`/sales?view=${s.id}`)}
                          className="flex w-full items-center justify-between gap-2 rounded-lg px-2 py-1 text-left text-xs text-navy-300 hover:bg-navy-800/60"
                        >
                          <span className="truncate">
                            {s.invoice_number} · {s.customer_name || s.party_name || "Cash Sales"}
                          </span>
                          <span className="shrink-0 font-semibold text-orange-300">Rs. {parseFloat(s.due_amount).toFixed(0)}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
