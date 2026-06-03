export default function PrimaryButton({ children, ...props }) {
  return (
    <button
      {...props}
      className="rounded-2xl bg-emerald-500 px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-emerald-400"
    >
      {children}
    </button>
  );
}