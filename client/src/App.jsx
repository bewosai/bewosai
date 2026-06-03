import { Routes, Route, Navigate } from "react-router-dom";
import LandingPage from "./pages/LandingPage";
import LoginPage from "./pages/Login";
import DashboardPage from "./pages/Dashboard";
import PartiesPage from "./pages/PartiesPage";
import ItemsPage from "./pages/ItemsPage";
import SalesPage from "./pages/SalesPage";
import PurchasesPage from "./pages/PurchasesPage";
import PaymentsPage from "./pages/PaymentsPage";
import ExpensesPage from "./pages/ExpensesPage";
import ReportsPage from "./pages/ReportsPage";
import AppLayout from "./components/layout/AppLayout";
import ProtectedRoute from "./components/ProtectedRoute";
import SalesInvoicePage from "./sales/sales_Invoice";
import PaymentInPage from "./sales/payment_in";
import QuotationPage from "./sales/Quotation";
import SalesReturnPage from "./sales/sales_return";  

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<LoginPage />} />

      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/parties" element={<PartiesPage />} />
        <Route path="/items" element={<ItemsPage />} />
        <Route path="/sales" element={<SalesPage />} />
        <Route path="/purchases" element={<PurchasesPage />} />
        <Route path="/payments" element={<PaymentsPage />} />
        <Route path="/expenses" element={<ExpensesPage />} />
        <Route path="/reports" element={<ReportsPage />} />

<Route path="/sales/invoice" element={<SalesInvoicePage />} />
<Route path="/sales/payment-in" element={<PaymentInPage />} />
<Route path="/sales/quotation" element={<QuotationPage />} />
<Route path="/sales/return" element={<SalesReturnPage />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}