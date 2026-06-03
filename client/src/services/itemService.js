import axios from "axios";

const API = import.meta.env.VITE_API_URL || "http://localhost:5000/api";

const getAuthHeaders = () => {
  const token = localStorage.getItem("accessToken");
  if (!token) {
    console.error("No access token found");
    throw new Error("Authentication required");
  }
  return {
    Authorization: `Bearer ${token}`,
  };
};

export const getItems = async (params = {}) => {
  const res = await axios.get(`${API}/items`, {
    params,
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
};

export const getItemStats = async () => {
  const res = await axios.get(`${API}/items/stats`, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
};

export const createItem = async (payload) => {
  const res = await axios.post(`${API}/items`, payload, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
};

export const updateItem = async (id, payload) => {
  const res = await axios.put(`${API}/items/${id}`, payload, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
};

export const deleteItem = async (id) => {
  const res = await axios.delete(`${API}/items/${id}`, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
};