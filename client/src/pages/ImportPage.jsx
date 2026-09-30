import { useState, useRef } from "react";
import { useSearchParams } from "react-router-dom";
import * as XLSX from "xlsx";
import { inventory as inventoryApi, parties as partiesApi } from "../api/index";
import { useTranslation } from "../utils/translations";
import { useAuth } from "../context/AuthContext";
import {
  Upload, Download, FileSpreadsheet, Check, X, AlertTriangle,
  Package, Users, ChevronRight, RefreshCw, Loader, Lock, Crown,
} from "lucide-react";

// Matches the backend's ProductBulkImportView/PartyBulkImportView.MAX_ROWS —
// checked here too so an oversized file is rejected immediately instead of
// only after a round-trip to the server.
const MAX_IMPORT_ROWS = 500;
const MAX_IMPORT_BYTES = 1024 * 1024; // 1MB — matches Flutter's ExcelImportUtils.maxBytes

/* ── helpers ── */
function downloadTemplate(type) {
  let headers, rows, filename;

  if (type === "products") {
    // category/unit are matched (or created) by name on your account — leave
    // blank if a product doesn't need one. hs_code is the Nepal customs/VAT
    // classification code, also optional.
    headers = ["name", "category", "unit", "sale_price", "purchase_price", "secondary_sale_price", "secondary_purchase_price", "stock_quantity", "low_stock_threshold", "barcode", "hs_code", "description"];
    rows = [
      // secondary_* = own price per secondary unit (e.g. per Piece of a Box); leave blank to use price ÷ conversion.
      ["Coca Cola 500ml", "Beverages", "Piece", 60, 45, "", "", 100, 10, "12345678", "22021010", "Cold drink"],
      ["Biscuit Box", "Snacks", "Box", 1200, 1000, 110, 90, 20, 5, "", "", "Box of 12"],
    ];
    filename = "products_template.xlsx";
  } else {
    headers = ["name", "party_type", "phone", "email", "address", "opening_balance"];
    rows = [
      ["Ram Prasad", "CUSTOMER", "9841000001", "ram@example.com", "Kathmandu", 0],
      ["Shyam Suppliers", "SUPPLIER", "9841000002", "", "Pokhara", 5000],
    ];
    filename = "parties_template.xlsx";
  }

  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  ws["!cols"] = headers.map(() => ({ wch: 20 }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, type === "products" ? "Products" : "Parties");
  XLSX.writeFile(wb, filename);
}

// Writes every skipped row back out as .xlsx (original columns + why it was
// skipped) so the user can fix just those rows and re-upload, instead of
// re-checking a whole spreadsheet by hand against a list capped at 5 lines.
function downloadFailedRows(skippedDetails, type) {
  const columns = [...new Set(skippedDetails.flatMap(s => Object.keys(s.row || {})))];
  const headers = [...columns, "reason"];
  const rows = skippedDetails.map(s => [...columns.map(c => s.row?.[c] ?? ""), s.reason]);
  const ws = XLSX.utils.aoa_to_sheet([headers, ...rows]);
  ws["!cols"] = headers.map(() => ({ wch: 20 }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Failed rows");
  XLSX.writeFile(wb, `${type}_import_failed_rows.xlsx`);
}

function parseExcel(file, type) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const wb = XLSX.read(e.target.result, { type: "array" });
        const ws = wb.Sheets[wb.SheetNames[0]];
        const raw = XLSX.utils.sheet_to_json(ws, { defval: "" });
        resolve(raw);
      } catch (err) {
        reject(err);
      }
    };
    reader.onerror = reject;
    reader.readAsArrayBuffer(file);
  });
}

/* ── ImportTab ── */
// Pick a file → the server checks every row against your real data without
// saving (dry run) → preview with All / Ready / Will skip filters and each
// skipped row's reason → "Import N ready rows" creates those and skips the rest.
const FILTERS = [
  { key: "all", label: "All" },
  { key: "ready", label: "Ready" },
  { key: "skipped", label: "Will skip" },
];

function ImportTab({ type }) {
  const { language } = useTranslation();
  const fileRef = useRef(null);
  const [rows, setRows] = useState(null);        // rows as read from the file
  const [checks, setChecks] = useState(null);    // server preview: one result per row, same order
  const [filter, setFilter] = useState("all");
  const [fileName, setFileName] = useState("");
  const [fileError, setFileError] = useState(""); // problems with the file itself
  const [checking, setChecking] = useState(false);
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState(null);    // { created, skipped, skipped_details, results }
  const [dragOver, setDragOver] = useState(false);

  const isProducts = type === "products";
  const noun = isProducts ? "products" : "parties";
  const send = (data, dryRun) =>
    isProducts ? inventoryApi.bulkImportProducts(data, dryRun) : partiesApi.bulkImport(data, dryRun);
  const previewCols = isProducts
    ? ["name", "category", "unit", "sale_price", "purchase_price", "stock_quantity"]
    : ["name", "party_type", "phone", "email", "opening_balance"];

  const colLabel = {
    name: "Name", category: "Category", unit: "Unit", sale_price: "Sale Price", purchase_price: "Buy Price",
    stock_quantity: "Stock", party_type: "Type", phone: "Phone",
    email: "Email", opening_balance: "Opening Bal",
  };

  const reset = () => {
    setRows(null); setChecks(null); setFileName(""); setFileError(""); setResult(null); setFilter("all");
    if (fileRef.current) fileRef.current.value = "";
  };

  const processFile = async (file) => {
    if (!file) return;
    reset();
    setFileName(file.name);
    if (file.size > MAX_IMPORT_BYTES) {
      setFileError(`This file is ${(file.size / (1024 * 1024)).toFixed(1)}MB — only files up to 1MB are supported.`);
      return;
    }
    let parsed;
    try {
      parsed = await parseExcel(file, type);
    } catch {
      setFileError("Could not read file. Make sure it is a valid .xlsx or .xls file.");
      return;
    }
    if (parsed.length === 0) {
      setFileError("This file has no rows under the header. Fill in the template and try again.");
      return;
    }
    if (parsed.length > MAX_IMPORT_ROWS) {
      setFileError(`This file has ${parsed.length} rows — import is limited to ${MAX_IMPORT_ROWS} at a time. Split it into smaller files and import each separately.`);
      return;
    }
    setRows(parsed);
    setChecking(true);
    try {
      // Values go exactly as typed ("1,200" included) — the server reads them.
      const { data } = await send(parsed, true);
      setChecks(data.results || []);
    } catch (e) {
      setFileError(e.response?.data?.error || e.response?.data?.detail || "Couldn't check the file. Please try again.");
    } finally { setChecking(false); }
  };

  const handleFile = (e) => processFile(e.target.files?.[0]);
  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    processFile(e.dataTransfer.files?.[0]);
  };

  const readyCount = checks ? checks.filter(c => c.status === "ready").length : 0;
  const skipCount = checks ? checks.length - readyCount : 0;
  const counts = { all: checks?.length || 0, ready: readyCount, skipped: skipCount };
  const visible = (rows || [])
    .map((row, i) => ({ row, check: checks?.[i] }))
    .filter(({ check }) => filter === "all" || check?.status === filter);

  const doImport = async () => {
    if (!rows?.length || readyCount === 0) return;
    setImporting(true);
    try {
      const { data } = await send(rows, false);
      setResult(data);
      setRows(null); setChecks(null); setFileName("");
    } catch (e) {
      setFileError(e.response?.data?.error || e.response?.data?.detail || "Import failed. Please try again.");
    } finally { setImporting(false); }
  };

  return (
    <div className="space-y-5">
      {/* Download template */}
      <div className="flex items-center justify-between rounded-2xl border border-navy-800 bg-navy-900 px-5 py-4">
        <div>
          <p className="font-semibold text-white text-sm">
            {language === "ne" ? "टेम्पलेट डाउनलोड गर्नुहोस्" : `Download ${isProducts ? "Products" : "Parties"} Template`}
          </p>
          <p className="text-xs text-navy-500 mt-0.5">
            {language === "ne" ? "सही ढाँचा बुझ्नका लागि" : "Fill in the correct format before uploading"}
          </p>
        </div>
        <button onClick={() => downloadTemplate(type)}
          className="flex items-center gap-2 rounded-xl border border-orange-500/40 bg-orange-500/10 px-4 py-2 text-sm font-semibold text-orange-400 hover:bg-orange-500/20 transition">
          <Download className="h-4 w-4" />
          {language === "ne" ? "टेम्पलेट" : "Template (.xlsx)"}
        </button>
      </div>

      {/* Result */}
      {result && (
        <div className="flex items-start gap-3 rounded-2xl border border-green-500/30 bg-green-500/10 px-5 py-4">
          <Check className="h-5 w-5 text-green-400 shrink-0 mt-0.5" />
          <div>
            <p className="font-semibold text-green-400">Import finished</p>
            <p className="text-sm text-navy-400 mt-0.5">
              {result.created} {noun} created.
              {result.skipped > 0 && ` ${result.skipped} row${result.skipped > 1 ? "s" : ""} skipped.`}
            </p>
            {result.skipped_details?.length > 0 && (
              <>
                <ul className="mt-2 max-h-40 space-y-1 overflow-y-auto">
                  {result.skipped_details.map((s, i) => (
                    <li key={i} className="text-xs text-red-400">
                      • Row {s.excel_row ?? "?"}{s.row?.name ? ` (${s.row.name})` : ""}: {s.reason}
                    </li>
                  ))}
                </ul>
                <button
                  onClick={() => downloadFailedRows(result.skipped_details, type)}
                  className="mt-2 flex items-center gap-1.5 text-xs font-semibold text-orange-400 hover:underline"
                >
                  <Download className="h-3.5 w-3.5" /> Download skipped rows to fix &amp; re-upload
                </button>
              </>
            )}
            <button onClick={reset} className="mt-3 block text-xs text-orange-400 hover:underline">Import more</button>
          </div>
        </div>
      )}

      {/* Upload area */}
      {!result && (
        <>
          <div
            onDragOver={e => { e.preventDefault(); setDragOver(true); }}
            onDragLeave={() => setDragOver(false)}
            onDrop={handleDrop}
            onClick={() => fileRef.current?.click()}
            className={`cursor-pointer rounded-2xl border-2 border-dashed p-10 text-center transition ${
              dragOver ? "border-orange-500 bg-orange-500/5" : "border-navy-700 hover:border-orange-500/50"
            }`}
          >
            <input ref={fileRef} type="file" accept=".xlsx,.xls,.csv" className="hidden" onChange={handleFile} />
            <FileSpreadsheet className="mx-auto h-10 w-10 text-navy-600 mb-3" />
            {fileName ? (
              <p className="font-semibold text-white text-sm">{fileName}</p>
            ) : (
              <>
                <p className="font-semibold text-white text-sm">
                  {language === "ne" ? "फाइल छान्नुहोस् वा यहाँ छोड्नुहोस्" : "Click to select or drag & drop file here"}
                </p>
                <p className="text-xs text-navy-500 mt-1">Only Excel files up to {MAX_IMPORT_ROWS} entries & 1MB are supported.</p>
              </>
            )}
          </div>

          {fileError && (
            <div className="flex items-start gap-2 rounded-2xl border border-red-500/30 bg-red-500/10 p-4">
              <AlertTriangle className="h-4 w-4 shrink-0 text-red-400 mt-0.5" />
              <p className="text-sm text-red-300">{fileError}</p>
            </div>
          )}

          {checking && (
            <div className="flex items-center justify-center gap-2 py-6 text-sm text-navy-400">
              <Loader className="h-4 w-4 animate-spin text-orange-500" /> Checking every row…
            </div>
          )}

          {/* Preview with filters */}
          {rows && checks && (
            <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
              <div className="flex flex-wrap items-center justify-between gap-2 border-b border-navy-800 px-5 py-3">
                <div className="flex gap-1 rounded-xl border border-navy-800 bg-navy-950 p-1">
                  {FILTERS.map(f => (
                    <button key={f.key} onClick={() => setFilter(f.key)}
                      className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
                        filter === f.key ? "bg-orange-500 text-white" : "text-navy-400 hover:text-white"
                      }`}>
                      {f.label} ({counts[f.key]})
                    </button>
                  ))}
                </div>
                <button onClick={reset} className="text-xs text-navy-500 hover:text-red-400 flex items-center gap-1">
                  <X className="h-3.5 w-3.5" /> Clear
                </button>
              </div>
              <div className="max-h-[28rem] overflow-auto">
                <table className="w-full text-xs">
                  <thead className="sticky top-0 bg-navy-900">
                    <tr className="border-b border-navy-800">
                      <th className="px-3 py-2 text-left font-semibold text-navy-400">Row</th>
                      <th className="px-3 py-2 text-left font-semibold text-navy-400">Status</th>
                      {previewCols.map(col => (
                        <th key={col} className="px-3 py-2 text-left font-semibold text-navy-400">{colLabel[col] || col}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {visible.map(({ row, check }) => (
                      <tr key={check?.row} className="border-b border-navy-800/50 align-top hover:bg-navy-800/20">
                        <td className="px-3 py-2 text-navy-500">{check?.row}</td>
                        <td className="px-3 py-2">
                          {check?.status === "ready" ? (
                            <span className="rounded bg-green-500/10 px-1.5 py-0.5 font-semibold text-green-400">Ready</span>
                          ) : (
                            <>
                              <span className="rounded bg-red-500/10 px-1.5 py-0.5 font-semibold text-red-400">Will skip</span>
                              <p className="mt-1 max-w-[16rem] text-red-300">{check?.reason}</p>
                            </>
                          )}
                        </td>
                        {previewCols.map(col => (
                          <td key={col} className="px-3 py-2 text-white">{String(row[col] ?? "") || "—"}</td>
                        ))}
                      </tr>
                    ))}
                    {visible.length === 0 && (
                      <tr><td colSpan={previewCols.length + 2} className="px-4 py-6 text-center text-navy-500">No rows here.</td></tr>
                    )}
                  </tbody>
                </table>
              </div>

              <div className="border-t border-navy-800 px-5 py-4 flex flex-wrap items-center justify-between gap-3">
                <p className="text-xs text-navy-500">
                  {readyCount === 0
                    ? "No rows are ready — fix the file and upload it again."
                    : `${readyCount} ready${skipCount ? `, ${skipCount} will be skipped` : ""}.`}
                </p>
                <button
                  disabled={importing || readyCount === 0}
                  onClick={doImport}
                  className="flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition disabled:opacity-50"
                >
                  {importing ? <Loader className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
                  {importing ? "Importing…" : `Import ${readyCount} ready ${readyCount === 1 ? "row" : "rows"}`}
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function UpgradePrompt() {
  const { language } = useTranslation();
  return (
    <div className="flex flex-col items-center justify-center gap-4 rounded-2xl border border-navy-800 bg-navy-900 px-6 py-16 text-center">
      <div className="flex h-14 w-14 items-center justify-center rounded-full bg-orange-500/10">
        <Lock className="h-6 w-6 text-orange-400" />
      </div>
      <div>
        <p className="flex items-center justify-center gap-2 text-lg font-bold text-white">
          <Crown className="h-5 w-5 text-orange-400" />
          {language === "ne" ? "प्रिमियम सुविधा" : "Premium Feature"}
        </p>
        <p className="mt-2 max-w-md text-sm text-navy-400">
          {language === "ne"
            ? "Excel बाट ब्याच आयात प्रिमियम प्लानमा मात्र उपलब्ध छ। थप्न वा हटाउनको लागि आफ्नो प्लान अपग्रेड गर्नुहोस्।"
            : "Bulk import/export from Excel is available on the Premium plan. Upgrade your plan to unlock it."}
        </p>
      </div>
      <a
        href="/settings"
        className="rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition"
      >
        {language === "ne" ? "प्लान अपग्रेड गर्नुहोस्" : "Upgrade Plan"}
      </a>
    </div>
  );
}

export default function ImportPage() {
  const { language } = useTranslation();
  const { currentBusiness } = useAuth();
  const [searchParams] = useSearchParams();
  // Lets Inventory/Parties deep-link straight to the right tab (/import?type=parties)
  // instead of always landing on Products regardless of where the user came from.
  const [activeTab, setActiveTab] = useState(searchParams.get("type") === "parties" ? "parties" : "products");
  // effective_plan so a coupon/referral-granted Premium/PremiumPlus counts
  // too, not just a directly-licensed one — see Business.effective_plan.
  const isPremium = (currentBusiness?.effective_plan || currentBusiness?.plan) !== "FREE";

  const tabs = [
    { key: "products", label: language === "ne" ? "उत्पादनहरू" : "Products", icon: Package },
    { key: "parties", label: language === "ne" ? "पार्टीहरू" : "Parties", icon: Users },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold text-white">
          <FileSpreadsheet className="h-6 w-6 text-orange-500" />
          {language === "ne" ? "Excel बाट डेटा आयात" : "Import from Excel"}
        </h1>
        <p className="mt-1 text-sm text-navy-500">
          {language === "ne"
            ? "Excel फाइलबाट उत्पादन वा पार्टी डेटा ब्याच आयात गर्नुहोस्"
            : "Bulk import products or parties from an Excel spreadsheet"}
        </p>
      </div>

      {/* How it works */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {[
          { step: "1", title: "Download Template", desc: "Get the Excel template with correct column headers" },
          { step: "2", title: "Fill Your Data", desc: "Add your products or parties in the spreadsheet" },
          { step: "3", title: "Upload & Import", desc: "Upload the file and preview before confirming import" },
        ].map(s => (
          <div key={s.step} className="flex items-start gap-3 rounded-xl border border-navy-800 bg-navy-900 px-4 py-3">
            <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-orange-500/20 text-sm font-bold text-orange-400">
              {s.step}
            </div>
            <div>
              <p className="text-sm font-semibold text-white">{s.title}</p>
              <p className="text-xs text-navy-500 mt-0.5">{s.desc}</p>
            </div>
          </div>
        ))}
      </div>

      {!isPremium ? (
        <UpgradePrompt />
      ) : (
        <>
          {/* Tabs */}
          <div className="flex gap-2">
            {tabs.map(({ key, label, icon: Icon }) => (
              <button key={key} onClick={() => setActiveTab(key)}
                className={`flex items-center gap-2 rounded-xl px-5 py-2.5 text-sm font-semibold transition ${
                  activeTab === key
                    ? "bg-orange-500 text-white"
                    : "border border-navy-800 bg-navy-900 text-navy-400 hover:text-white"
                }`}
              >
                <Icon className="h-4 w-4" /> {label}
              </button>
            ))}
          </div>

          <ImportTab key={activeTab} type={activeTab} />
        </>
      )}
    </div>
  );
}
