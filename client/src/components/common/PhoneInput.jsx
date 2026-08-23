import { useMemo, useState } from "react";

// Nepal first and default — this is a Nepal-focused app (Bikram Sambat
// calendar, PAN/VAT, NPR currency throughout) — with a handful of common
// destinations for businesses with cross-border suppliers/customers.
const COUNTRY_CODES = [
  { code: "+977", flag: "🇳🇵", label: "Nepal" },
  { code: "+91",  flag: "🇮🇳", label: "India" },
  { code: "+1",   flag: "🇺🇸", label: "USA/Canada" },
  { code: "+44",  flag: "🇬🇧", label: "UK" },
  { code: "+971", flag: "🇦🇪", label: "UAE" },
  { code: "+974", flag: "🇶🇦", label: "Qatar" },
  { code: "+966", flag: "🇸🇦", label: "Saudi Arabia" },
  { code: "+60",  flag: "🇲🇾", label: "Malaysia" },
  { code: "+61",  flag: "🇦🇺", label: "Australia" },
  { code: "+82",  flag: "🇰🇷", label: "South Korea" },
  { code: "+81",  flag: "🇯🇵", label: "Japan" },
];

function splitPhone(value) {
  const v = (value || "").trim();
  const match = COUNTRY_CODES
    .slice()
    .sort((a, b) => b.code.length - a.code.length) // longest prefix first (+974 before +97, etc.)
    .find((c) => v.startsWith(c.code));
  if (match) {
    return { code: match.code, number: v.slice(match.code.length).trim() };
  }
  return { code: "+977", number: v };
}

/**
 * A phone field with a country-code prefix, defaulting to Nepal. Stores and
 * reports the combined "+9779800000000" form (no separating space) through
 * the same single `value`/`onChange` a plain text input would use — every
 * existing phone validator in this codebase (accounts/serializers.py's
 * validate_phone, Flutter's Validators.phone) matches `^\+?\d{7,15}$` with
 * no whitespace allowed, so a space here would fail that check.
 */
export default function PhoneInput({ value, onChange, placeholder = "98XXXXXXXX", className = "" }) {
  const parsed = useMemo(() => splitPhone(value), [value]);
  const [code, setCode] = useState(parsed.code);

  const emit = (nextCode, nextNumber) => {
    const number = nextNumber.trim();
    onChange(number ? `${nextCode}${number}` : "");
  };

  return (
    <div className={`flex gap-2 ${className}`}>
      <select
        value={code}
        onChange={(e) => { setCode(e.target.value); emit(e.target.value, parsed.number); }}
        className="w-23 shrink-0 rounded-lg bg-navy-800 border border-navy-700 px-2 py-2 text-sm text-white focus:border-orange-500 focus:outline-none"
      >
        {COUNTRY_CODES.map((c) => (
          <option key={c.code} value={c.code}>{c.flag} {c.code}</option>
        ))}
      </select>
      <input
        type="tel"
        inputMode="tel"
        value={parsed.number}
        onChange={(e) => emit(code, e.target.value)}
        placeholder={placeholder}
        className="min-w-0 flex-1 rounded-lg bg-navy-800 border border-navy-700 px-3 py-2 text-sm text-white placeholder-navy-500 focus:border-orange-500 focus:outline-none"
      />
    </div>
  );
}
