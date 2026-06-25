import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function ProtectedRoute({ children, forType }) {
  const { isLoggedIn, user, currentBusiness } = useAuth();

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

  return children;
}
