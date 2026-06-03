import axios from "axios";

const API = import.meta.env.VITE_API_URL || "http://localhost:5000/api";

function getAuthHeaders() {
  const token = localStorage.getItem("accessToken");
  return {
    Authorization: `Bearer ${token}`,
  };
}

export async function getParties(params = {}) {
  const res = await axios.get(`${API}/parties`, {
    params,
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
}

export async function getPartyStats() {
  const res = await axios.get(`${API}/parties/stats`, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
}

export async function getPartyLedger(id) {
  const res = await axios.get(`${API}/parties/${id}/ledger`, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
}

export async function createParty(payload) {
  const res = await axios.post(`${API}/parties`, payload, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
}

export async function updateParty(id, payload) {
  const res = await axios.put(`${API}/parties/${id}`, payload, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
}

export async function deleteParty(id) {
  const res = await axios.delete(`${API}/parties/${id}`, {
    headers: getAuthHeaders(),
    withCredentials: true,
  });
  return res.data;
}