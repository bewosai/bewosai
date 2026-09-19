import { formatCurrency, formatDate } from "../../utils/format";

export default function PartyLedgerModal({ open, onClose, ledger, loading }) {
  if (!open) return null;

  const cardClass =
    "rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-4";

  const summary = ledger?.summary || {};
  const balance = summary?.balance || {};

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 px-4 py-6">
      <div className="max-h-[90vh] w-full max-w-5xl overflow-hidden rounded-2xl border border-emerald-500/20 bg-slate-900 shadow-2xl">
        <div className="flex items-center justify-between border-b border-emerald-500/20 px-5 py-4">
          <div>
            <h2 className="text-lg font-semibold text-emerald-200">
              Party Ledger
            </h2>
            <p className="text-sm text-emerald-200/70">
              {ledger?.party?.name || "Party details"}
            </p>
          </div>

          <button
            onClick={onClose}
            className="rounded-lg border border-emerald-500/20 px-3 py-1.5 text-sm text-emerald-200 hover:bg-emerald-500/10"
          >
            Close
          </button>
        </div>

        <div className="max-h-[calc(90vh-76px)] overflow-y-auto p-5">
          {loading ? (
            <div className="py-10 text-center text-emerald-200">
              Loading ledger...
            </div>
          ) : !ledger ? (
            <div className="py-10 text-center text-emerald-200">
              No ledger data found.
            </div>
          ) : (
            <>
              <div className="mb-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <div className={cardClass}>
                  <p className="text-sm text-emerald-200/70">Opening Balance</p>
                  <h3 className="mt-2 text-xl font-bold text-emerald-200">
                    {formatCurrency(ledger.party?.openingBalance || 0)}
                  </h3>
                </div>

                <div className={cardClass}>
                  <p className="text-sm text-emerald-200/70">Total Sales</p>
                  <h3 className="mt-2 text-xl font-bold text-emerald-200">
                    {formatCurrency(summary.totalSales || 0)}
                  </h3>
                </div>

                <div className={cardClass}>
                  <p className="text-sm text-emerald-200/70">Total Purchases</p>
                  <h3 className="mt-2 text-xl font-bold text-emerald-200">
                    {formatCurrency(summary.totalPurchases || 0)}
                  </h3>
                </div>

                <div className={cardClass}>
                  <p className="text-sm text-emerald-200/70">Payments In</p>
                  <h3 className="mt-2 text-xl font-bold text-emerald-200">
                    {formatCurrency(summary.totalPaymentsIn || 0)}
                  </h3>
                </div>

                <div className={cardClass}>
                  <p className="text-sm text-emerald-200/70">Payments Out</p>
                  <h3 className="mt-2 text-xl font-bold text-emerald-200">
                    {formatCurrency(summary.totalPaymentsOut || 0)}
                  </h3>
                </div>

                <div className="rounded-2xl border border-emerald-500 bg-emerald-500 p-4">
                  <p className="text-sm text-white/80">Current Balance</p>
                  <h3 className="mt-2 text-xl font-bold text-white">
                    {formatCurrency(balance.net || 0)}
                  </h3>
                  <p className="mt-1 text-xs text-white/80">
                    {balance.direction === "party_owes_you" && "Party owes you"}
                    {balance.direction === "you_owe_party" && "You owe party"}
                    {balance.direction === "settled" && "Settled"}
                  </p>
                </div>
              </div>

              <div className="mb-5 rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-4">
                <h4 className="mb-3 text-base font-semibold text-emerald-200">
                  Party Details
                </h4>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  <Info label="Name" value={ledger.party?.name} />
                  <Info label="Phone" value={ledger.party?.phone} />
                  <Info label="Email" value={ledger.party?.email} />
                  <Info label="Type" value={ledger.party?.type} />
                  <Info label="Address" value={ledger.party?.address} />
                  <Info label="Contact Person" value={ledger.party?.contactPerson} />
                  <Info label="Status" value={ledger.party?.status} />
                  <Info label="Notes" value={ledger.party?.notes} />
                </div>
              </div>

              <div className="rounded-2xl border border-emerald-500/20 bg-emerald-500/10 p-4">
                <h4 className="mb-3 text-base font-semibold text-emerald-200">
                  Transactions
                </h4>

                {!ledger.transactions || ledger.transactions.length === 0 ? (
                  <div className="rounded-xl border border-emerald-500/10 bg-slate-950/40 p-4 text-sm text-emerald-200/70">
                    No transactions found.
                  </div>
                ) : (
                  <div className="space-y-3">
                    {ledger.transactions.map((tx) => (
                      <div
                        key={`${tx.type}-${tx._id}`}
                        className="flex flex-col gap-3 rounded-xl border border-emerald-500/10 bg-slate-950/40 p-4 sm:flex-row sm:items-center sm:justify-between"
                      >
                        <div>
                          <p className="text-sm font-semibold capitalize text-emerald-200">
                            {String(tx.type || "").replace("_", " ")}
                          </p>
                          <p className="text-xs text-emerald-200/60">
                            {tx.refNo || "No reference"}
                          </p>
                          <p className="text-xs text-emerald-200/60">
                            {formatDate(tx.date)}
                          </p>
                          {tx.note ? (
                            <p className="mt-1 text-sm text-emerald-200/80">
                              {tx.note}
                            </p>
                          ) : null}
                        </div>

                        <div className="text-left sm:text-right">
                          <p className="text-lg font-bold text-emerald-200">
                            {formatCurrency(tx.amount || 0)}
                          </p>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function Info({ label, value }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-emerald-200/60">
        {label}
      </p>
      <p className="mt-1 text-sm text-emerald-200">{value || "-"}</p>
    </div>
  );
}