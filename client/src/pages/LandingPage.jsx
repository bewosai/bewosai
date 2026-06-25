import { Link } from "react-router-dom";
import bewosyLogo from "../assessts/images/bewosy.jpeg";
import {
  ShoppingCart, Users, Package, BarChart3, Monitor, UserCheck,
  Image, MessageCircle, Building2, Shield, Upload, FileText,
  Bell, WifiOff, Heart, CreditCard, Share2, Globe, Cloud,
  ArrowRight, CheckCircle2, Star,
} from "lucide-react";

const features = [
  {
    icon: ShoppingCart,
    title: "Add Sales, Purchases & Expenses",
    desc: "Record every transaction instantly. Track daily income and outgoing costs in one tap.",
  },
  {
    icon: Users,
    title: "Manage Parties",
    desc: "Manage customers & suppliers ledger. Know who owes you and who you owe.",
  },
  {
    icon: Package,
    title: "Manage Inventory",
    desc: "Keep track of products in real time. Get alerts when stock runs low.",
  },
  {
    icon: BarChart3,
    title: "Business Insights",
    desc: "View business performance reports. Understand profit, loss, and growth trends.",
  },
  {
    icon: Monitor,
    title: "Desktop Web Version",
    desc: "Manage business from computer. Full-featured dashboard on any browser.",
  },
  {
    icon: UserCheck,
    title: "Multi-Staff",
    desc: "Add users & manage their access. Assign roles — owner, manager, cashier, viewer.",
  },
  {
    icon: Image,
    title: "Upload Bill Images",
    desc: "Organize paper bills & receipts. Attach images to expenses and purchases.",
  },
  {
    icon: MessageCircle,
    title: "Send Payment Reminders",
    desc: "Send reminders via WhatsApp & SMS. Reduce overdue payments automatically.",
  },
  {
    icon: Building2,
    title: "Manage Bank Accounts",
    desc: "Track your balance in one place. Multiple accounts, one cash book.",
  },
  {
    icon: Globe,
    title: "Multi Business",
    desc: "Manage multiple stores in one place. Switch between businesses instantly.",
  },
  {
    icon: Shield,
    title: "Enhanced Security",
    desc: "Enable app lock & privacy mode. PIN protection and role-based access.",
  },
  {
    icon: Upload,
    title: "Bulk Import Data",
    desc: "Import your parties & inventory easily. Upload Excel files to save time.",
  },
  {
    icon: FileText,
    title: "Send Quotations",
    desc: "Share quotations with your customers. Convert quotes to invoices in one click.",
  },
  {
    icon: Bell,
    title: "Low Stock Alerts",
    desc: "Get notified when it is time to restock. Never run out of your best sellers.",
  },
  {
    icon: WifiOff,
    title: "Works Offline",
    desc: "Use the app even without internet. Data syncs automatically when reconnected.",
  },
  {
    icon: Heart,
    title: "Greeting Cards",
    desc: "Share beautiful posts with customers. Build relationships beyond transactions.",
  },
  {
    icon: CreditCard,
    title: "Create Business Card",
    desc: "Share professional business cards. Make a strong first impression digitally.",
  },
  {
    icon: Share2,
    title: "Share Transactions",
    desc: "Send transaction link/pdf with contacts. PDF invoices, A4 & thermal printing.",
  },
  {
    icon: Globe,
    title: "Built for Nepal",
    desc: "Use app in Nepali language & calendar. Designed for the Nepali business owner.",
  },
  {
    icon: Cloud,
    title: "Data Backup & Security",
    desc: "All data is securely stored in the cloud. Auto backup, restore anytime.",
  },
];

const plans = [
  {
    name: "Free",
    price: "Rs. 0",
    period: "forever",
    color: "border-navy-700",
    badge: null,
    features: [
      "1 Business Profile",
      "1 User Account",
      "Basic Inventory Management",
      "Customer & Supplier Management",
      "Sales & Expense Tracking",
      "1 Bank Account",
      "Offline & Online Access",
      "Basic Invoices",
      "100 Report Downloads",
    ],
  },
  {
    name: "Premium",
    price: "Rs. 499",
    period: "per month",
    color: "border-orange-500",
    badge: "Most Popular",
    features: [
      "Up to 5 Business Profiles",
      "Up to 5 Staff Members",
      "Multi-User Access",
      "Unlimited Transactions & Reports",
      "Multiple Bank Accounts",
      "Bill & Product Image Upload",
      "Barcode Generation",
      "Excel Import & Export",
      "Thermal Printer Support",
      "Custom Invoice Templates",
      "App Lock & Cloud Backup",
    ],
  },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-navy-950 text-white">
      {/* Navbar */}
      <nav className="sticky top-0 z-50 border-b border-navy-800 bg-navy-950/90 backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <img src={bewosyLogo} alt="Bewosy" className="h-9 w-9 rounded-xl object-cover" />
            <span className="text-xl font-bold tracking-tight text-white">Bewosy</span>
          </div>
          <div className="flex items-center gap-3">
            <Link
              to="/login"
              className="rounded-xl border border-navy-700 px-4 py-2 text-sm font-medium text-white transition hover:border-orange-500 hover:text-orange-400"
            >
              Log In
            </Link>
            <Link
              to="/register"
              className="rounded-xl bg-orange-500 px-4 py-2 text-sm font-bold text-white transition hover:bg-orange-400"
            >
              Get Started Free
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative overflow-hidden py-20 sm:py-28">
        <div className="absolute inset-0 bg-linear-to-br from-navy-800/30 via-navy-950 to-navy-950" />
        <div className="absolute -left-20 top-10 h-96 w-96 rounded-full bg-orange-500/10 blur-3xl" />
        <div className="absolute -right-20 bottom-0 h-96 w-96 rounded-full bg-navy-700/30 blur-3xl" />

        <div className="relative mx-auto max-w-4xl px-4 text-center sm:px-6">
          <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-orange-500/30 bg-orange-500/10 px-4 py-2 text-sm text-orange-300">
            <span className="h-2 w-2 rounded-full bg-orange-400" />
            Built for Nepali businesses
          </div>

          <div className="mb-6 flex justify-center">
            <img src={bewosyLogo} alt="Bewosy" className="h-20 w-20 rounded-3xl object-cover shadow-2xl shadow-orange-500/20" />
          </div>

          <h1 className="text-4xl font-extrabold leading-tight tracking-tight sm:text-6xl">
            Manage your business{" "}
            <span className="text-orange-500">smarter</span>
          </h1>

          <p className="mx-auto mt-5 max-w-2xl text-lg leading-8 text-navy-200">
            Manage sales, inventory, expenses, customers, staff, and reports in one
            place — without the complexity of VAT/PAN billing.
          </p>

          <div className="mt-10 flex flex-wrap justify-center gap-4">
            <Link
              to="/register"
              className="inline-flex items-center gap-2 rounded-2xl bg-orange-500 px-8 py-4 text-base font-bold text-white shadow-lg shadow-orange-500/30 transition hover:bg-orange-400"
            >
              Start Free Today <ArrowRight className="h-5 w-5" />
            </Link>
            <Link
              to="/login"
              className="inline-flex items-center gap-2 rounded-2xl border border-navy-700 px-8 py-4 text-base font-medium text-white transition hover:border-orange-500 hover:text-orange-400"
            >
              Sign In
            </Link>
          </div>

          <div className="mt-10 flex flex-wrap justify-center gap-6 text-sm text-navy-300">
            {["Free to start", "No VAT/PAN required", "Works offline", "Nepali calendar"].map((t) => (
              <span key={t} className="flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 text-orange-400" /> {t}
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-16 sm:py-20">
        <div className="mx-auto max-w-7xl px-4 sm:px-6">
          <div className="mb-12 text-center">
            <h2 className="text-3xl font-bold sm:text-4xl">
              Everything your business needs
            </h2>
            <p className="mt-3 text-navy-300">
              20+ powerful features — all in one app
            </p>
          </div>

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {features.map(({ icon: Icon, title, desc }) => (
              <div
                key={title}
                className="group rounded-2xl border border-navy-800 bg-navy-900/70 p-5 transition hover:border-orange-500/50 hover:bg-navy-800/80"
              >
                <div className="mb-3 flex h-11 w-11 items-center justify-center rounded-2xl bg-orange-500/15 text-orange-400 transition group-hover:bg-orange-500/25">
                  <Icon className="h-5 w-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">{title}</h3>
                <p className="mt-1.5 text-xs leading-5 text-navy-300">{desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Plans */}
      <section className="py-16 sm:py-20">
        <div className="mx-auto max-w-5xl px-4 sm:px-6">
          <div className="mb-12 text-center">
            <h2 className="text-3xl font-bold sm:text-4xl">Simple, honest pricing</h2>
            <p className="mt-3 text-navy-300">Start free, upgrade when you grow</p>
          </div>

          <div className="grid gap-6 sm:grid-cols-2">
            {plans.map((plan) => (
              <div
                key={plan.name}
                className={`relative rounded-3xl border-2 ${plan.color} bg-navy-900/70 p-8`}
              >
                {plan.badge && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-orange-500 px-4 py-1 text-xs font-bold text-white">
                    {plan.badge}
                  </div>
                )}
                <div className="mb-6">
                  <h3 className="text-xl font-bold text-white">{plan.name} Plan</h3>
                  <div className="mt-2 flex items-end gap-1">
                    <span className="text-4xl font-extrabold text-white">{plan.price}</span>
                    <span className="mb-1 text-sm text-navy-300">/ {plan.period}</span>
                  </div>
                </div>
                <ul className="space-y-3">
                  {plan.features.map((f) => (
                    <li key={f} className="flex items-start gap-2.5 text-sm text-navy-200">
                      <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-orange-400" />
                      {f}
                    </li>
                  ))}
                </ul>
                <Link
                  to="/register"
                  className={`mt-8 block rounded-2xl py-3 text-center text-sm font-bold transition ${
                    plan.badge
                      ? "bg-orange-500 text-white hover:bg-orange-400"
                      : "border border-navy-700 text-white hover:border-orange-500 hover:text-orange-400"
                  }`}
                >
                  Get Started
                </Link>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-navy-800 py-8">
        <div className="mx-auto max-w-7xl px-4 sm:px-6">
          <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
            <div className="flex items-center gap-2">
              <img src={bewosyLogo} alt="Bewosy" className="h-7 w-7 rounded-lg object-cover" />
              <span className="font-bold text-white">Bewosy</span>
            </div>
            <p className="text-sm text-navy-400">
              © 2026 Bewosy. Built for Nepal.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
