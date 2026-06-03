import axios from "axios";

const API = axios.create({
  baseURL: "http://localhost:5000/api",
  withCredentials: true,
});

API.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export const createSale = async (payload) => {
  const { data } = await API.post("/sales", payload);
  return data;
};

export const getSales = async (type = "") => {
  const { data } = await API.get(`/sales${type ? `?type=${type}` : ""}`);
  return data;
};

export const deleteSale = async (id) => {
  const { data } = await API.delete(`/sales/${id}`);
  return data;
};

export const addPaymentIn = async (id, amount, meta = {}) => {
  const { data } = await API.post(`/sales/${id}/payment-in`, {
    amount,
    ...meta,
  });
  return data;
};

export const createSalesReturn = async (id, items, meta = {}) => {
  const { data } = await API.post(`/sales/${id}/return`, {
    items,
    ...meta,
  });
  return data;
};