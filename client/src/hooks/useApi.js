import { useState, useEffect, useCallback } from "react";

/**
 * Generic data-fetching hook.
 * Usage: const { data, loading, error, refetch } = useApi(apiFn, params)
 */
export function useApi(apiFn, params = {}, deps = []) {
  const [data, setData]       = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState(null);

  const fetch = useCallback(() => {
    setLoading(true);
    setError(null);
    apiFn(params)
      .then(r => setData(r.data))
      .catch(e => setError(e?.response?.data?.detail || "Failed to load"))
      .finally(() => setLoading(false));
  }, deps); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { fetch(); }, [fetch]);

  return { data, loading, error, refetch: fetch };
}
