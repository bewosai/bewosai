import { useState, useEffect } from "react";
import { sales } from "../api/index";
import { useTranslation } from "../utils/translations";
import { useAppSettings } from "../context/AppSettingsContext";
import { RotateCcw, Plus, Loader } from "lucide-react";

export default function SalesReturnPage() {
  const { t, language } = useTranslation();
  const { dateMode } = useAppSettings();
  const formatDate = (dateStr) => dateStr ? new Date(dateStr).toLocaleDateString("en-GB") : "";
  const [returns, setReturns] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    sales.returns().then((r) => setReturns(r.data?.results ?? r.data ?? [])).catch(() => setReturns([])).finally(() => setLoading(false));
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
            <RotateCcw className="h-6 w-6 text-orange-500" />{t("salesReturn")}
          </h1>
          <p className="mt-1 text-sm text-navy-500">{language === "ne" ? "उत्पादन फिर्ता र स्टक समायोजन" : "Product returns and automatic stock adjustment"}</p>
        </div>
        <button className="flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition">
          <Plus className="h-4 w-4" />{t("newReturn")}
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : returns.length === 0 ? (
        <div className="flex flex-col items-center rounded-2xl border border-navy-800 bg-navy-900 py-16 text-center">
          <RotateCcw className="h-10 w-10 text-navy-600 mb-3" />
          <h3 className="font-semibold text-white">{t("noData")}</h3>
          <p className="mt-1 text-sm text-navy-500">{language === "ne" ? "कुनै फिर्ता रेकर्ड छैन" : "No return records found"}</p>
        </div>
      ) : (
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="divide-y divide-navy-800">
            {returns.map((r) => (
              <div key={r.id} className="flex items-center gap-4 px-5 py-4 hover:bg-navy-800/40 transition">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-orange-100">
                  <RotateCcw className="h-4 w-4 text-orange-600" />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-white text-sm">{t("originalInvoice")}: {r.original_sale}</p>
                  <p className="text-xs text-navy-500 mt-0.5">{formatDate(r.return_date)} · {r.reason || (language === "ne" ? "कारण उल्लेख छैन" : "No reason")}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="font-bold text-red-500">- Rs. {parseFloat(r.amount || 0).toLocaleString("en-IN", { minimumFractionDigits: 2 })}</p>
                  <p className="text-xs text-green-500 mt-0.5">{t("stockAdjusted")}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
