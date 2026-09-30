import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import { AppSettingsProvider } from "./context/AppSettingsContext";
import { FeatureProvider } from "./context/FeatureContext";
import { LicenseProvider } from "./context/LicenseContext";
import App from "./App";
import { installZeroSelect } from "./utils/zeroSelect";
import { installErrorReporting, ErrorBoundary } from "./utils/errorReporting";
import "./index.css";

installErrorReporting();
installZeroSelect();

// Shown instead of a blank page if something crashes while drawing the page
// (and, with Sentry on, the crash is reported).
function CrashScreen() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-navy-950 px-4 text-center">
      <div>
        <h1 className="text-xl font-bold text-white">Something went wrong</h1>
        <p className="mt-2 text-sm text-navy-400">Please reload the page. Your saved data is safe.</p>
        <button onClick={() => window.location.reload()}
          className="mt-5 rounded-xl bg-orange-500 px-6 py-2.5 font-bold text-white hover:bg-orange-400">
          Reload
        </button>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <ErrorBoundary fallback={<CrashScreen />}>
    <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <AppSettingsProvider>
        <AuthProvider>
          <FeatureProvider>
            <LicenseProvider>
              <App />
            </LicenseProvider>
          </FeatureProvider>
        </AuthProvider>
      </AppSettingsProvider>
    </BrowserRouter>
  </ErrorBoundary>
);
