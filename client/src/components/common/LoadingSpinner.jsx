import { Loader } from "lucide-react";

export default function LoadingSpinner({ message = "Loading…" }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-14">
      <Loader className="h-6 w-6 animate-spin text-orange-500" />
      <p className="text-sm text-navy-400">{message}</p>
    </div>
  );
}
