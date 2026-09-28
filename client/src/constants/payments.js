// Plan prices and how to pay for them — one place to change them.
// No payment gateway: the customer scans a QR, pays, and sends the screenshot;
// Bewosai then issues a coupon for the plan, which they enter under
// "Have a coupon?" (see UpgradePlanPage).

export const PLAN_PRICES = {
  PREMIUM: { amount: 1999, period: "year" },
  PREMIUMPLUS: { amount: 1999, period: "year" },
};

// QR images live in client/public/payments/ — replace those files to change them.
export const PAYMENT_METHODS = [
  { key: "esewa", name: "eSewa", qr: "/payments/esewa-qr.png", accent: "text-green-400 border-green-500/30 bg-green-500/5" },
  { key: "connectips", name: "ConnectIPS", qr: "/payments/connectips-qr.png", accent: "text-blue-400 border-blue-500/30 bg-blue-500/5" },
];

export const PAYMENT_CONTACT = {
  whatsapp: "9779744895505", // wa.me format: country code + number, no "+"
  phone: "9744895505",
  email: "bewosai@gmail.com",
};
