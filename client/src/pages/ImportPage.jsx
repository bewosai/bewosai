import { useState, useRef } from "react";
import * as XLSX from "xlsx";
import { inventory as inventoryApi, parties as partiesApi } from "../api/index";
import { useTranslation } from "../utils/translations";
import {
  Upload, Download, FileSpreadsheet, Check, X, AlertTriangle,
  Package, Users, ChevronRight, RefreshCw, Loader,
} from "lucide-react";

/* ── helpers ── */
function downloadTemplate(type) {
  let headers, rows, filename;

  if (type === "products") {
    headers = ["name", "sale_price", "purchase_price", "stock_quantity", "low_stock_threshold", "barcode", "description"];
    rows = [
      ["Coca Cola 500ml", 60, 45, 100, 10, "12345678", "Cold drink"],
      ["Biscuit Pack", 25, 18, 200, 20, "", "Snack item"],
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
function ImportTab({ type }) {
  const { language } = useTranslation();
  const fileRef = useRef(null);
  const [rows, setRows] = useState(null);      // parsed preview rows
  const [fileName, setFileName] = useState("");
  const [errors, setErrors] = useState([]);
  const [importing, setImporting] = useState(false);
  const [result, setResult] = useState(null);  // { created, skipped }
  const [dragOver, setDragOver] = useState(false);

  const isProducts = type === "products";
  const previewCols = isProducts
    ? ["name", "sale_price", "purchase_price", "stock_quantity"]
    : ["name", "party_type", "phone", "email", "opening_balance"];

  const colLabel = {
    name: "Name", sale_price: "Sale Price", purchase_price: "Buy Price",
    stock_quantity: "Stock", party_type: "Type", phone: "Phone",
    email: "Email", opening_balance: "Opening Bal",
  };

  const processFile = async (file) => {
    if (!file) return;
    setResult(null);
    setErrors([]);
    try {
      const parsed = await parseExcel(file, type);
      const errs = [];
      parsed.forEach((r, i) => {
        if (!r.name) errs.push(`Row ${i + 2}: "name" is required`);
        if (isProducts && r.sale_price && isNaN(Number(r.sale_price)))
          errs.push(`Row ${i + 2}: sale_price must be a number`);
        if (!isProducts && r.party_type && !["CUSTOMER", "SUPPLIER", "BOTH"].includes(String(r.party_type).toUpperCase()))
          errs.push(`Row ${i + 2}: party_type must be CUSTOMER, SUPPLIER, or BOTH`);
      });
      setErrors(errs);
      setRows(parsed);
      setFileName(file.name);
    } catch {
      setErrors(["Could not read file. Make sure it is a valid .xlsx or .xls file."]);
    }
  };

  const handleFile = (e) => processFile(e.target.files?.[0]);
  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    processFile(e.dataTransfer.files?.[0]);
  };

  const doImport = async () => {
    if (!rows?.length) return;
    setImporting(true);
    try {
      let res;
      const cleaned = rows.map(r => ({
        ...r,
        party_type: r.party_type ? String(r.party_type).toUpperCase() : "CUSTOMER",
        sale_price: Number(r.sale_price) || 0,
        purchase_price: Number(r.purchase_price) || 0,
        stock_quantity: Number(r.stock_quantity) || 0,
        low_stock_threshold: Number(r.low_stock_threshold) || 5,
        opening_balance: Number(r.opening_balance) || 0,
      }));
      if (isProducts) {
        res = await inventoryApi.bulkImportProducts(cleaned);
      } else {
        res = await partiesApi.bulkImport(cleaned);
      }
      setResult(res.data);
      setRows(null);
      setFileName("");
    } catch (e) {
      setErrors([e.response?.data?.error || "Import failed. Please try again."]);
    } finally { setImporting(false); }
  };

  const reset = () => { setRows(null); setFileName(""); setErrors([]); setResult(null); if (fileRef.current) fileRef.current.value = ""; };

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

      {/* Success result */}
      {result && (
        <div className="flex items-start gap-3 rounded-2xl border border-green-500/30 bg-green-500/10 px-5 py-4">
          <Check className="h-5 w-5 text-green-400 shrink-0 mt-0.5" />
          <div>
            <p className="font-semibold text-green-400">Import Successful!</p>
            <p className="text-sm text-navy-400 mt-0.5">
              {result.created} {isProducts ? "products" : "parties"} created.
              {result.skipped > 0 && ` ${result.skipped} rows skipped.`}
            </p>
            {result.skipped_details?.length > 0 && (
              <ul className="mt-2 space-y-1">
                {result.skipped_details.slice(0, 5).map((s, i) => (
                  <li key={i} className="text-xs text-red-400">• {s.reason} ({s.row?.name || "unknown"})</li>
                ))}
              </ul>
            )}
            <button onClick={reset} className="mt-3 text-xs text-orange-400 hover:underline">Import more</button>
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
                <p className="text-xs text-navy-500 mt-1">.xlsx, .xls, .csv supported</p>
              </>
            )}
          </div>

          {/* Validation errors */}
          {errors.length > 0 && (
            <div className="rounded-2xl border border-red-500/30 bg-red-500/10 p-4">
              <div className="flex items-center gap-2 mb-2">
                <AlertTriangle className="h-4 w-4 text-red-400" />
                <p className="text-sm font-semibold text-red-400">{errors.length} validation issue{errors.length > 1 ? "s" : ""}</p>
              </div>
              <ul className="space-y-1">
                {errors.slice(0, 8).map((e, i) => <li key={i} className="text-xs text-red-300">• {e}</li>)}
                {errors.length > 8 && <li className="text-xs text-red-300">… and {errors.length - 8} more</li>}
              </ul>
            </div>
          )}

          {/* Preview table */}
          {rows && rows.length > 0 && (
            <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
              <div className="flex items-center justify-between border-b border-navy-800 px-5 py-3">
                <p className="text-sm font-semibold text-white">
                  Preview — {rows.length} row{rows.length > 1 ? "s" : ""}
                </p>
                <button onClick={reset} className="text-xs text-navy-500 hover:text-red-400 flex items-center gap-1">
                  <X className="h-3.5 w-3.5" /> Clear
                </button>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-xs">
                  <thead>
                    <tr className="border-b border-navy-800 bg-navy-900/80">
                      {previewCols.map(col => (
                        <th key={col} className="px-4 py-2 text-left font-semibold text-navy-400">{colLabel[col] || col}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.slice(0, 10).map((row, i) => (
                      <tr key={i} className="border-b border-navy-800/50 hover:bg-navy-800/20">
                        {previewCols.map(col => (
                          <td key={col} className="px-4 py-2 text-white">{row[col] ?? "—"}</td>
                        ))}
                      </tr>
                    ))}
                    {rows.length > 10 && (
                      <tr>
                        <td colSpan={previewCols.length} className="px-4 py-2 text-center text-xs text-navy-500">
                          … and {rows.length - 10} more rows
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>

              <div className="border-t border-navy-800 px-5 py-4 flex items-center justify-between">
                <p className="text-xs text-navy-500">
                  {errors.length > 0
                    ? `Fix ${errors.length} error(s) before importing`
                    : `Ready to import ${rows.length} ${isProducts ? "products" : "parties"}`}
                </p>
                <button
                  disabled={importing || errors.length > 0}
                  onClick={doImport}
                  className="flex items-center gap-2 rounded-xl bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition disabled:opacity-50"
                >
                  {importing ? <Loader className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
                  {importing ? "Importing…" : `Import ${rows.length} rows`}
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default function ImportPage() {
  const { language } = useTranslation();
  const [activeTab, setActiveTab] = useState("products");

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
    </div>
  );
}
