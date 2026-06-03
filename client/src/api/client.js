import axios from "axios";
const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:5000/api";
export const api = axios.create({ baseURL: API_BASE, withCredentials: true });
export function setAccessToken(token){ if(token){ api.defaults.headers.common.Authorization=`Bearer ${token}`; localStorage.setItem("accessToken", token);} else {delete api.defaults.headers.common.Authorization; localStorage.removeItem("accessToken");}}
const saved=localStorage.getItem("accessToken"); if(saved) setAccessToken(saved);
api.interceptors.response.use(r=>r, async (error)=>{ const req=error.config; if(error?.response?.status===401 && !req._retry){ req._retry=true; try{ const res=await axios.post(`${API_BASE}/auth/refresh`,{}, {withCredentials:true}); const token=res.data?.accessToken; if(token){ setAccessToken(token); req.headers.Authorization=`Bearer ${token}`; return api(req);} }catch{} } return Promise.reject(error);});
