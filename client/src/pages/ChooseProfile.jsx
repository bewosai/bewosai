import { useState } from "react";
import { useNavigate } from "react-router-dom";
import bewosyLogo from "../assessts/images/bewosy.jpeg";
import { User, Building2, ArrowRight, ArrowLeft, Check } from "lucide-react";
import { ProfileCard, Steps } from "../components/auth/AuthWidgets";

/* ─── Choose Profile page — Step 1 of the signup flow ─────────────────────── */
export default function ChooseProfilePage() {
  const navigate = useNavigate();
  const [selectedProfile, setSelectedProfile] = useState("");

  const handleContinue = () => {
    if (!selectedProfile) return;
    navigate("/login", { state: { isSignup: true, accountType: selectedProfile } });
  };

  return (
    <div className="flex min-h-screen flex-col bg-navy-950">
      <div className="flex flex-1 flex-col items-center justify-center px-4 py-8 sm:py-12">
        <div className="w-full max-w-sm">

          {/* Logo */}
          <div className="mb-8 flex flex-col items-center gap-3 text-center">
            <div className="relative">
              <img
                src={bewosyLogo}
                alt="Bewosy"
                className="h-18 w-18 rounded-3xl object-cover shadow-xl shadow-orange-500/20 ring-2 ring-orange-500/30"
                style={{ height: 72, width: 72 }}
              />
              <div className="absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full bg-orange-500 shadow-md">
                <Check className="h-3.5 w-3.5 text-white" />
              </div>
            </div>
            <div>
              <h1 className="text-2xl font-extrabold text-white">Bewosy</h1>
              <p className="text-xs text-navy-400 mt-0.5">Smart Business Suite</p>
            </div>
          </div>

          {/* Card */}
          <div className="rounded-3xl border border-navy-800 bg-navy-900/80 px-6 py-7 shadow-2xl backdrop-blur-sm">

            <Steps current={1} steps={["Profile", "Email", "Verify"]} />

            <button
              type="button"
              onClick={() => navigate(-1)}
              className="mb-4 flex items-center gap-1.5 text-sm text-navy-400 hover:text-white transition"
            >
              <ArrowLeft className="h-4 w-4" /> Back
            </button>

            <div className="mb-5 text-center">
              <h2 className="text-xl font-bold text-white">Choose your profile</h2>
              <p className="mt-1.5 text-sm text-navy-400">
                Select once — this sets up your workspace
              </p>
            </div>

            <div className="space-y-3">
              <ProfileCard
                label="Business"
                description="Complete business management for shops, companies & teams"
                features={["Sales & Invoices", "Inventory", "Staff & Roles", "Reports", "Purchases"]}
                icon={Building2}
                iconColor="bg-orange-500/15 text-orange-500"
                selected={selectedProfile === "business"}
                onSelect={() => setSelectedProfile("business")}
              />
              <ProfileCard
                label="Personal Finance"
                description="Track personal income, expenses and budgets"
                features={["Income tracking", "Expenses", "Budget", "Reports"]}
                icon={User}
                iconColor="bg-blue-500/15 text-blue-500"
                selected={selectedProfile === "personal"}
                onSelect={() => setSelectedProfile("personal")}
              />
            </div>

            <button
              onClick={handleContinue}
              disabled={!selectedProfile}
              className="mt-5 flex w-full items-center justify-center gap-2 rounded-2xl bg-orange-500 py-4 text-base font-bold text-white transition hover:bg-orange-400 active:bg-orange-600 disabled:opacity-60"
            >
              Continue <ArrowRight className="h-4 w-4" />
            </button>

            <p className="mt-3 text-center text-xs text-navy-500">
              You can always add another workspace later
            </p>
          </div>

          <p className="mt-5 text-center text-xs text-navy-500">
            By continuing you agree to Bewosy's Terms of Service
          </p>
        </div>
      </div>
    </div>
  );
}
