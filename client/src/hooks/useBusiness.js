import { useAuth } from "../context/AuthContext";

/**
 * Returns the current business id and a helper to build
 * the business query param object used by every API call.
 */
export function useBusiness() {
  const { currentBusiness } = useAuth();
  const id = currentBusiness?.id || localStorage.getItem("business_id") || "";
  return {
    businessId: id,
    bParams: id ? { business: id } : {},
  };
}
