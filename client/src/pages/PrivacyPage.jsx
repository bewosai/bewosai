import { Link } from "react-router-dom";

/* Public page at /privacy — the privacy policy link Google Play asks for.
   Keep it matching what the app really collects and where it is kept. */
const UPDATED = "23 October 2026";
const CONTACT = "bewosai@gmail.com";

function Section({ title, children }) {
  return (
    <section className="space-y-2">
      <h2 className="text-lg font-semibold text-white">{title}</h2>
      <div className="space-y-2 text-sm leading-relaxed text-navy-200">{children}</div>
    </section>
  );
}

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-navy-950 px-4 py-12 text-navy-100">
      <div className="mx-auto max-w-2xl space-y-8">
        <Link to="/" className="text-sm text-orange-400 hover:underline">← Bewosai</Link>
        <div>
          <h1 className="text-2xl font-bold text-white">Privacy Policy</h1>
          <p className="text-xs text-navy-500">Last updated {UPDATED}</p>
        </div>

        <Section title="Who we are">
          <p>Bewosai is a business management app (website and Android app) for shops and small businesses in Nepal:
            sales, purchases, stock, parties, payments, expenses, banking and reports. Contact: {CONTACT}.</p>
        </Section>

        <Section title="What we collect">
          <ul className="list-disc space-y-1 pl-5">
            <li><b>Account:</b> your email address, name and, if you add it, phone number.</li>
            <li><b>Business records you enter:</b> business profile (name, address, PAN/VAT), customers and suppliers,
              products and stock, invoices, purchases, payments, expenses and bank account records.</li>
            <li><b>Photos you choose to upload:</b> product images, business logo, bill photos, payment QR codes.</li>
            <li><b>Sign-in activity:</b> time of sign-in, IP address and whether it was the website or the app — shown to
              you and used to protect your account.</li>
            <li><b>Error reports:</b> if the app or website crashes, technical details of the error (no passwords,
              cookies or email addresses).</li>
          </ul>
          <p>We do not collect your location, contacts, or photos you don't pick. The app has no ads and no ad tracking.</p>
        </Section>

        <Section title="How we use it">
          <p>Only to run the service for you: to sign you in (login codes are sent to your email), store and show your
            business records, produce your reports, send reminders you set, and fix errors. We do not sell your data or
            share it for advertising.</p>
        </Section>

        <Section title="Who stores it for us">
          <p>Your data is kept with service providers that run the service on our behalf: Render (app server), Neon
            (database), Vercel (website), Cloudinary (uploaded images), SendGrid (login-code emails) and Sentry (error
            reports). Data is sent to them over encrypted connections (HTTPS).</p>
        </Section>

        <Section title="Who can see your business data">
          <p>You, and the staff members you add to your business with the access you give them. Bewosai's platform
            administrator can view business data to provide support and keep the service safe.</p>
        </Section>

        <Section title="How long we keep it, and deleting it">
          <p>We keep your data while your account exists. You can delete your account at any time — in the app under
            Settings → Delete Account, or on the web at <Link to="/delete-account" className="text-orange-400 underline">bewosai.com/delete-account</Link>.
            This permanently deletes your account and every business you own with all its records. Items you delete
            inside the app first go to its Recycle Bin, where you can restore or permanently delete them.</p>
        </Section>

        <Section title="Children">
          <p>Bewosai is meant for businesses and is not directed at children under 13.</p>
        </Section>

        <Section title="Changes and contact">
          <p>If this policy changes, the date above changes with it. Questions or requests about your data:
            {" "}<a href={`mailto:${CONTACT}`} className="text-orange-400 underline">{CONTACT}</a>.</p>
        </Section>
      </div>
    </div>
  );
}
