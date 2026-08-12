import { Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./context/AuthContext";

// Auth pages
import LoginPage from "./pages/Login";
import VerifyOtpPage from "./pages/VerifyOtp";
import ChooseProfilePage from "./pages/ChooseProfile";
import LandingPage from "./pages/LandingPage";
import CreateBusinessPage from "./pages/CreateBusiness";
import SelectBusinessPage from "./pages/SelectBusiness";

// Business layout + pages
import AppLayout from "./components/layout/AppLayout";
import ProtectedRoute from "./components/ProtectedRoute";
import FeatureGate from "./components/FeatureGate";
import DashboardPage from "./pages/Dashboard";
import PartiesPage from "./pages/PartiesPage";
import InventoryPage from "./pages/InventoryPage";
import SalesPage from "./pages/SalesPage";
import PurchasesPage from "./pages/PurchasesPage";
import PaymentsPage from "./pages/PaymentsPage";
import ExpensesPage from "./pages/ExpensesPage";
import ReportsPage from "./pages/ReportsPage";
import BankingPage from "./pages/BankingPage";
import StaffPage from "./pages/StaffPage";
import SuperAdminPage from "./pages/SuperAdminPage";
import SettingsPage from "./pages/SettingsPage";
import RecycleBinPage from "./pages/RecycleBinPage";
import QuotationPage from "./pages/QuotationPage";
import SalesReturnPage from "./pages/SalesReturnPage";
import ImportPage from "./pages/ImportPage";

// Personal layout + pages
import PersonalLayout from "./components/layout/PersonalLayout";
import PersonalDashboard from "./pages/PersonalDashboard";

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
    <Routes>
      {/* Public */}
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<GuestOnly><LoginPage /></GuestOnly>} />
      <Route path="/choose-profile" element={<GuestOnly><ChooseProfilePage /></GuestOnly>} />
      <Route path="/verify-otp" element={<VerifyOtpPage />} />

      {/* Post-login setup */}
      <Route path="/create-business" element={<RequireAuth><CreateBusinessPage /></RequireAuth>} />
      <Route path="/select-business" element={<RequireAuth><SelectBusinessPage /></RequireAuth>} />

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
        <Route path="/payments" element={<FeatureGate feature="payments"><PaymentsPage /></FeatureGate>} />
        <Route path="/expenses" element={<FeatureGate feature="expenses"><ExpensesPage /></FeatureGate>} />

        <Route path="/banking" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />
        <Route path="/banking/accounts" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />
        <Route path="/banking/transactions" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />
        <Route path="/banking/cashbook" element={<FeatureGate feature="banking"><BankingPage /></FeatureGate>} />

        <Route path="/staff" element={<FeatureGate feature="staff_management"><StaffPage /></FeatureGate>} />
        <Route path="/reports" element={<FeatureGate feature="reports"><ReportsPage /></FeatureGate>} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/recycle-bin" element={<RecycleBinPage />} />
        <Route path="/import" element={<FeatureGate feature="excel_import"><ImportPage /></FeatureGate>} />
        <Route path="/superadmin" element={<SuperAdminPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
