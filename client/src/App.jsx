import { lazy, Suspense } from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./context/AuthContext";
import LoadingSpinner from "./components/common/LoadingSpinner";

// Landing/login — kept eager since these are what a fresh, logged-out
// visitor sees first; no code-splitting win for the one screen everyone loads.
import LoginPage from "./pages/Login";
import LandingPage from "./pages/LandingPage";

// Rest of the auth flow only runs after that first screen (OTP step,
// onboarding, staff links), so lazy-load them like the business pages below.
const VerifyOtpPage = lazy(() => import("./pages/VerifyOtp"));
const CreateBusinessPage = lazy(() => import("./pages/CreateBusiness"));
const ReferralLanding = lazy(() => import("./pages/ReferralLanding"));
const SelectBusinessPage = lazy(() => import("./pages/SelectBusiness"));
const LicenseRequiredPage = lazy(() => import("./pages/LicenseRequired"));
const StaffLoginPage = lazy(() => import("./pages/StaffLoginPage"));

// Business layout + pages — lazy-loaded so a session only downloads the
// module(s) it actually opens instead of every page's code up front. This
// was previously one ~1.5MB bundle for the whole app.
import AppLayout from "./components/layout/AppLayout";
import ProtectedRoute from "./components/ProtectedRoute";
import FeatureGate from "./components/FeatureGate";
const DashboardPage = lazy(() => import("./pages/Dashboard"));
const PartiesPage = lazy(() => import("./pages/PartiesPage"));
const InventoryPage = lazy(() => import("./pages/InventoryPage"));
const SalesPage = lazy(() => import("./pages/SalesPage"));
const PurchasesPage = lazy(() => import("./pages/PurchasesPage"));
const PaymentsPage = lazy(() => import("./pages/PaymentsPage"));
const ExpensesPage = lazy(() => import("./pages/ExpensesPage"));
const ReportsPage = lazy(() => import("./pages/ReportsPage"));
const BankingPage = lazy(() => import("./pages/BankingPage"));
const StaffPage = lazy(() => import("./pages/StaffPage"));
const SuperAdminPage = lazy(() => import("./pages/SuperAdminPage"));
const SettingsPage = lazy(() => import("./pages/SettingsPage"));
const UpgradePlanPage = lazy(() => import("./pages/UpgradePlanPage"));
const RecycleBinPage = lazy(() => import("./pages/RecycleBinPage"));
const QuotationPage = lazy(() => import("./pages/QuotationPage"));
const SalesReturnPage = lazy(() => import("./pages/SalesReturnPage"));
const PurchaseReturnPage = lazy(() => import("./pages/PurchaseReturnPage"));
const ImportPage = lazy(() => import("./pages/ImportPage"));

// Personal layout + pages
import PersonalLayout from "./components/layout/PersonalLayout";
const PersonalDashboard = lazy(() => import("./pages/PersonalDashboard"));

function GuestOnly({ children }) {
  const { isLoggedIn, user } = useAuth();
  if (!isLoggedIn) return children;
  return <Navigate to={user?.account_type === "personal" ? "/personal/dashboard" : "/dashboard"} replace />;
}

// create-business/select-business are only ever reached after a successful
// OTP verification, so they require auth but not a chosen business yet.
function RequireAuth({ children }) {
  const { isLoggedIn } = useAuth();
  if (!isLoggedIn) return <Navigate to="/login" replace />;
  return children;
}

export default function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
    <Routes>
      {/* Public */}
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<GuestOnly><LoginPage /></GuestOnly>} />
      <Route path="/r/:code" element={<ReferralLanding />} />
      <Route path="/verify-otp" element={<VerifyOtpPage />} />
      {/* Not wrapped in GuestOnly: clicking a staff login link should
          switch the session on this device even if someone else (or a
          previous staff member) is already logged in here. */}
      <Route path="/staff-login/:token" element={<StaffLoginPage />} />

      {/* Post-login setup */}
      <Route path="/create-business" element={<RequireAuth><CreateBusinessPage /></RequireAuth>} />
      <Route path="/select-business" element={<RequireAuth><SelectBusinessPage /></RequireAuth>} />
      <Route path="/license-required" element={<RequireAuth><LicenseRequiredPage /></RequireAuth>} />

      {/* ── PERSONAL routes ── */}
      <Route
        element={
          <ProtectedRoute forType="personal">
            <PersonalLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/personal/dashboard" element={<PersonalDashboard />} />
        <Route path="/personal/expenses" element={<ExpensesPage />} />
        <Route path="/personal/reports" element={<ReportsPage />} />
        <Route path="/personal/settings" element={<SettingsPage />} />
      </Route>

      {/* ── BUSINESS routes ── */}
      <Route
        element={
          <ProtectedRoute forType="business">
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/parties" element={<FeatureGate feature="parties"><PartiesPage /></FeatureGate>} />

        <Route path="/inventory" element={<FeatureGate feature="inventory"><InventoryPage /></FeatureGate>} />
        <Route path="/inventory/products" element={<FeatureGate feature="inventory"><InventoryPage /></FeatureGate>} />
        <Route path="/inventory/categories" element={<FeatureGate feature="inventory"><InventoryPage /></FeatureGate>} />
        <Route path="/inventory/stock" element={<FeatureGate feature="inventory"><InventoryPage /></FeatureGate>} />
        <Route path="/inventory/low-stock" element={<FeatureGate feature="inventory"><InventoryPage /></FeatureGate>} />

        <Route path="/sales" element={<FeatureGate feature="pos"><SalesPage /></FeatureGate>} />
        <Route path="/sales/quotation" element={<FeatureGate feature="pos"><QuotationPage /></FeatureGate>} />
        <Route path="/sales/return" element={<FeatureGate feature="pos"><SalesReturnPage /></FeatureGate>} />

        <Route path="/purchases" element={<FeatureGate feature="purchases"><PurchasesPage /></FeatureGate>} />
        <Route path="/purchases/return" element={<FeatureGate feature="purchases"><PurchaseReturnPage /></FeatureGate>} />
        <Route path="/payments" element={<FeatureGate feature="payments"><PaymentsPage /></FeatureGate>} />
        <Route path="/expenses" element={<FeatureGate feature="expenses"><ExpensesPage /></FeatureGate>} />

        <Route path="/banking" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />
        <Route path="/banking/accounts" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />
        <Route path="/banking/transactions" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />
        <Route path="/banking/cashbook" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />

        <Route path="/staff" element={<FeatureGate feature="staff_management"><StaffPage /></FeatureGate>} />
        <Route path="/reports" element={<FeatureGate feature="reports"><ReportsPage /></FeatureGate>} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/settings/upgrade" element={<UpgradePlanPage />} />
        <Route path="/recycle-bin" element={<RecycleBinPage />} />
        <Route path="/import" element={<FeatureGate feature="excel_import"><ImportPage /></FeatureGate>} />
        <Route path="/superadmin" element={<SuperAdminPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
    </Suspense>
  );
}
