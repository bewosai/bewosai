import axios from "axios";
import { wrapWithOfflineQueue } from "../utils/offlineQueue";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8000/api";

const api = axios.create({
  baseURL: API_URL,
  // Tells the backend's feature-flag enforcement (require_feature) this is
  // the web client, so Super Admin's per-platform toggles apply correctly —
  // see bewosai/permissions.py::get_platform. The Flutter app sends "mobile".
  headers: { "Content-Type": "application/json", "X-Platform": "web" },
});

// Wrap so offline mutations are queued and re-synced automatically
wrapWithOfflineQueue(api);

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("access");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  const bid = localStorage.getItem("business_id");
  if (bid) {
    // Always send business_id as query param AND header
    config.params = { ...config.params, business: bid };
    config.headers["X-Business-ID"] = bid;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  async (err) => {
    const original = err.config;
    if (err.response?.status === 401 && !original._retry) {
      original._retry = true;
      try {
        const refresh = localStorage.getItem("refresh");
        const { data } = await axios.post(`${API_URL}/auth/refresh/`, { refresh });
        localStorage.setItem("access", data.access);
        original.headers.Authorization = `Bearer ${data.access}`;
        return api(original);
      } catch {
        localStorage.clear();
        window.location.href = "/login";
      }
    }
    return Promise.reject(err);
  }
);

export const auth = {
  sendOtp: (email, isSignup = false) => api.post("/auth/send-otp/", { email, is_signup: isSignup }),
  verifyOtp: (email, code, remember) =>
    api.post("/auth/verify-otp/", { email, code, remember }),
  setAccountType: (accountType) => api.post("/auth/set-account-type/", { account_type: accountType }),
  logout: (refresh) => api.post("/auth/logout/", { refresh }),
  me: () => api.get("/auth/me/"),
  updateMe: (d) => api.patch("/auth/me/", d),
  businesses: () => api.get("/auth/businesses/"),
  createBusiness: (d) => api.post("/auth/businesses/", d),
  updateBusiness: (id, d) => {
    const isFormData = d instanceof FormData;
    return api.patch(`/auth/businesses/${id}/`, d, isFormData ? { headers: { "Content-Type": "multipart/form-data" } } : {});
  },
  staff: (bid) => api.get(`/auth/businesses/${bid}/staff/`),
  inviteStaff: (bid, d) => api.post(`/auth/businesses/${bid}/staff/`, d),
  updateStaff: (bid, sid, d) => api.patch(`/auth/businesses/${bid}/staff/${sid}/`, d),
  removeStaff: (bid, sid) => api.delete(`/auth/businesses/${bid}/staff/${sid}/`),
};

export const inventory = {
  products: (p) => api.get("/inventory/products/", { params: p }),
  createProduct: (d) => api.post("/inventory/products/", d),
  updateProduct: (id, d) => api.patch(`/inventory/products/${id}/`, d),
  deleteProduct: (id) => api.delete(`/inventory/products/${id}/`),
  bulkImportProducts: (products) => api.post("/inventory/products/bulk-import/", { products }),
  categories: (p) => api.get("/inventory/categories/", { params: p }),
  createCategory: (d) => api.post("/inventory/categories/", d),
  units: (p) => api.get("/inventory/units/", { params: p }),
  createUnit: (d) => api.post("/inventory/units/", d),
  stockMovements: (p) => api.get("/inventory/stock-movements/", { params: p }),
  addStockMovement: (d) => api.post("/inventory/stock-movements/", d),
};

export const parties = {
  list: (p) => api.get("/parties/", { params: p }),
  create: (d) => api.post("/parties/", d),
  update: (id, d) => api.patch(`/parties/${id}/`, d),
  delete: (id) => api.delete(`/parties/${id}/`),
  bulkImport: (parties) => api.post("/parties/bulk-import/", { parties }),
  ledger: (id, p) => api.get(`/parties/${id}/ledger/`, { params: p }),
  payments: (p) => api.get("/parties/payments/", { params: p }),
  addPayment: (d) => api.post("/parties/payments/", d),
  deletePayment: (id) => api.delete(`/parties/payments/${id}/`),
};

export const sales = {
  list: (p) => api.get("/sales/", { params: p }),
  create: (d) => api.post("/sales/", d),
  update: (id, d) => api.patch(`/sales/${id}/`, d),
  delete: (id) => api.delete(`/sales/${id}/`),
  get: (id) => api.get(`/sales/${id}/`),
  nextNumber: () => api.get("/sales/next-number/"),
  returns: (p) => api.get("/sales/returns/", { params: p }),
  createReturn: (d) => api.post("/sales/returns/", d),
  quotations: (p) => api.get("/sales/quotations/", { params: p }),
  createQuotation: (d) => api.post("/sales/quotations/", d),
  updateQuotation: (id, d) => api.patch(`/sales/quotations/${id}/`, d),
  deleteQuotation: (id) => api.delete(`/sales/quotations/${id}/`),
};

const bid = () => localStorage.getItem("business_id") || "";
const bid_headers = () => ({ "X-Business-ID": bid() });

export const purchases = {
  list: (params) => api.get("/purchases/", { params, headers: bid_headers() }),
  nextNumber: () => api.get("/purchases/next-number/", { headers: bid_headers() }),
  create: (data) => {
    const isFormData = data instanceof FormData;
    return api.post("/purchases/", data, { headers: { ...bid_headers(), ...(isFormData ? { "Content-Type": "multipart/form-data" } : {}) } });
  },
  update: (id, data) => {
    const isFormData = data instanceof FormData;
    return api.patch(`/purchases/${id}/`, data, { headers: { ...bid_headers(), ...(isFormData ? { "Content-Type": "multipart/form-data" } : {}) } });
  },
  delete: (id) => api.delete(`/purchases/${id}/`, { headers: bid_headers() }),
};

export const recycleBin = {
  list: (params) => api.get("/purchases/recycle-bin/", { params, headers: bid_headers() }),
  restore: (type, id) => api.post(`/purchases/recycle-bin/restore/${type}/${id}/`, {}, { headers: bid_headers() }),
  permanentDelete: (type, id) => api.delete(`/purchases/recycle-bin/delete/${type}/${id}/`, { headers: bid_headers() }),
};

export const expenses = {
  list: (p) => api.get("/expenses/", { params: p }),
  create: (d) => {
    const isFormData = d instanceof FormData;
    return api.post("/expenses/", d, isFormData ? { headers: { "Content-Type": "multipart/form-data" } } : {});
  },
  update: (id, d) => {
    const isFormData = d instanceof FormData;
    return api.patch(`/expenses/${id}/`, d, isFormData ? { headers: { "Content-Type": "multipart/form-data" } } : {});
  },
  delete: (id) => api.delete(`/expenses/${id}/`),
  categories: (p) => api.get("/expenses/categories/", { params: p }),
  createCategory: (d) => api.post("/expenses/categories/", d),
};

export const banking = {
  accounts: (p) => api.get("/banking/accounts/", { params: p }),
  createAccount: (d) => {
    const isFormData = d instanceof FormData;
    return api.post("/banking/accounts/", d, isFormData ? { headers: { "Content-Type": "multipart/form-data" } } : {});
  },
  updateAccount: (id, d) => {
    const isFormData = d instanceof FormData;
    return api.patch(`/banking/accounts/${id}/`, d, isFormData ? { headers: { "Content-Type": "multipart/form-data" } } : {});
  },
  deleteAccount: (id) => api.delete(`/banking/accounts/${id}/`),
  transactions: (p) => api.get("/banking/transactions/", { params: p }),
  addTransaction: (d) => api.post("/banking/transactions/", d),
  deleteTransaction: (id) => api.delete(`/banking/transactions/${id}/`),
};

export const reports = {
  dashboard: () => api.get("/reports/dashboard/"),
  sales: (p) => api.get("/reports/sales/", { params: p }),
  expenses: (p) => api.get("/reports/expenses/", { params: p }),
  inventory: () => api.get("/reports/inventory/"),
  profit: (p) => api.get("/reports/profit/", { params: p }),
  monthly: (p) => api.get("/reports/monthly/", { params: p }),
  receivableAging: () => api.get("/reports/receivable-aging/"),
  dayBook: (p) => api.get("/reports/day-book/", { params: p }),
  cashFlow: (p) => api.get("/reports/cash-flow/", { params: p }),
  stock: () => api.get("/reports/stock/"),
  cashInHand: (p) => api.get("/reports/cash-in-hand/", { params: p }),
  bankStatement: (p) => api.get("/reports/bank-statement/", { params: p }),
  allTransactions: (p) => api.get("/reports/all-transactions/", { params: p }),
  staffActivity: (p) => api.get("/auth/staff-activity/", { params: p }),
};

export const licenses = {
  me: () => api.get("/auth/licenses/me/"),
  activate: (code) => api.post("/auth/licenses/activate/", { code }),
};

export const superadmin = {
  stats: () => api.get("/superadmin/stats/"),

  businesses: (p) => api.get("/superadmin/businesses/", { params: p }),
  businessAction: (id, action) => api.patch(`/superadmin/businesses/${id}/action/`, { action }),
  editBusiness: (id, d) => api.patch(`/superadmin/businesses/${id}/`, d),
  deleteBusiness: (id) => api.delete(`/superadmin/businesses/${id}/`),
  businessData: (id) => api.get(`/superadmin/businesses/${id}/data/`),

  users: (p) => api.get("/superadmin/users/", { params: p }),
  userAction: (id, action) => api.patch(`/superadmin/users/${id}/action/`, { action }),
  createUser: (d) => api.post("/superadmin/users/create/", d),
  deleteUser: (id) => api.delete(`/superadmin/users/${id}/delete/`),
  loginActivity: () => api.get("/superadmin/login-activity/"),
  userLoginActivity: (userId) => api.get("/superadmin/login-activity/", { params: { user_id: userId } }),

  tickets: (p) => api.get("/superadmin/tickets/", { params: p }),
  updateTicket: (id, d) => api.patch(`/superadmin/tickets/${id}/`, d),

  announcements: () => api.get("/superadmin/announcements/"),
  createAnnouncement: (d) => api.post("/superadmin/announcements/", d),
  updateAnnouncement: (id, d) => api.patch(`/superadmin/announcements/${id}/`, d),
  deleteAnnouncement: (id) => api.delete(`/superadmin/announcements/${id}/`),

  features: () => api.get("/superadmin/features/"),
  toggleFeature: (key, d) => api.patch(`/superadmin/features/${key}/toggle/`, d),

  licenseList: (params) => api.get("/superadmin/licenses/", { params }),
  licenseYears: () => api.get("/superadmin/licenses/years/"),
  generateLicense: (d) => api.post("/superadmin/licenses/generate/", d),
  licenseDetail: (id) => api.get(`/superadmin/licenses/${id}/`),
  updateLicense: (id, d) => api.patch(`/superadmin/licenses/${id}/`, d),
  extendLicense: (id, d) => api.post(`/superadmin/licenses/${id}/extend/`, d),
  revokeLicense: (id) => api.post(`/superadmin/licenses/${id}/revoke/`),
  reassignLicense: (id, businessId) => api.post(`/superadmin/licenses/${id}/reassign/`, { business: businessId }),
  licenseAuditLog: (params) => api.get("/superadmin/licenses/audit-log/", { params }),

  businessFeaturePermissions: (businessId) => api.get(`/superadmin/businesses/${businessId}/features/`),
  setBusinessFeaturePermission: (businessId, featureKey, enabled) =>
    api.patch(`/superadmin/businesses/${businessId}/features/`, { feature_key: featureKey, enabled }),
};

// Effective feature availability for the current business — same endpoint
// the Flutter app reads, so both platforms always agree (see
// bewosai/urls.py::EffectiveFeaturesView).
export const features = {
  effective: () => api.get("/features/"),
};

export default api;
