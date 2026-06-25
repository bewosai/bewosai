export default function PrimaryButton({ children, variant = "primary", className = "", ...props }) {
  const base = "inline-flex items-center gap-1.5 rounded-xl px-4 py-2.5 text-sm font-semibold transition disabled:opacity-60";
  const variants = {
    primary: "bg-orange-500 text-white hover:bg-orange-400",
    outline: "border border-navy-700 text-white hover:border-orange-500 hover:text-orange-400",
    danger: "bg-red-600 text-white hover:bg-red-500",
  };
  return (
    <button {...props} className={`${base} ${variants[variant]} ${className}`}>
      {children}
    </button>
  );
}