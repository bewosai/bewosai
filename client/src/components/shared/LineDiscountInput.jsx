import { lineDiscountAmount } from "../../utils/calculations";

// A billing line's discount, typed as a rupee amount or as a % of the line —
// the small button beside it switches between the two, converting the typed
// value so the discount itself doesn't change. The line item keeps
// `discount_mode` ("amount" | "percent") plus `discount_amount` /
// `discount_percent` for whichever is being typed; the rupee figure that's
// actually saved is lineDiscount(item) below.
export const lineDiscount = (item, gross) =>
  item.discount_mode === "percent"
    ? lineDiscountAmount(gross, item.discount_percent, "percent")
    : lineDiscountAmount(gross, item.discount_amount, "amount");

export default function LineDiscountInput({ item, gross, onChange }) {
  const percent = item.discount_mode === "percent";
  const typed = percent ? item.discount_percent : item.discount_amount;
  const value = parseFloat(typed) || 0;
  const tooBig = percent ? value > 100 : value > gross + 0.005;

  const toggle = () => {
    const amount = lineDiscount(item, gross);
    onChange(percent
      ? { discount_mode: "amount", discount_amount: amount }
      : { discount_mode: "percent", discount_percent: gross > 0 ? Math.round((amount / gross) * 10000) / 100 : 0 });
  };

  return (
    <div className="flex items-center gap-0.5">
      <input
        type="number" min="0" max={percent ? 100 : undefined} step="0.01"
        title={tooBig
          ? (percent ? "A discount can't be more than 100% — it will be capped." :
            `Discount can't be more than the line amount (Rs ${gross.toFixed(2)}) — it will be capped.`)
          : undefined}
        className={`w-full min-w-0 rounded-md bg-navy-800 border px-1.5 py-1.5 text-xs text-white text-right focus:outline-none ${tooBig ? "border-red-500 focus:border-red-500" : "border-navy-700 focus:border-orange-500"}`}
        value={typed ?? 0}
        onChange={e => {
          const v = Math.max(0, parseFloat(e.target.value) || 0);
          onChange(percent ? { discount_percent: v } : { discount_amount: v });
        }}
      />
      <button
        type="button" onClick={toggle}
        title={percent ? "Discount in % — click to enter Rs instead" : "Discount in Rs — click to enter % instead"}
        className="shrink-0 rounded-md bg-navy-700 px-1.5 py-1.5 text-[10px] font-bold text-orange-300 hover:bg-navy-600"
      >
        {percent ? "%" : "Rs"}
      </button>
    </div>
  );
}
