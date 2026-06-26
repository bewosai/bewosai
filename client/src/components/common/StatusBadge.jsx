import { SALE_STATUS } from "../../constants";

/**
 * Renders a colored pill for sale/purchase/quotation status.
 */
export default function StatusBadge({ status }) {
  const meta = SALE_STATUS[status] || { label: status, cls: "bg-navy-700 text-navy-400 border-navy-600" };
  return (
    <span className={`inline-block rounded-full border px-2.5 py-0.5 text-xs font-semibold ${meta.cls}`}>
      {meta.label}
    </span>
  );
}
