import { useState, useEffect } from "react";
import { recycleBin } from "../api/index";
import { useTranslation } from "../utils/translations";
import { useDateFormat } from "../context/AppSettingsContext";
import { Trash2, RotateCcw, AlertTriangle, Loader } from "lucide-react";

const TYPE_CONFIG = {
  sale: { label: "Sale", labelNe: "बिक्री", color: "blue" },
  purchase: { label: "Purchase", labelNe: "खरिद", color: "purple" },
  party: { label: "Party", labelNe: "पार्टी", color: "green" },
  expense: { label: "Expense", labelNe: "खर्च", color: "orange" },
};
const COLOR_CLASSES = {
  blue: "bg-blue-100 text-blue-700",
  purple: "bg-purple-100 text-purple-700",
  green: "bg-green-100 text-green-600",
  orange: "bg-orange-100 text-orange-600",
};

function ConfirmDialog({ title, body, onConfirm, onCancel, dangerous }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-sm rounded-2xl border border-navy-800 bg-navy-900 p-6 shadow-2xl">
        <div className={`mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full ${dangerous ? "bg-red-100" : "bg-orange-100"}`}>
          <AlertTriangle className={`h-6 w-6 ${dangerous ? "text-red-500" : "text-orange-500"}`} />
        </div>
        <h3 className="text-center text-base font-bold text-white">{title}</h3>
        <p className="mt-2 text-center text-sm text-navy-400">{body}</p>
        <div className="mt-5 flex gap-3">
          <button onClick={onCancel} className="flex-1 rounded-xl border border-navy-700 py-2.5 text-sm font-medium text-navy-400 hover:bg-navy-800">Cancel</button>
          <button onClick={onConfirm} className={`flex-1 rounded-xl py-2.5 text-sm font-semibold text-white ${dangerous ? "bg-red-500 hover:bg-red-600" : "bg-orange-500 hover:bg-orange-600"}`}>
            {dangerous ? "Delete Forever" : "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function RecycleBinPage() {
  const { t, language } = useTranslation();
  const formatDate = useDateFormat();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [confirm, setConfirm] = useState(null);

  useEffect(() => {
    recycleBin.list().then((r) => setItems(r.data || [])).catch(() => setItems([])).finally(() => setLoading(false));
  }, []);

  const doRestore = async (item) => {
    try { await recycleBin.restore(item.type, item.id); setItems((p) => p.filter((i) => !(i.type === item.type && i.id === item.id))); } catch {}
    setConfirm(null);
  };
  const doDelete = async (item) => {
    try { await recycleBin.permanentDelete(item.type, item.id); setItems((p) => p.filter((i) => !(i.type === item.type && i.id === item.id))); } catch {}
    setConfirm(null);
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
          <Trash2 className="h-6 w-6 text-orange-500" />{t("recycleBin")}
        </h1>
        <p className="mt-1 text-sm text-navy-500">{t("recycleBinDesc")}</p>
      </div>

      {loading ? (
        <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-orange-500" /></div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center rounded-2xl border border-navy-800 bg-navy-900 py-20 text-center">
          <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-navy-800">
            <Trash2 className="h-8 w-8 text-navy-500" />
          </div>
          <h3 className="font-semibold text-white">{t("recycleBinEmpty")}</h3>
          <p className="mt-2 text-sm text-navy-500 max-w-xs px-4">{t("recycleBinDesc")}</p>
        </div>
      ) : (
        <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
          <div className="border-b border-navy-800 px-5 py-3.5">
            <p className="text-sm font-semibold text-white">{items.length} {language === "ne" ? "वस्तुहरू" : "items"}</p>
          </div>
          <div className="divide-y divide-navy-800">
            {items.map((item, idx) => {
              const cfg = TYPE_CONFIG[item.type] || TYPE_CONFIG.sale;
              return (
                <div key={`${item.type}-${item.id}-${idx}`} className="flex items-center gap-4 px-5 py-4 hover:bg-navy-800/40 transition">
                  <span className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold ${COLOR_CLASSES[cfg.color]}`}>
                    {language === "ne" ? cfg.labelNe : cfg.label}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="font-medium text-white text-sm truncate">{item.label}</p>
                    {item.deleted_at && <p className="text-xs text-navy-500 mt-0.5">{t("deletedAt")}: {formatDate(item.deleted_at)}</p>}
                  </div>
                  <div className="flex shrink-0 gap-2">
                    <button onClick={() => setConfirm({ type: "restore", item })} className="flex items-center gap-1.5 rounded-lg border border-green-500/40 px-3 py-1.5 text-xs font-medium text-green-500 hover:bg-green-500/10 transition">
                      <RotateCcw className="h-3.5 w-3.5" />{t("restore")}
                    </button>
                    <button onClick={() => setConfirm({ type: "delete", item })} className="flex items-center gap-1.5 rounded-lg border border-red-500/40 px-3 py-1.5 text-xs font-medium text-red-500 hover:bg-red-500/10 transition">
                      <Trash2 className="h-3.5 w-3.5" />{t("permanentDelete")}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {confirm?.type === "restore" && (
        <ConfirmDialog
          title={language === "ne" ? "पुनर्स्थापना गर्नुहुन्छ?" : "Restore this record?"}
          body={`"${confirm.item.label}" ${language === "ne" ? "पुनर्स्थापना गरिनेछ।" : "will be restored."}`}
          onConfirm={() => doRestore(confirm.item)} onCancel={() => setConfirm(null)} dangerous={false}
        />
      )}
      {confirm?.type === "delete" && (
        <ConfirmDialog
          title={t("permanentDeleteConfirmBody")}
          body={`"${confirm.item.label}" ${language === "ne" ? "सधैंका लागि मेटिनेछ।" : "will be permanently deleted."}`}
          onConfirm={() => doDelete(confirm.item)} onCancel={() => setConfirm(null)} dangerous={true}
        />
      )}
    </div>
  );
}
