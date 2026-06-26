export default function SectionCard({ title, children, right, action }) {
  return (
    <div className="rounded-2xl border border-navy-800 bg-navy-900">
      {title && (
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-navy-800 px-4 py-3 sm:px-5 sm:py-4">
          <h2 className="text-sm font-semibold text-white">{title}</h2>
          {(right || action) && <div className="shrink-0">{right || action}</div>}
        </div>
      )}
      <div className="p-4 sm:p-5">{children}</div>
    </div>
  );
}
