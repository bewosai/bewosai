import axios from "axios";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8000/api";

const api = axios.create({
  baseURL: API_URL,
  headers: { "Content-Type": "application/json" },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("access");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  const bid = localStorage.getItem("business_id");
  if (bid && config.method === "get") {
    config.params = { ...config.params, business: bid };
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
  sendOtp: (email, accountType) => api.post("/auth/send-otp/", { email, account_type: accountType }),
  verifyOtp: (email, code, accountType, remember) =>
    api.post("/auth/verify-otp/", { email, code, account_type: accountType, remember }),
  logout: (refresh) => api.post("/auth/logout/", { refresh }),
  me: () => api.get("/auth/me/"),
  updateMe: (d) => api.patch("/auth/me/", d),
  businesses: () => api.get("/auth/businesses/"),
  createBusiness: (d) => api.post("/auth/businesses/", d),
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
  payments: (p) => api.get("/parties/payments/", { params: p }),
  addPayment: (d) => api.post("/parties/payments/", d),
};

export const sales = {
  list: (p) => api.get("/sales/", { params: p }),
  create: (d) => api.post("/sales/", d),
  update: (id, d) => api.patch(`/sales/${id}/`, d),
  get: (id) => api.get(`/sales/${id}/`),
  returns: (p) => api.get("/sales/returns/", { params: p }),
  createReturn: (d) => api.post("/sales/returns/", d),
  quotations: (p) => api.get("/sales/quotations/", { params: p }),
  createQuotation: (d) => api.post("/sales/quotations/", d),
};

export const expenses = {
  list: (p) => api.get("/expenses/", { params: p }),
  create: (d) => api.post("/expenses/", d),
  update: (id, d) => api.patch(`/expenses/${id}/`, d),
  delete: (id) => api.delete(`/expenses/${id}/`),
  categories: (p) => api.get("/expenses/categories/", { params: p }),
  createCategory: (d) => api.post("/expenses/categories/", d),
};

export const banking = {
  accounts: (p) => api.get("/banking/accounts/", { params: p }),
  createAccount: (d) => api.post("/banking/accounts/", d),
  updateAccount: (id, d) => api.patch(`/banking/accounts/${id}/`, d),
  transactions: (p) => api.get("/banking/transactions/", { params: p }),
  addTransaction: (d) => api.post("/banking/transactions/", d),
};

export const reports = {
  dashboard: () => api.get("/reports/dashboard/"),
  sales: (p) => api.get("/reports/sales/", { params: p }),
  expenses: (p) => api.get("/reports/expenses/", { params: p }),
  inventory: () => api.get("/reports/inventory/"),
  profit: (p) => api.get("/reports/profit/", { params: p }),
};

export const superadmin = {
  stats: () => api.get("/superadmin/stats/"),
  businesses: (p) => api.get("/superadmin/businesses/", { params: p }),
  businessAction: (id, action) => api.patch(`/superadmin/businesses/${id}/action/`, { action }),
  users: () => api.get("/superadmin/users/"),
  loginActivity: () => api.get("/superadmin/login-activity/"),
  tickets: () => api.get("/superadmin/tickets/"),
  updateTicket: (id, d) => api.patch(`/superadmin/tickets/${id}/`, d),
  announcements: () => api.get("/superadmin/announcements/"),
  createAnnouncement: (d) => api.post("/superadmin/announcements/", d),
};

export default api;
