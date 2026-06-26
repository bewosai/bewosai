import { LABEL_CLS, INPUT_CLS } from "../../constants";

/**
 * Label + input/select/textarea wrapper.
 * Accepts all native input/select/textarea props plus:
 *   label, as ("input" | "select" | "textarea"), error, children (for select options)
 */
export default function FormField({ label, as: Tag = "input", error, className = "", children, ...props }) {
  return (
    <div className="w-full">
      {label && <label className={LABEL_CLS}>{label}</label>}
      <Tag
        className={`${INPUT_CLS} ${error ? "border-red-500" : ""} ${className}`}
        {...props}
      >
        {children}
      </Tag>
      {error && <p className="mt-1 text-xs text-red-400">{error}</p>}
    </div>
  );
}
