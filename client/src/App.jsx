import { Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./context/AuthContext";

// Auth pages
import LoginPage from "./pages/Login";
import LandingPage from "./pages/LandingPage";
import CreateBusinessPage from "./pages/CreateBusiness";
import SelectBusinessPage from "./pages/SelectBusiness";

// Business layout + pages
import AppLayout from "./components/layout/AppLayout";
import ProtectedRoute from "./components/ProtectedRoute";
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

// Personal layout + pages
import PersonalLayout from "./components/layout/PersonalLayout";
import PersonalDashboard from "./pages/PersonalDashboard";

function GuestOnly({ children }) {
  const { isLoggedIn, user } = useAuth();
  if (!isLoggedIn) return children;
  return <Navigate to={user?.account_type === "personal" ? "/personal/dashboard" : "/dashboard"} replace />;
}

export default function App() {
  return (
    <Routes>
      {/* Public */}
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<GuestOnly><LoginPage /></GuestOnly>} />

      {/* Post-login setup */}
      <Route path="/create-business" element={<CreateBusinessPage />} />
      <Route path="/select-business" element={<SelectBusinessPage />} />

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
        <Route path="/parties" element={<PartiesPage />} />

        <Route path="/inventory" element={<InventoryPage />} />
        <Route path="/inventory/products" element={<InventoryPage />} />
        <Route path="/inventory/categories" element={<InventoryPage />} />
        <Route path="/inventory/stock" element={<InventoryPage />} />
        <Route path="/inventory/low-stock" element={<InventoryPage />} />

        <Route path="/sales" element={<SalesPage />} />
        <Route path="/sales/quotation" element={<QuotationPage />} />
        <Route path="/sales/return" element={<SalesReturnPage />} />

        <Route path="/purchases" element={<PurchasesPage />} />
        <Route path="/payments" element={<PaymentsPage />} />
        <Route path="/expenses" element={<ExpensesPage />} />

        <Route path="/banking" element={<BankingPage />} />
        <Route path="/banking/accounts" element={<BankingPage />} />
        <Route path="/banking/transactions" element={<BankingPage />} />
        <Route path="/banking/cashbook" element={<BankingPage />} />

        <Route path="/staff" element={<StaffPage />} />
        <Route path="/reports" element={<ReportsPage />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/recycle-bin" element={<RecycleBinPage />} />
        <Route path="/superadmin" element={<SuperAdminPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
