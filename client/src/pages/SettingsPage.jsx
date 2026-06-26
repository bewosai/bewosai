import { useState, useRef } from "react";
import { useAppSettings } from "../context/AppSettingsContext";
import { useTranslation } from "../utils/translations";
import { useAuth } from "../context/AuthContext";
import {
  Sun, Moon, Globe, Eye, EyeOff, Calendar, Building2,
  Upload, Save, Bell, Shield, Palette, User, Check,
} from "lucide-react";

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

export default function SettingsPage() {
  const { theme, language, privateMode, dateMode, currency,
          toggleTheme, toggleLanguage, togglePrivateMode, toggleDateMode,
          setTheme, setLanguage, setDateMode, setCurrency } = useAppSettings();
  const { t } = useTranslation();
  const { currentBusiness, user } = useAuth();
  const [saved, setSaved] = useState(false);
  const [businessForm, setBusinessForm] = useState({
    name: currentBusiness?.name || "",
    address: currentBusiness?.address || "",
    phone: currentBusiness?.phone || "",
    email: currentBusiness?.email || "",
    business_type: currentBusiness?.business_type || "",
  });

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
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
          {saved ? (language === "ne" ? "सुरक्षित!" : "Saved!") : t("saveSettings")}
        </button>
      </div>

      <div className="grid gap-5 lg:grid-cols-2">
        {/* Appearance */}
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

        {/* Privacy & Security */}
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

        {/* Business Info */}
        <SettingCard title={t("businessInfo")} icon={Building2}>
          <div className="space-y-3">
            {[
              { key: "name", label: t("businessName"), placeholder: "My Business" },
              { key: "business_type", label: t("businessType"), placeholder: "Retail, Wholesale..." },
              { key: "phone", label: t("phone"), placeholder: "+977-..." },
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
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-navy-400">{t("businessLogo")}</label>
            <label className="flex cursor-pointer items-center gap-3 rounded-xl border border-dashed border-navy-700 px-4 py-3 hover:border-orange-500 transition">
              <Upload className="h-5 w-5 text-navy-500" />
              <span className="text-sm text-navy-500">{t("uploadLogo")}</span>
              <input type="file" accept="image/*" className="hidden" />
            </label>
          </div>
        </SettingCard>

        {/* User Profile */}
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
                defaultValue={user?.name}
                placeholder="Your name"
                className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-navy-400">
                {language === "ne" ? "फोन नम्बर" : "Phone Number"}
              </label>
              <input
                defaultValue={user?.phone}
                placeholder="+977-..."
                className="w-full rounded-lg border border-navy-700 bg-navy-800 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
              />
            </div>
          </div>
        </SettingCard>

        {/* Tax Configuration */}
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

        {/* Notifications */}
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
      </div>

      {/* App Info */}
      <div className="rounded-2xl border border-navy-800 bg-navy-900 p-5">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-semibold text-white">Bewosy Business Suite</p>
            <p className="text-xs text-navy-500 mt-1">Version 2.0 · {language === "ne" ? "सबै अधिकार सुरक्षित" : "All rights reserved"}</p>
          </div>
          <div className="text-right">
            <p className="text-xs text-navy-500">
              {language === "ne" ? "निर्मित" : "Made with"} ❤️ {language === "ne" ? "नेपालमा" : "in Nepal"}
            </p>
            <p className="text-xs text-orange-500 mt-1">bewosy.com</p>
          </div>
        </div>
      </div>
    </div>
  );
}
