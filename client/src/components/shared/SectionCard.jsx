export default function SectionCard({ title, children, right, action }) {
  return (
    <div className="rounded-2xl border border-navy-800 bg-navy-900">
      {title && (
        <div className="flex items-center justify-between border-b border-navy-800 px-5 py-4">
          <h2 className="text-sm font-semibold text-white">{title}</h2>
          {(right || action) && <div>{right || action}</div>}
        </div>
      )}
      <div className="p-5">{children}</div>
    </div>
  );
}