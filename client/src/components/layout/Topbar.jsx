import { useState, useEffect } from "react";
import {
  Menu, Bell, Search, LogOut, ChevronDown, Building2,
  Sun, Moon, Eye, EyeOff, Globe, WifiOff, RefreshCw,
  Download, CloudUpload,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../context/AuthContext";
import { useAppSettings } from "../../context/AppSettingsContext";
import { useOfflineSync } from "../../utils/offlineQueue";
import api from "../../api";

export default function Topbar({ onMenuClick }) {
  const navigate = useNavigate();
  const { user, currentBusiness, logout } = useAuth();
  const { theme, language, privateMode, toggleTheme, toggleLanguage, togglePrivateMode } = useAppSettings();
  const { isOnline, pendingCount, isSyncing, flush } = useOfflineSync(api);

  // PWA install prompt
  const [installPrompt, setInstallPrompt] = useState(null);
  const [installed, setInstalled] = useState(false);

  useEffect(() => {
    const handler = (e) => { e.preventDefault(); setInstallPrompt(e); };
    window.addEventListener("beforeinstallprompt", handler);
    window.addEventListener("appinstalled", () => { setInstalled(true); setInstallPrompt(null); });
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  const handleInstall = async () => {
    if (!installPrompt) return;
    installPrompt.prompt();
    const { outcome } = await installPrompt.userChoice;
    if (outcome === "accepted") { setInstallPrompt(null); setInstalled(true); }
  };

  async function handleLogout() {
    await logout();
    navigate("/login");
  }

  return (
    <header className="sticky top-0 z-30 border-b border-navy-800 bg-navy-900/95 backdrop-blur-md shadow-sm">
      <div className="flex items-center justify-between gap-2 px-3 py-2.5 sm:gap-4 sm:px-6 sm:py-3">
        {/* Left */}
        <div className="flex items-center gap-2 sm:gap-3">
          <button
            onClick={onMenuClick}
            className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 hover:text-white lg:hidden"
          >
            <Menu className="h-5 w-5" />
          </button>

          <div className="hidden items-center gap-2 rounded-xl border border-navy-800 bg-navy-900 px-3 py-2 md:flex">
            <Search className="h-4 w-4 text-navy-500" />
            <input
              type="text"
              placeholder="Search…"
              className="w-48 bg-transparent text-sm text-white outline-none placeholder:text-navy-500 lg:w-64"
            />
          </div>
        </div>

        {/* Right */}
        <div className="flex items-center gap-1.5 sm:gap-2">
          {/* Business switcher */}
          <button
            onClick={() => navigate("/select-business")}
            className="hidden items-center gap-2 rounded-xl border border-navy-800 bg-navy-900 px-3 py-2 transition hover:border-orange-500/50 sm:flex"
          >
            <Building2 className="h-4 w-4 text-orange-400" />
            <span className="max-w-24 truncate text-sm text-white lg:max-w-30">
              {currentBusiness?.name || "Select Business"}
            </span>
            <ChevronDown className="h-3 w-3 text-navy-500" />
          </button>

          {/* Offline indicator / sync */}
          {!isOnline && (
            <span className="flex items-center gap-1 rounded-xl border border-red-500/40 bg-red-500/10 px-2 py-1.5 text-xs font-semibold text-red-400">
              <WifiOff className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">Offline</span>
            </span>
          )}
          {isOnline && pendingCount > 0 && (
            <button
              onClick={flush}
              disabled={isSyncing}
              title="Sync pending changes"
              className="flex items-center gap-1 rounded-xl border border-orange-500/40 bg-orange-500/10 px-2 py-1.5 text-xs font-semibold text-orange-400 transition hover:bg-orange-500/20"
            >
              {isSyncing
                ? <RefreshCw className="h-3.5 w-3.5 animate-spin" />
                : <CloudUpload className="h-3.5 w-3.5" />}
              <span className="hidden sm:inline">{pendingCount}</span>
            </button>
          )}

          {/* PWA install button */}
          {installPrompt && !installed && (
            <button
              onClick={handleInstall}
              title="Install Bewosy app"
              className="hidden items-center gap-1.5 rounded-xl border border-navy-800 bg-navy-900 px-2.5 py-2 text-xs font-semibold text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400 sm:flex"
            >
              <Download className="h-3.5 w-3.5" />
              Install
            </button>
          )}

          {/* Language toggle */}
          <button
            onClick={toggleLanguage}
            title={language === "en" ? "Switch to Nepali" : "Switch to English"}
            className="flex items-center gap-1 rounded-xl border border-navy-800 bg-navy-900 px-2 py-2 text-navy-300 transition hover:border-orange-500/50 hover:text-orange-400"
          >
            <Globe className="h-4 w-4" />
            <span className="hidden text-xs font-semibold sm:inline">{language === "en" ? "EN" : "ने"}</span>
          </button>

          {/* Private mode toggle */}
          <button
            onClick={togglePrivateMode}
            title={privateMode ? "Show amounts" : "Hide amounts (private mode)"}
            className={`rounded-xl border p-2 transition ${
              privateMode
                ? "border-orange-500/50 bg-orange-500/10 text-orange-400"
                : "border-navy-800 bg-navy-900 text-navy-300 hover:text-orange-400"
            }`}
          >
            {privateMode ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
          </button>

          {/* Theme toggle */}
          <button
            onClick={toggleTheme}
            className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 transition hover:text-orange-400"
          >
            {theme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </button>

          <button className="relative rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 transition hover:text-orange-400">
            <Bell className="h-4 w-4" />
          </button>

          <div className="hidden rounded-xl border border-navy-800 bg-navy-900 px-3 py-2 sm:block">
            <p className="text-sm font-medium text-white">{user?.name || "User"}</p>
            <p className="text-[10px] text-navy-400">{currentBusiness?.plan || "Free"} Plan</p>
          </div>

          <button
            onClick={handleLogout}
            className="rounded-xl border border-navy-800 bg-navy-900 p-2 text-navy-300 transition hover:text-red-400"
          >
            <LogOut className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Status banners */}
      {privateMode && (
        <div className="border-t border-orange-500/20 bg-orange-500/10 px-4 py-1 text-center">
          <p className="text-xs font-medium text-orange-400">
            {language === "ne" ? "गोप्य मोड — रकम लुकाइएको" : "Private Mode — amounts hidden"}
          </p>
        </div>
      )}
      {!isOnline && (
        <div className="border-t border-red-500/20 bg-red-500/10 px-4 py-1 text-center">
          <p className="text-xs font-medium text-red-400">
            {language === "ne" ? "अफलाइन — परिवर्तनहरू क्लाउडमा स्वचालित रूपमा सिङ्क हुनेछन्" : "Offline — changes will auto-sync when internet returns"}
          </p>
        </div>
      )}
    </header>
  );
}
