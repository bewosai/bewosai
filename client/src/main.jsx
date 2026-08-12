import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext";
import { AppSettingsProvider } from "./context/AppSettingsContext";
import { FeatureProvider } from "./context/FeatureContext";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
    <AppSettingsProvider>
      <AuthProvider>
        <FeatureProvider>
          <App />
        </FeatureProvider>
      </AuthProvider>
    </AppSettingsProvider>
  </BrowserRouter>
);
