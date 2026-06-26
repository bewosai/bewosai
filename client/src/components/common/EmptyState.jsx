import { Plus } from "lucide-react";

/**
 * Reusable empty state component.
 * Props: icon (Lucide component), title, description, actionLabel, onAction
 */
export default function EmptyState({ icon: Icon, title, description, actionLabel, onAction }) {
  return (
    <div className="flex flex-col items-center gap-3 py-14 text-center">
      {Icon && (
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-navy-800">
          <Icon className="h-7 w-7 text-navy-500" />
        </div>
      )}
      {title && <p className="text-sm font-semibold text-navy-300">{title}</p>}
      {description && <p className="max-w-xs text-xs text-navy-500">{description}</p>}
      {actionLabel && onAction && (
        <button
          onClick={onAction}
          className="mt-1 flex items-center gap-2 rounded-xl bg-orange-500 px-4 py-2 text-sm font-semibold text-white transition hover:bg-orange-600"
        >
          <Plus className="h-4 w-4" />
          {actionLabel}
        </button>
      )}
    </div>
  );
}
