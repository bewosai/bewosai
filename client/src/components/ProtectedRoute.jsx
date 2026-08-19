import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useLicense } from "../context/LicenseContext";

export default function ProtectedRoute({ children, forType }) {
  const { isLoggedIn, user, currentBusiness } = useAuth();
  const { loaded: licenseLoaded, hasActiveSubscription } = useLicense();

  if (!isLoggedIn) return <Navigate to="/login" replace />;

  // Personal users going to business routes → redirect to personal
  if (forType === "business" && user?.account_type === "personal") {
    return <Navigate to="/personal/dashboard" replace />;
  }

  // Business users going to personal routes → redirect to business
  if (forType === "personal" && user?.account_type === "business") {
    return <Navigate to="/dashboard" replace />;
  }

  // Business users with no business selected → pick one
  if (forType === "business" && !currentBusiness) {
    return <Navigate to="/select-business" replace />;
  }

  // Trial ended, no active license → block every business route until one
  // is activated. Wait for the license check to actually resolve first
  // (licenseLoaded) so a fresh login doesn't flash this before the real
  // status is known — LicenseContext fails open in the meantime.
  //
  // Platform admins are exempt: /superadmin is nested inside this same
  // business-type route, so gating it on the admin's own business
  // subscription would risk locking an admin out of the one panel that can
  // generate a license in the first place — including their own.
  if (forType === "business" && licenseLoaded && !hasActiveSubscription && !user?.is_platform_admin) {
    return <Navigate to="/license-required" replace />;
  }

  return children;
}
