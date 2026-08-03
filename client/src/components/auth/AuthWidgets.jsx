import { useRef } from "react";
import { Check } from "lucide-react";

/* ─── OTP 6-box input ─────────────────────── */
export function OTPInput({ value, onChange, disabled }) {
  const inputs = useRef([]);

  const handleChange = (e, i) => {
    const v = e.target.value.replace(/\D/g, "").slice(-1);
    const arr = (value + "      ").slice(0, 6).split("");
    arr[i] = v;
    onChange(arr.join("").trimEnd().slice(0, 6));
    if (v && i < 5) inputs.current[i + 1]?.focus();
  };

  const handleKey = (e, i) => {
    if (e.key === "Backspace" && !e.target.value && i > 0) {
      inputs.current[i - 1]?.focus();
    }
  };

  const handlePaste = (e) => {
    const p = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    onChange(p.padEnd(6, " ").slice(0, 6).trimEnd());
    inputs.current[Math.min(p.length, 5)]?.focus();
    e.preventDefault();
  };

  return (
    <div className="flex justify-center gap-2">
      {Array.from({ length: 6 }).map((_, i) => (
        <input
          key={i}
          id={`otp-${i}`}
          name={`otp-${i}`}
          ref={(el) => (inputs.current[i] = el)}
          maxLength={1}
          value={(value || "")[i] || ""}
          onChange={(e) => handleChange(e, i)}
          onKeyDown={(e) => handleKey(e, i)}
          onPaste={handlePaste}
          inputMode="numeric"
          autoComplete="one-time-code"
          disabled={disabled}
          className={`h-14 w-11 rounded-2xl border-2 bg-navy-950 text-center text-xl font-bold text-white outline-none transition focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 disabled:opacity-50 ${
            (value || "")[i] ? "border-orange-500" : "border-navy-700"
          }`}
        />
      ))}
    </div>
  );
}

/* ─── Profile card ──────────────────────── */
export function ProfileCard({ label, description, features, icon: Icon, iconColor, selected, onSelect }) {
  return (
    <button
      onClick={onSelect}
      className={`relative w-full rounded-2xl border-2 p-5 text-left transition-all duration-200 ${
        selected
          ? "border-orange-500 bg-orange-500/8 shadow-lg shadow-orange-500/10"
          : "border-navy-700 bg-navy-950/60 hover:border-navy-500"
      }`}
    >
      {selected && (
        <div className="absolute right-3 top-3 flex h-6 w-6 items-center justify-center rounded-full bg-orange-500">
          <Check className="h-3.5 w-3.5 text-white" />
        </div>
      )}
      <div className={`mb-3 flex h-12 w-12 items-center justify-center rounded-xl ${iconColor}`}>
        <Icon className="h-6 w-6" />
      </div>
      <p className="text-base font-bold text-white">{label}</p>
      <p className="mt-1 text-xs text-navy-400">{description}</p>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {features.map((f) => (
          <span key={f} className="rounded-full bg-navy-800 px-2.5 py-1 text-[10px] text-navy-400">{f}</span>
        ))}
      </div>
    </button>
  );
}

/* ─── Step indicators ─── */
export function Steps({ current, steps }) {
  return (
    <div className="mb-6 flex items-center justify-center gap-2">
      {steps.map((label, i) => {
        const n = i + 1;
        const done = n < current;
        const active = n === current;
        return (
          <div key={label} className="flex items-center gap-2">
            <div className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold transition ${
              done ? "bg-green-500 text-white" : active ? "bg-orange-500 text-white" : "bg-navy-800 text-navy-500"
            }`}>
              {done ? <Check className="h-3.5 w-3.5" /> : n}
            </div>
            <span className={`text-xs ${active ? "text-white font-medium" : "text-navy-500"}`}>{label}</span>
            {i < steps.length - 1 && <div className={`h-px w-6 ${done ? "bg-green-500" : "bg-navy-700"}`} />}
          </div>
        );
      })}
    </div>
  );
}
