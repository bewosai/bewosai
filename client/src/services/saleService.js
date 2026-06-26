/**
 * Compatibility shim — maps old saleService calls to the new Django API.
 * The legacy sales sub-pages (sales_Invoice, payment_in, Quotation, sales_return)
 * import from here; new code should use "../api" directly.
 */
import { sales as salesApi, parties as partiesApi } from "../api";

export async function getSales(params) {
  const res = await salesApi.list(params);
  return { data: res.data.results ?? res.data };
}

export async function createSale(data) {
  const res = await salesApi.create(data);
  return { data: res.data };
}

export async function deleteSale(id) {
  return salesApi.update(id, { is_active: false });
}

export async function createSalesReturn(data) {
  const res = await salesApi.createReturn(data);
  return { data: res.data };
}

export async function addPaymentIn(data) {
  const res = await partiesApi.addPayment({ ...data, payment_type: "IN" });
  return { data: res.data };
}

export async function getParties(params) {
  const res = await partiesApi.list(params);
  return { data: res.data.results ?? res.data };
}
