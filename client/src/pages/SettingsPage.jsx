import { useState, useRef, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAppSettings } from "../context/AppSettingsContext";
import { useTranslation } from "../utils/translations";
import { useAuth } from "../context/AuthContext";
import { auth as authApi, support as supportApi } from "../api";
import {
  Sun, Moon, Globe, Eye, EyeOff, Calendar, Building2,
  Upload, Save, Bell, Shield, Palette, User, Check, FileText, BarChart3, ChevronRight, ChevronDown,
  FileSpreadsheet, Crown, Archive, Loader, AlertCircle, MessageSquare, Send,
} from "lucide-react";
import PhoneInput from "../components/common/PhoneInput";
import ConfirmDialog from "../components/common/ConfirmDialog";

function SettingCard({ title, icon: Icon, children }) {
  return (
    <div className="rounded-2xl border border-navy-800 bg-navy-900 overflow-hidden">
      <div className="flex items-center gap-3 border-b border-navy-800 px-5 py-4">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-orange-500/15">
          <Icon className="h-4 w-4 text-orange-500" />
        </div>
        <h2 className="font-semibold text-white">{title}</h2>
      </div>
      <div className="p-5 space-y-4">{children}</div>
    </div>
  );
}

function ToggleRow({ label, description, value, onChange }) {
  return (
    <div className="flex items-center justify-between py-1">
      <div>
        <p className="text-sm font-medium text-white">{label}</p>
        {description && <p className="text-xs text-navy-500 mt-0.5">{description}</p>}
      </div>
      <button
        onClick={() => onChange(!value)}
        className={`relative h-6 w-11 rounded-full transition-colors ${value ? "bg-orange-500" : "bg-navy-700"}`}
      >
        <span className={`absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white transition-transform ${value ? "translate-x-5" : ""}`} />
      </button>
    </div>
  );
}

function SelectRow({ label, value, options, onChange }) {
  return (
    <div className="flex items-center justify-between py-1">
      <p className="text-sm font-medium text-white">{label}</p>
      <div className="flex gap-1.5">
        {options.map((opt) => (
          <button
            key={opt.value}
            onClick={() => onChange(opt.value)}
            className={`rounded-lg px-3 py-1.5 text-xs font-medium transition ${
              value === opt.value
                ? "bg-orange-500 text-white"
                : "bg-navy-800 text-navy-400 hover:bg-navy-700 hover:text-white"
            }`}
          >
            {opt.label}
          </button>
        ))}
      </div>
    </div>
  );
}

const STATUS_META = {
  OPEN: { label: "Open", color: "text-yellow-400 bg-yellow-500/10" },
  IN_PROGRESS: { label: "In Progress", color: "text-blue-400 bg-blue-500/10" },
  CLOSED: { label: "Closed", color: "text-navy-400 bg-navy-800" },
};

/* ── Comments / feedback — any user can leave one, and see their own reply
   status; Super Admin sees every comment, by user, in Support Tickets. ── */
function CommentsCard({ language }) {
  const [comments, setComments] = useState([]);
  const [loadingComments, setLoadingComments] = useState(true);
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [sent, setSent] = useState(false);

  const load = () => {
    setLoadingComments(true);
    supportApi.myComments()
      .then((r) => setComments(r.data?.results ?? r.data ?? []))
      .catch(() => setComments([]))
      .finally(() => setLoadingComments(false));
  };

  useEffect(load, []);

  const submit = async (e) => {
    e.preventDefault();
    if (!message.trim()) return;
    setSending(true);
    setError("");
    try {
      await supportApi.submit({
        subject: message.trim().slice(0, 60),
        message: message.trim(),
      });
      setMessage("");
      setSent(true);
      setTimeout(() => setSent(false), 2500);
      load();
    } catch (err) {
      setError(err.response?.data?.message || err.response?.data?.detail || "Couldn't send your comment.");
    } finally {
      setSending(false);
    }
  };

  return (
    <SettingCard title={language === "ne" ? "टिप्पणी / प्रतिक्रिया" : "Comments & Feedback"} icon={MessageSquare}>
      <form onSubmit={submit} className="space-y-2">
        <textarea
          rows={3}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder={language === "ne" ? "तपाईंको प्रश्न वा प्रतिक्रिया लेख्नुहोस्…" : "Ask a question, report an issue, or leave feedback…"}
          className="w-full resize-none rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
        />
        <div className="flex items-center justify-between">
          {sent ? (
            <p className="flex items-center gap-1.5 text-xs text-green-400"><Check className="h-3.5 w-3.5" /> Sent — Super Admin will get back to you here.</p>
          ) : error ? (
            <p className="text-xs text-red-400">{error}</p>
          ) : <span />}
          <button
            type="submit"
            disabled={sending || !message.trim()}
            className="flex items-center gap-1.5 rounded-lg bg-orange-500 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-orange-600 disabled:opacity-50"
          >
            <Send className="h-3.5 w-3.5" /> {sending ? "Sending…" : "Send"}
          </button>
        </div>
      </form>

      {loadingComments ? (
        <div className="flex justify-center py-3"><Loader className="h-4 w-4 animate-spin text-orange-500" /></div>
      ) : comments.length > 0 && (
        <div className="mt-2 space-y-2 border-t border-navy-800 pt-3">
          <p className="text-xs font-semibold text-navy-400">{language === "ne" ? "तपाईंका टिप्पणीहरू" : "Your comments"}</p>
          {comments.map((c) => {
            const meta = STATUS_META[c.status] || STATUS_META.OPEN;
            return (
              <div key={c.id} className="rounded-lg border border-navy-800 bg-navy-950 px-3 py-2.5">
                <div className="flex items-start justify-between gap-2">
                  <p className="text-xs text-navy-300">{c.message}</p>
                  <span className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold ${meta.color}`}>{meta.label}</span>
                </div>
                {c.admin_reply && (
                  <p className="mt-1.5 text-xs text-green-400">↳ {c.admin_reply}</p>
                )}
                <p className="mt-1 text-[10px] text-navy-600">{new Date(c.created_at).toLocaleDateString()}</p>
              </div>
            );
          })}
        </div>
      )}
    </SettingCard>
  );
}

const SECTIONS = [
  { key: "account",       icon: User,           label: { en: "Account", ne: "खाता" } },
  { key: "business",      icon: Building2,      label: { en: "Business", ne: "व्यवसाय" } },
  { key: "billing",       icon: Crown,          label: { en: "Billing & Plan", ne: "बिलिङ र योजना" } },
  { key: "appearance",    icon: Palette,        label: { en: "Appearance & Invoices", ne: "रूप र बिजक" } },
  { key: "data",          icon: FileSpreadsheet, label: { en: "Data & Reports", ne: "डेटा र प्रतिवेदन" } },
  { key: "notifications", icon: Bell,           label: { en: "Notifications", ne: "सूचना" } },
  { key: "support",       icon: MessageSquare,  label: { en: "Support", ne: "सहयोग" } },
];

/* ── Section picker — a dropdown instead of a dozen SettingCards stacked
   in one long scroll, so a viewer lands on exactly the group they want. ── */
function SectionDropdown({ section, setSection, language }) {
  const [open, setOpen] = useState(false);
  const active = SECTIONS.find((s) => s.key === section) || SECTIONS[0];
  const ActiveIcon = active.icon;

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between gap-2 rounded-xl border border-navy-700 bg-navy-900 px-4 py-3 text-left transition hover:border-orange-500/40 sm:w-72"
      >
        <span className="flex items-center gap-2.5">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-orange-500/15">
            <ActiveIcon className="h-4 w-4 text-orange-500" />
          </span>
          <span className="text-sm font-semibold text-white">{active.label[language] || active.label.en}</span>
        </span>
        <ChevronDown className={`h-4 w-4 shrink-0 text-navy-500 transition-transform ${open ? "rotate-180" : ""}`} />
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute left-0 top-full z-20 mt-1.5 w-full min-w-[16rem] rounded-xl border border-navy-700 bg-navy-900 p-1.5 shadow-2xl">
            {SECTIONS.map((s) => {
              const Icon = s.icon;
              const isActive = s.key === section;
              return (
                <button
                  key={s.key}
                  onClick={() => { setSection(s.key); setOpen(false); }}
                  className={`flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left text-sm transition ${
                    isActive ? "bg-orange-500/15 font-semibold text-orange-400" : "text-navy-300 hover:bg-navy-800 hover:text-white"
                  }`}
                >
                  <Icon className="h-4 w-4 shrink-0" />
                  {s.label[language] || s.label.en}
                </button>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

export default function SettingsPage() {
  const { theme, language, privateMode, dateMode, currency,
          toggleTheme, toggleLanguage, togglePrivateMode, toggleDateMode,
          setTheme, setLanguage, setDateMode, setCurrency } = useAppSettings();
  const { t } = useTranslation();
  const { currentBusiness, user, updateBusinessInList } = useAuth();
  const navigate = useNavigate();
  const [section, setSection] = useState("account");
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  const [showCloseFiscalYear, setShowCloseFiscalYear] = useState(false);
  const [closingFiscalYear, setClosingFiscalYear] = useState(false);
  const [fiscalYearError, setFiscalYearError] = useState("");
  const [fiscalYears, setFiscalYears] = useState([]);
  const [fiscalYearsLoading, setFiscalYearsLoading] = useState(true);
  const [profileForm, setProfileForm] = useState({ name: user?.name || "", phone: user?.phone || "" });
  const [invoiceForm, setInvoiceForm] = useState({
    header_color: localStorage.getItem("invoice_header_color") || "#f97316",
    footer_text: localStorage.getItem("invoice_footer_text") || "Thank you for your business!",
    invoice_prefix: localStorage.getItem("invoice_prefix") || "INV-",
    terms_text: localStorage.getItem("invoice_terms_text") || "",
    warranty_text: localStorage.getItem("invoice_warranty_text") || "",
  });
  const [logoPreview, setLogoPreview] = useState(currentBusiness?.logo || null);
  const [logoFile, setLogoFile] = useState(null);
  const logoRef = useRef(null);
  const [businessForm, setBusinessForm] = useState({
    name: currentBusiness?.name || "",
    address: currentBusiness?.address || "",
    phone: currentBusiness?.phone || "",
    email: currentBusiness?.email || "",
    business_type: currentBusiness?.business_type || "",
    default_tax_rate: currentBusiness?.default_tax_rate ?? 13,
  });

  const handleLogoUpload = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setLogoFile(file);
    setLogoPreview(URL.createObjectURL(file));
  };

  const handleSave = async () => {
    setSaving(true);
    setSaveError("");
    const errors = [];
    try {
      await authApi.updateMe(profileForm);
    } catch (e) {
      const data = e.response?.data;
      errors.push(
        data?.phone?.[0] || data?.error || data?.detail ||
        (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null) ||
        "Couldn't save your profile."
      );
    }
    if (currentBusiness?.id) {
      try {
        let payload = businessForm;
        if (logoFile) {
          const form = new FormData();
          Object.entries(businessForm).forEach(([k, v]) => form.append(k, v ?? ""));
          form.append("logo", logoFile);
          payload = form;
        }
        const { data } = await authApi.updateBusiness(currentBusiness.id, payload);
        updateBusinessInList?.(data);
        setLogoFile(null);
        setLogoPreview(data.logo || null);
      } catch (e) {
        const data = e.response?.data;
        errors.push(
          data?.error || data?.detail ||
          (data && typeof data === "object" ? Object.values(data).flat().join(" ") : null) ||
          "Couldn't save business details."
        );
      }
    }
    localStorage.setItem("invoice_header_color", invoiceForm.header_color);
    localStorage.setItem("invoice_footer_text", invoiceForm.footer_text);
    localStorage.setItem("invoice_prefix", invoiceForm.invoice_prefix);
    localStorage.setItem("invoice_terms_text", invoiceForm.terms_text);
    localStorage.setItem("invoice_warranty_text", invoiceForm.warranty_text);
    if (businessForm.name) localStorage.setItem("business_name", businessForm.name);
    if (businessForm.address) localStorage.setItem("business_address", businessForm.address);
    if (businessForm.phone) localStorage.setItem("business_phone", businessForm.phone);
    setSaving(false);
    if (errors.length) {
      setSaveError(errors.join(" "));
    } else {
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    }
  };

  const loadFiscalYears = () => {
    if (!currentBusiness?.id) return;
    setFiscalYearsLoading(true);
    authApi.fiscalYears(currentBusiness.id)
      .then((r) => setFiscalYears(r.data?.results ?? r.data ?? []))
      .catch(() => setFiscalYears([]))
      .finally(() => setFiscalYearsLoading(false));
  };

  useEffect(loadFiscalYears, [currentBusiness?.id]);

  const handleCloseFiscalYear = async () => {
    if (!currentBusiness?.id) return;
    setClosingFiscalYear(true);
    setFiscalYearError("");
    try {
      await authApi.closeFiscalYear(currentBusiness.id);
      setShowCloseFiscalYear(false);
      loadFiscalYears();
    } catch (e) {
      setFiscalYearError(e.response?.data?.error || "Couldn't close the fiscal year.");
    } finally {
      setClosingFiscalYear(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">{t("appSettings")}</h1>
          <p className="text-sm text-navy-500 mt-1">
            {language === "ne" ? "आफ्नो अनुभव अनुकूलन गर्नुहोस्" : "Customize your app experience"}
          </p>
        </div>
        <button
          onClick={handleSave}
          className={`flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition ${
            saved ? "bg-green-500 text-white" : "bg-orange-500 hover:bg-orange-600 text-white"
          }`}
        >
          {saved ? <Check className="h-4 w-4" /> : <Save className="h-4 w-4" />}
          {saving ? (language === "ne" ? "सुरक्षित…" : "Saving…") : saved ? (language === "ne" ? "सुरक्षित!" : "Saved!") : t("saveSettings")}
        </button>
      </div>

      {saveError && (
        <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-400">
          {saveError}
        </div>
      )}

      <SectionDropdown section={section} setSection={setSection} language={language} />

      <div className="grid gap-5 lg:grid-cols-2">
        {/* Upgrade Plan / Refer & Earn */}
        {section === "billing" && (
        <SettingCard title={language === "ne" ? "योजना अपग्रेड" : "Upgrade Plan"} icon={Crown}>
          <button
            onClick={() => navigate("/settings/upgrade")}
            className="flex w-full items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3 text-left transition hover:border-orange-500/50"
          >
            <div>
              <p className="text-sm font-medium text-white">
                {language === "ne" ? "योजना र रेफर एण्ड अर्न" : "Plan & Refer and Earn"}
              </p>
              <p className="text-xs text-navy-500 mt-0.5">
                {language === "ne"
                  ? "कुपन प्रयोग गर्नुहोस् वा मित्रलाई रेफर गरेर प्रिमियम कमाउनुहोस्"
                  : "Apply a coupon, or refer a friend to earn free Premium"}
              </p>
            </div>
            <ChevronRight className="h-4 w-4 text-navy-500 shrink-0" />
          </button>
        </SettingCard>
        )}

        {/* View Report */}
        {section === "data" && (
        <SettingCard title={language === "ne" ? "प्रतिवेदन" : "Reports"} icon={BarChart3}>
          <button
            onClick={() => navigate(user?.account_type === "personal" ? "/personal/reports" : "/reports")}
            className="flex w-full items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3 text-left transition hover:border-orange-500/50"
          >
            <div>
              <p className="text-sm font-medium text-white">
                {language === "ne" ? "प्रतिवेदन हेर्नुहोस्" : "View Report"}
              </p>
              <p className="text-xs text-navy-500 mt-0.5">
                {language === "ne"
                  ? "स्टक, बिक्री, नगद, बैंक र थप प्रतिवेदनहरू"
                  : "Stock, sales, cash, bank statements & more"}
              </p>
            </div>
            <ChevronRight className="h-4 w-4 text-navy-500 shrink-0" />
          </button>
        </SettingCard>
        )}

        {/* Bulk Import */}
        {section === "data" && (
        <SettingCard title={language === "ne" ? "ब्याच आयात" : "Bulk Import"} icon={FileSpreadsheet}>
          <button
            onClick={() => navigate("/import")}
            className="flex w-full items-center justify-between rounded-xl border border-navy-800 bg-navy-950 px-4 py-3 text-left transition hover:border-orange-500/50"
          >
            <div>
              <p className="text-sm font-medium text-white">
                {language === "ne" ? "Excel बाट आयात गर्नुहोस्" : "Import from Excel"}
              </p>
              <p className="text-xs text-navy-500 mt-0.5">
                {language === "ne"
                  ? "उत्पादन वा पार्टीहरू ब्याचमा थप्नुहोस्"
                  : "Add many products or parties at once"}
              </p>
            </div>
            <ChevronRight className="h-4 w-4 text-navy-500 shrink-0" />
          </button>
        </SettingCard>
        )}

        {/* Appearance */}
        {section === "appearance" && (
        <SettingCard title={language === "ne" ? "रूप र थिम" : "Appearance & Theme"} icon={Palette}>
          <SelectRow
            label={t("theme")}
            value={theme}
            options={[
              { value: "light", label: t("lightMode") },
              { value: "dark", label: t("darkMode") },
            ]}
            onChange={setTheme}
          />
          <div className="border-t border-navy-800 pt-3">
            <SelectRow
              label={t("language")}
              value={language}
              options={[
                { value: "en", label: "English" },
                { value: "ne", label: "नेपाली" },
              ]}
              onChange={setLanguage}
            />
          </div>
          <div className="border-t border-navy-800 pt-3">
            <SelectRow
              label={t("dateFormat")}
              value={dateMode}
              options={[
                { value: "AD", label: "AD" },
                { value: "BS", label: "BS" },
              ]}
              onChange={setDateMode}
            />
            <p className="text-xs text-navy-500 mt-2">
              {dateMode === "BS"
                ? (language === "ne" ? "सबै मितिहरू BS (बिक्रम सम्बत) मा देखाइनेछन्" : "All dates shown in BS (Bikram Sambat)")
                : (language === "ne" ? "सबै मितिहरू AD (ग्रेगोरियन) मा देखाइनेछन्" : "All dates shown in AD (Gregorian)")}
            </p>
          </div>
          <div className="border-t border-navy-800 pt-3">
            <SelectRow
              label={t("currency")}
              value={currency}
              options={[
                { value: "Rs.", label: "Rs. (NPR)" },
                { value: "USD", label: "$ (USD)" },
              ]}
              onChange={setCurrency}
            />
          </div>
        </SettingCard>
        )}

        {/* Privacy & Security */}
        {section === "account" && (
        <SettingCard title={language === "ne" ? "गोपनीयता र सुरक्षा" : "Privacy & Security"} icon={Shield}>
          <ToggleRow
            label={t("privateMode")}
            description={t("privateModeDesc")}
            value={privateMode}
            onChange={togglePrivateMode}
          />
          {privateMode && (
            <div className="rounded-xl bg-orange-500/10 border border-orange-500/20 px-4 py-3">
              <p className="text-sm font-semibold text-orange-500">
                {language === "ne" ? "निजी मोड सक्रिय" : "Private Mode Active"}
              </p>
              <p className="text-xs text-navy-400 mt-1">
                {language === "ne"
                  ? "सबै रकमहरू XXXXX को रूपमा देखाइनेछ"
                  : "All monetary amounts are shown as XXXXX"}
              </p>
            </div>
          )}
          <div className="border-t border-navy-800 pt-3">
            <p className="text-sm font-medium text-white mb-1">
              {language === "ne" ? "लगइन विधि" : "Login Method"}
            </p>
            <div className="flex items-center gap-2 rounded-xl bg-navy-800 px-3 py-2.5">
              <div className="h-2 w-2 rounded-full bg-green-500" />
              <p className="text-sm text-navy-400">
                {language === "ne" ? "OTP मार्फत इमेल — सुरक्षित" : "Email OTP — Secure"}
              </p>
            </div>
          </div>
        </SettingCard>
        )}

        {/* Business Info */}
        {section === "business" && (
        <SettingCard title={t("businessInfo")} icon={Building2}>
          <div className="space-y-3">
            {[
              { key: "name", label: t("businessName"), placeholder: "My Business" },
              { key: "business_type", label: t("businessType"), placeholder: "Retail, Wholesale..." },
              { key: "address", label: t("address"), placeholder: "Kathmandu, Nepal" },
            ].map(({ key, label, placeholder }) => (
              <div key={key}>
                <label className="mb-1 block text-xs font-medium text-navy-400">{label}</label>
                <input
                  value={businessForm[key]}
                  onChange={(e) => setBusinessForm((f) => ({ ...f, [key]: e.target.value }))}
                  placeholder={placeholder}
                  className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                />
              </div>
            ))}
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">{t("phone")}</label>
              <PhoneInput value={businessForm.phone} onChange={(phone) => setBusinessForm((f) => ({ ...f, phone }))} />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">
                {language === "ne" ? "पूर्वनिर्धारित कर दर (%)" : "Default Tax Rate (%)"}
              </label>
              <input
                type="number" min="0" max="100" step="0.01"
                value={businessForm.default_tax_rate}
                onChange={(e) => setBusinessForm((f) => ({ ...f, default_tax_rate: parseFloat(e.target.value) || 0 }))}
                placeholder="13"
                className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
              <p className="mt-1 text-[11px] text-navy-500">
                {language === "ne" ? "नयाँ बिक्रीमा पूर्वनिर्धारित रूपमा लागू हुनेछ (उदाहरणका लागि VAT १३%)।" : "Applied by default to new sales (e.g. VAT 13%)."}
              </p>
            </div>
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-navy-400">{t("businessLogo")}</label>
            <input ref={logoRef} type="file" accept="image/*" className="hidden" onChange={handleLogoUpload} />
            {logoPreview ? (
              <div className="flex items-center gap-3">
                <img src={logoPreview} alt="Logo" className="h-14 w-14 rounded-xl object-cover border border-navy-700" />
                <div className="space-y-1">
                  <p className="text-xs text-green-400">Logo uploaded</p>
                  <button onClick={() => logoRef.current?.click()} className="text-xs text-orange-400 hover:underline">Change</button>
                  <button onClick={() => { setLogoPreview(null); setLogoFile(null); }} className="ml-2 text-xs text-red-400 hover:underline">Remove</button>
                </div>
              </div>
            ) : (
              <label className="flex cursor-pointer items-center gap-3 rounded-xl border border-dashed border-navy-700 px-4 py-3 hover:border-orange-500 transition">
                <Upload className="h-5 w-5 text-navy-500" />
                <span className="text-sm text-navy-500">{t("uploadLogo")}</span>
                <input type="file" accept="image/*" className="hidden" onChange={handleLogoUpload} />
              </label>
            )}
          </div>
        </SettingCard>
        )}

        {/* Fiscal Year */}
        {section === "business" && (
        <SettingCard title={language === "ne" ? "आर्थिक वर्ष" : "Fiscal Year"} icon={Calendar}>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-navy-300">
                {language === "ne"
                  ? "हालको आर्थिक वर्ष बन्द गर्नुहोस्। बिक्री, खरिद, खर्च आदि यहीं रहन्छन् — केवल पढ्न मात्र मिल्ने हुन्छन्; तपाईं अझै पनि पुरानो डेटा हेर्न र खोज्न सक्नुहुन्छ।"
                  : "Closes the current fiscal year. Your sales, purchases, expenses, etc. all stay right here — they just become read-only. You can still view and search old data anytime."}
              </p>
              <p className="mt-1.5 text-xs text-navy-500">
                {language === "ne" ? "यो पूर्ववत गर्न सकिँदैन।" : "This can't be undone."}
              </p>
            </div>
            <button
              onClick={() => { setFiscalYearError(""); setShowCloseFiscalYear(true); }}
              disabled={!currentBusiness?.id}
              className="flex shrink-0 items-center gap-1.5 rounded-xl border border-red-500/30 px-3 py-2 text-xs font-semibold text-red-400 transition hover:bg-red-500/10 disabled:opacity-50"
            >
              <Archive className="h-3.5 w-3.5" />
              {language === "ne" ? "आर्थिक वर्ष बन्द गर्नुहोस्" : "Close Fiscal Year"}
            </button>
          </div>
          {fiscalYearError && !showCloseFiscalYear && (
            <p className="mt-3 flex items-center gap-1.5 text-xs text-red-400">
              <AlertCircle className="h-3.5 w-3.5" /> {fiscalYearError}
            </p>
          )}

          {fiscalYearsLoading ? (
            <div className="mt-4 flex justify-center border-t border-navy-800 pt-3">
              <Loader className="h-4 w-4 animate-spin text-orange-500" />
            </div>
          ) : fiscalYears.length > 0 && (
            <div className="mt-4 space-y-1.5 border-t border-navy-800 pt-3">
              <p className="text-xs font-semibold text-navy-400">
                {language === "ne" ? "बन्द भएका आर्थिक वर्षहरू" : "Closed fiscal years"}
              </p>
              {fiscalYears.map((fy) => (
                <div key={fy.id} className="flex items-center justify-between rounded-lg border border-navy-800 bg-navy-950 px-3 py-2">
                  <div>
                    <p className="text-sm font-medium text-white">{fy.label}</p>
                    <p className="text-[11px] text-navy-500">{fy.start_date} — {fy.end_date}</p>
                  </div>
                  <span className="rounded-full bg-navy-800 px-2 py-0.5 text-[10px] font-semibold text-navy-400">
                    {language === "ne" ? "बन्द 🔒" : "Closed 🔒"}
                  </span>
                </div>
              ))}
            </div>
          )}
        </SettingCard>
        )}

        {/* Invoice Customization */}
        {section === "appearance" && (
        <SettingCard title={language === "ne" ? "बिजक अनुकूलन" : "Invoice Customization"} icon={FileText}>
          <div className="space-y-4">
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">Header Color</label>
              <div className="flex items-center gap-3">
                <input
                  type="color"
                  value={invoiceForm.header_color}
                  onChange={e => setInvoiceForm(f => ({ ...f, header_color: e.target.value }))}
                  className="h-9 w-14 cursor-pointer rounded-lg border border-navy-700 bg-navy-800 p-1"
                />
                <div className="flex gap-2">
                  {["#f97316", "#3b82f6", "#22c55e", "#8b5cf6", "#ef4444", "#1e293b"].map(c => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => setInvoiceForm(f => ({ ...f, header_color: c }))}
                      className={`h-7 w-7 rounded-full border-2 transition ${invoiceForm.header_color === c ? "border-white scale-110" : "border-transparent"}`}
                      style={{ backgroundColor: c }}
                    />
                  ))}
                </div>
              </div>
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">Invoice Prefix</label>
              <input
                value={invoiceForm.invoice_prefix}
                onChange={e => setInvoiceForm(f => ({ ...f, invoice_prefix: e.target.value }))}
                placeholder="INV-"
                className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
              <p className="mt-1 text-xs text-navy-500">e.g. Invoice numbers will appear as {invoiceForm.invoice_prefix}001</p>
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">Invoice Footer Text</label>
              <textarea
                rows={2}
                value={invoiceForm.footer_text}
                onChange={e => setInvoiceForm(f => ({ ...f, footer_text: e.target.value }))}
                placeholder="Thank you for your business!"
                className="w-full resize-none rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mb-1 block text-xs font-medium text-navy-400">Terms & Conditions</label>
                <input
                  value={invoiceForm.terms_text}
                  onChange={e => setInvoiceForm(f => ({ ...f, terms_text: e.target.value }))}
                  placeholder="Payment must be made within 7 days"
                  className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-navy-400">Warranty</label>
                <input
                  value={invoiceForm.warranty_text}
                  onChange={e => setInvoiceForm(f => ({ ...f, warranty_text: e.target.value }))}
                  placeholder="e.g. 15 Days Full"
                  className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
                />
              </div>
              <p className="col-span-2 -mt-1 text-xs text-navy-500">Shown on printed invoices/bills when filled in. Leave blank to hide.</p>
            </div>
            <div
              className="rounded-xl border p-4"
              style={{ borderColor: invoiceForm.header_color + "40", backgroundColor: invoiceForm.header_color + "10" }}
            >
              <p className="text-xs font-semibold mb-1" style={{ color: invoiceForm.header_color }}>Preview</p>
              <div className="flex items-center justify-between">
                {logoPreview && <img src={logoPreview} alt="logo" className="h-8 w-8 rounded object-cover" />}
                <p className="text-xs text-white font-bold">{businessForm.name || "Your Business"}</p>
                <span className="text-xs font-bold" style={{ color: invoiceForm.header_color }}>INVOICE</span>
              </div>
              <p className="mt-2 text-[10px] text-navy-500 text-center italic">{invoiceForm.footer_text}</p>
            </div>
          </div>
        </SettingCard>
        )}

        {/* User Profile */}
        {section === "account" && (
        <SettingCard title={language === "ne" ? "प्रयोगकर्ता प्रोफाइल" : "User Profile"} icon={User}>
          <div className="flex items-center gap-4 mb-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-orange-500/20 text-xl font-bold text-orange-500">
              {(user?.name || user?.email || "U")[0].toUpperCase()}
            </div>
            <div>
              <p className="font-semibold text-white">{user?.name || "User"}</p>
              <p className="text-sm text-navy-500">{user?.email}</p>
              <span className="inline-block mt-1 rounded-full bg-green-100 px-2 py-0.5 text-xs text-green-600 font-medium">
                {language === "ne" ? "प्रमाणित" : "Verified"}
              </span>
            </div>
          </div>
          <div className="space-y-3">
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">
                {language === "ne" ? "पूरा नाम" : "Full Name"}
              </label>
              <input
                value={profileForm.name}
                onChange={e => setProfileForm(f => ({ ...f, name: e.target.value }))}
                placeholder="Your name"
                className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">
                {language === "ne" ? "फोन नम्बर" : "Phone Number"}
              </label>
              <PhoneInput value={profileForm.phone} onChange={(phone) => setProfileForm(f => ({ ...f, phone }))} />
            </div>
          </div>
        </SettingCard>
        )}

        {/* Tax Configuration */}
        {section === "business" && (
        <SettingCard title={language === "ne" ? "कर कन्फिगरेसन" : "Tax Configuration"} icon={Shield}>
          <div className="rounded-xl bg-navy-800 p-4">
            <div className="flex items-start gap-3">
              <div className="flex h-6 w-6 items-center justify-center rounded-full bg-green-500/20 mt-0.5">
                <Check className="h-3.5 w-3.5 text-green-500" />
              </div>
              <div>
                <p className="text-sm font-semibold text-white">
                  {language === "ne" ? "VAT बन्द छ" : "No VAT / Tax"}
                </p>
                <p className="text-xs text-navy-500 mt-1">
                  {language === "ne"
                    ? "यो एप आन्तरिक व्यापार व्यवस्थापनको लागि हो। कुनै कर गणना गरिँदैन।"
                    : "This app is for internal business management only. No tax calculations are applied to invoices."}
                </p>
              </div>
            </div>
          </div>
        </SettingCard>
        )}

        {/* Notifications */}
        {section === "notifications" && (
        <SettingCard title={t("notification")} icon={Bell}>
          <ToggleRow
            label={language === "ne" ? "कम स्टक सूचना" : "Low Stock Alerts"}
            description={language === "ne" ? "स्टक न्यूनतम स्तरमा पुगेमा" : "When stock reaches minimum level"}
            value={true}
            onChange={() => {}}
          />
          <div className="border-t border-navy-800 pt-3">
            <ToggleRow
              label={language === "ne" ? "भुक्तानी स्मरण" : "Payment Reminders"}
              description={language === "ne" ? "बाँकी भुक्तानी अनुस्मारक" : "Due payment notifications"}
              value={true}
              onChange={() => {}}
            />
          </div>
          <div className="border-t border-navy-800 pt-3">
            <ToggleRow
              label={language === "ne" ? "म्याद नाघेको बिल सूचना" : "Overdue Bill Notifications"}
              description={language === "ne" ? "म्याद नाघेका बिलहरूको सूचना" : "Alerts for overdue bills"}
              value={true}
              onChange={() => {}}
            />
          </div>
        </SettingCard>
        )}

        {section === "support" && <CommentsCard language={language} />}
      </div>

      {/* App Info */}
      <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-semibold text-white">Bewosai Business Suite</p>
            <p className="text-xs text-navy-500 mt-1">Version 2.0 · {language === "ne" ? "सबै अधिकार सुरक्षित" : "All rights reserved"}</p>
          </div>
          <div className="text-right">
            <p className="text-xs text-navy-500">
              {language === "ne" ? "निर्मित" : "Made with"} ❤️ {language === "ne" ? "नेपालमा" : "in Nepal"}
            </p>
            <p className="text-xs text-orange-500 mt-1">bewosai.com</p>
          </div>
        </div>
      </div>

      {showCloseFiscalYear && (
        <ConfirmDialog
          message={
            <span>
              {language === "ne"
                ? `"${currentBusiness?.name}" को हालको आर्थिक वर्ष बन्द गर्ने हो? यसमा भएका सबै रेकर्ड पढ्न मात्र मिल्ने हुनेछन् — डेटा मेटिँदैन। यो पूर्ववत गर्न सकिँदैन।`
                : <>Close the current fiscal year for <strong className="text-white">{currentBusiness?.name}</strong>? Every record in it becomes read-only — nothing is deleted or moved. This can't be undone.</>}
              {fiscalYearError && (
                <span className="mt-3 flex items-center gap-1.5 text-xs text-red-400">
                  <AlertCircle className="h-3.5 w-3.5 shrink-0" /> {fiscalYearError}
                </span>
              )}
            </span>
          }
          confirmLabel={closingFiscalYear ? <Loader className="h-4 w-4 animate-spin" /> : "Close Fiscal Year"}
          confirmCls="bg-red-500 hover:bg-red-600 text-white disabled:opacity-60"
          onConfirm={closingFiscalYear ? undefined : handleCloseFiscalYear}
          onCancel={() => !closingFiscalYear && setShowCloseFiscalYear(false)}
        />
      )}
    </div>
  );
}
