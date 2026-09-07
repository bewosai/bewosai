import { useState, useEffect, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Bell, ChevronRight } from "lucide-react";
import { reports as reportsApi, sales as salesApi } from "../../api";
import { useAppSettings, usePrivateAmount } from "../../context/AppSettingsContext";
import { useEscToClose } from "../../hooks/useEscToClose";

/**
 * Topbar's reminder bell — replaces the two banners that used to sit at the
 * top of the Dashboard (receivable-collection nudge + due follow-up
 * reminders). Living in the Topbar means they follow the user to every
 * screen instead of only being visible on Dashboard, and don't push the
 * rest of the page's content down.
 */
export default function ReminderBell() {
  const navigate = useNavigate();
  const { language } = useAppSettings();
  const fmt = usePrivateAmount();

  const [totalReceivable, setTotalReceivable] = useState(0);
  const [debtors, setDebtors] = useState(null);
  const [dueReminders, setDueReminders] = useState([]);
  const [open, setOpen] = useState(false);
  const panelRef = useRef(null);

  useEffect(() => {
    reportsApi.dashboard()
      .then((r) => setTotalReceivable(r.data?.total_receivable || 0))
      .catch(() => setTotalReceivable(0));

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

  const hasReceivable = totalReceivable > 0;
  const count = dueReminders.length + (hasReceivable ? 1 : 0);
  const goTo = (path) => { close(); navigate(path); };

  return (
    <div className="relative" ref={panelRef}>
      <button
        onClick={() => setOpen((o) => !o)}
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
              {language === "ne" ? "रिमाइन्डरहरू" : "Reminders"}
            </p>
          </div>

          <div className="max-h-96 overflow-y-auto">
            {count === 0 ? (
              <p className="px-4 py-8 text-center text-sm text-navy-500">
                {language === "ne" ? "अहिलेको लागि कुनै रिमाइन्डर छैन" : "You're all caught up"}
              </p>
            ) : (
              <>
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
                              {d.customer__name || "Walk-in"} · {d.invoice_count} invoice{d.invoice_count !== 1 ? "s" : ""}
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
                  <div className="px-4 py-3">
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
                            {s.invoice_number} · {s.customer_name || s.party_name || "Walk-in"}
                          </span>
                          <span className="shrink-0 font-semibold text-blue-300">Rs. {parseFloat(s.due_amount).toFixed(0)}</span>
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
