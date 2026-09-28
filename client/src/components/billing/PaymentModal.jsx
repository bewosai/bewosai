import { useState } from "react";
import { X, Crown, MessageCircle, Mail, QrCode } from "lucide-react";
import { PLAN_PRICES, PAYMENT_METHODS, PAYMENT_CONTACT } from "../../constants/payments";

const PLAN_LABELS = { PREMIUM: "Premium", PREMIUMPLUS: "Premium Plus" };

// Price + the eSewa / ConnectIPS QR codes for one plan, and how to get it
// activated afterwards (send the screenshot; a coupon comes back).
export default function PaymentModal({ plan, userEmail, businessName, onClose }) {
  const price = PLAN_PRICES[plan];
  const label = PLAN_LABELS[plan] || plan;
  const [missing, setMissing] = useState({});

  const note = `Hi Bewosai, I paid Rs ${price.amount} for ${label} (1 ${price.period}).\n`
    + `Email: ${userEmail || ""}\nBusiness: ${businessName || ""}\nScreenshot attached.`;
  const whatsappUrl = `https://wa.me/${PAYMENT_CONTACT.whatsapp}?text=${encodeURIComponent(note)}`;
  const mailUrl = `mailto:${PAYMENT_CONTACT.email}?subject=${encodeURIComponent(`Payment for ${label}`)}&body=${encodeURIComponent(note)}`;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" onClick={onClose}>
      <div className="max-h-[92vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-navy-700 bg-navy-900 p-5 shadow-2xl"
        onClick={e => e.stopPropagation()}>
        <div className="mb-4 flex items-start justify-between">
          <div>
            <h2 className="flex items-center gap-2 text-lg font-bold text-white">
              <Crown className="h-5 w-5 text-orange-400" /> Upgrade to {label}
            </h2>
            <p className="mt-1 text-2xl font-extrabold text-orange-400">
              Rs {price.amount.toLocaleString("en-IN")} <span className="text-sm font-medium text-navy-400">/ {price.period}</span>
            </p>
          </div>
          <button onClick={onClose} aria-label="Close"><X className="h-5 w-5 text-navy-400" /></button>
        </div>

        <p className="mb-3 text-sm text-navy-300">Scan either QR code and pay <b className="text-white">Rs {price.amount}</b>:</p>
        <div className="grid gap-3 sm:grid-cols-2">
          {PAYMENT_METHODS.map(m => (
            <div key={m.key} className={`rounded-xl border p-3 text-center ${m.accent}`}>
              <p className="mb-2 text-sm font-bold">{m.name}</p>
              {missing[m.key] ? (
                <div className="flex aspect-square items-center justify-center rounded-lg bg-navy-950 text-xs text-navy-500">
                  <div><QrCode className="mx-auto mb-1 h-8 w-8" />QR code coming soon</div>
                </div>
              ) : (
                <img src={m.qr} alt={`${m.name} QR code`} className="mx-auto aspect-square w-full rounded-lg bg-white object-contain p-2"
                  onError={() => setMissing(s => ({ ...s, [m.key]: true }))} />
              )}
            </div>
          ))}
        </div>

        <ol className="mt-4 list-decimal space-y-1.5 pl-5 text-sm text-navy-300">
          <li>Pay <b className="text-white">Rs {price.amount}</b> with eSewa or your bank app (ConnectIPS).</li>
          <li>Put your email <b className="text-white">{userEmail}</b> in the payment remarks.</li>
          <li>Send the payment screenshot to us — we'll activate {label} and send you a coupon code.</li>
          <li>Enter that code below under <b className="text-white">Have a Coupon?</b></li>
        </ol>

        <div className="mt-4 grid gap-2 sm:grid-cols-2">
          <a href={whatsappUrl} target="_blank" rel="noreferrer"
            className="flex items-center justify-center gap-2 rounded-xl bg-green-600 py-2.5 text-sm font-bold text-white hover:bg-green-500">
            <MessageCircle className="h-4 w-4" /> Send on WhatsApp
          </a>
          <a href={mailUrl}
            className="flex items-center justify-center gap-2 rounded-xl border border-navy-600 py-2.5 text-sm font-semibold text-navy-200 hover:border-navy-500">
            <Mail className="h-4 w-4" /> Email {PAYMENT_CONTACT.email}
          </a>
        </div>
        <p className="mt-2 text-center text-xs text-navy-500">Questions? Call {PAYMENT_CONTACT.phone}</p>
      </div>
    </div>
  );
}
