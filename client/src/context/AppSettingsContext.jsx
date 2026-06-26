import { createContext, useContext, useState, useEffect } from "react";
import { adToBS, formatBS } from "../utils/nepaliDate";

const AppSettingsContext = createContext(null);

export function AppSettingsProvider({ children }) {
  const [theme, setTheme] = useState(() => localStorage.getItem("bw_theme") || "light");
  const [language, setLanguage] = useState(() => localStorage.getItem("bw_lang") || "en");
  const [privateMode, setPrivateMode] = useState(() => localStorage.getItem("bw_private") === "true");
  const [dateMode, setDateMode] = useState(() => localStorage.getItem("bw_date_mode") || "AD");
  const [currency, setCurrency] = useState(() => localStorage.getItem("bw_currency") || "Rs.");

  useEffect(() => {
    const root = document.documentElement;
    if (theme === "dark") {
      root.setAttribute("data-theme", "dark");
    } else {
      root.removeAttribute("data-theme");
    }
    localStorage.setItem("bw_theme", theme);
  }, [theme]);

  useEffect(() => { localStorage.setItem("bw_lang", language); }, [language]);
  useEffect(() => { localStorage.setItem("bw_private", privateMode); }, [privateMode]);
  useEffect(() => { localStorage.setItem("bw_date_mode", dateMode); }, [dateMode]);
  useEffect(() => { localStorage.setItem("bw_currency", currency); }, [currency]);

  const toggleTheme = () => setTheme((t) => (t === "light" ? "dark" : "light"));
  const toggleLanguage = () => setLanguage((l) => (l === "en" ? "ne" : "en"));
  const togglePrivateMode = () => setPrivateMode((p) => !p);
  const toggleDateMode = () => setDateMode((m) => (m === "AD" ? "BS" : "AD"));

  return (
    <AppSettingsContext.Provider
      value={{
        theme, language, privateMode, dateMode, currency,
        setTheme, setLanguage, setDateMode, setCurrency,
        toggleTheme, toggleLanguage, togglePrivateMode, toggleDateMode,
      }}
    >
      {children}
    </AppSettingsContext.Provider>
  );
}

export function useAppSettings() {
  return useContext(AppSettingsContext);
}

/** Mask amounts in private mode */
export function usePrivateAmount() {
  const { privateMode, currency } = useAppSettings();
  return (value, opts = {}) => {
    if (privateMode) return "XXXXX";
    const num = parseFloat(value) || 0;
    const formatted = num.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    return opts.noCurrency ? formatted : `${currency} ${formatted}`;
  };
}

/** Format a date string/Date according to the selected date mode */
export function useDateFormat() {
  const { dateMode, language } = useAppSettings();
  return (dateInput, opts = {}) => {
    if (!dateInput) return "";
    const d = dateInput instanceof Date ? dateInput : new Date(dateInput);
    if (isNaN(d)) return String(dateInput);

    if (dateMode === "BS") {
      try {
        const bs = adToBS(d);
        return formatBS(bs, language);
      } catch {
        // fallback to AD if conversion fails
      }
    }
    // AD format
    return d.toLocaleDateString("en-IN", {
      year: "numeric",
      month: opts.short ? "short" : "2-digit",
      day: "2-digit",
    });
  };
}
