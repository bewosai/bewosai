import { useEffect, useState } from "react";
import SaleForm from "../sales/sale_form";
import { createSale, getSales } from "../services/saleService";

export default function SalesPage() {
  const [sales, setSales] = useState([]);

  const load = async () => {
    const res = await getSales();
    setSales(res.data);
  };

  useEffect(() => {
    load();
  }, []);

  const handleCreate = async (data) => {
    await createSale(data);
    load();
  };

  return (
    <div>
      <h1 className="text-2xl text-white mb-4">Sales</h1>

      <SaleForm onSubmit={handleCreate} itemsList={[]} />

      <div className="mt-6">
        {sales.map((s) => (
          <div key={s._id} className="border p-3 mb-2">
            <p>{s.invoiceNo}</p>
            <p>Total: {s.totals.grandTotal}</p>
            <p>Due: {s.totals.due}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

