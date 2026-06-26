import { useState, useEffect } from "react";
import { sales } from "../api/index";
import { useTranslation } from "../utils/translations";
import { useDateFormat } from "../context/AppSettingsContext";
import { FileText, Plus, Loader, CheckCircle, Clock, XCircle, Send } from "lucide-react";

const STATUS_STYLES = {
  DRAFT: "bg-navy-800 text-navy-400",
  SENT: "bg-blue-100 text-blue-700",
  ACCEPTED: "bg-green-100 text-green-600",
  REJECTED: "bg-red-100 text-red-500",
};

export default function QuotationPage() {
  const { t, language } = useTranslation();
  const formatDate = useDateFormat();
  const [quotations, setQuotations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("ALL");

  useEffect(() => {
    sales.quotations().then((r) => setQuotations(r.data?.results ?? r.data ?? [])).catch(() => setQuotations([])).finally(() => setLoading(false));
  }, []);

  const tabs = ["ALL", "DRAFT", "SENT", "ACCEPTED", "REJECTED"];
  const filtered = activeTab === "ALL" ? quotations : quotations.filter((q) => q.status === activeTab);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
            <FileText className="h-6 w-6 text-orange-500" />{t("quotation")}
          </h1>
          <p className="mt-1 text-sm text-navy-500">{t("quotationHistory")}</p>
        </div>
        <button className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition">
          <Plus className="h-4 w-4" />{t("newQuotation")}
        </button>
      </div>

      <div className="flex gap-2 flex-wrap">
        {tabs.map((tab) => (
          <button key={tab} onClick={() => setActiveTab(tab)} className={`rounded-xl px-4 py-2 text-sm font-medium transition ${activeTab === tab ? "bg-orange-500 text-white" : "bg-navy-900 border border-navy-800 text-navy-400 hover:text-white"}`}>
            {tab === "ALL" ? t("all") : tab}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center rounded-2xl border border-navy-800 bg-navy-900 py-16 text-center">
          <FileText className="h-10 w-10 text-navy-600 mb-3" />
          <h3 className="font-semibold text-white">{t("noData")}</h3>
        </div>
      ) : (
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="divide-y divide-navy-800">
            {filtered.map((q) => (
              <div key={q.id} className="flex items-center gap-4 px-5 py-4 hover:bg-navy-800/40 transition">
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="font-semibold text-white text-sm">{q.quotation_number}</p>
                    <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${STATUS_STYLES[q.status] || STATUS_STYLES.DRAFT}`}>{q.status}</span>
                  </div>
                  <p className="text-xs text-navy-500 mt-0.5">{q.customer_name || language === "ne" ? "ग्राहक नाम छैन" : "No customer"} · {formatDate(q.date)}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="font-bold text-white">Rs. {parseFloat(q.total || 0).toLocaleString("en-IN", { minimumFractionDigits: 2 })}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
