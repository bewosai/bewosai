/**
 * Offline queue: stores failed mutations and retries them when online.
 * Works with the axios instance — call wrapWithOfflineQueue(api) once.
 */

const QUEUE_KEY = "bw_offline_queue";
const LISTENERS = new Set();

export function getQueue() {
  try { return JSON.parse(localStorage.getItem(QUEUE_KEY)) || []; } catch { return []; }
}

function setQueue(q) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(q));
  LISTENERS.forEach((fn) => fn(q));
}

export function enqueue(item) {
  const q = getQueue();
  q.push({ ...item, id: Date.now() + Math.random(), queuedAt: new Date().toISOString() });
  setQueue(q);
}

export function removeFromQueue(id) {
  setQueue(getQueue().filter((i) => i.id !== id));
}

/** Subscribe to queue changes. Returns unsubscribe fn. */
export function subscribeQueue(fn) {
  LISTENERS.add(fn);
  return () => LISTENERS.delete(fn);
}

/** Flush all queued requests using the provided axios instance. */
export async function flushQueue(axiosInstance) {
  const q = getQueue();
  if (!q.length) return { flushed: 0, failed: 0 };

  let flushed = 0, failed = 0;

  for (const item of q) {
    try {
      await axiosInstance.request({
        method: item.method,
        url: item.url,
        data: item.data,
        params: item.params,
      });
      removeFromQueue(item.id);
      flushed++;
    } catch {
      failed++;
    }
  }

  return { flushed, failed };
}

/**
 * Wraps an axios instance so failed network requests (offline)
 * are automatically queued and retried when back online.
 */
export function wrapWithOfflineQueue(axiosInstance) {
  axiosInstance.interceptors.response.use(
    (res) => res,
    async (err) => {
      // A response-less error also fires for timeouts, CORS failures, and
      // the backend's Render cold-start connection resets — none of those
      // mean the browser is actually offline. Queuing those and faking a
      // success response (as this used to do) told the caller the write
      // succeeded, so it would reload the list from the server and the
      // never-actually-sent item would just be missing — "my last entry
      // isn't showing up" with no error and no clue why. Only treat it as
      // a real offline write when the browser itself confirms there's no
      // connection; every other network failure surfaces as a normal,
      // retryable error instead of a silent lie.
      const isNetworkError = !err.response && err.config;
      const isMutation = ["post", "patch", "put", "delete"].includes(
        err.config?.method?.toLowerCase()
      );
      const isReallyOffline = typeof navigator !== "undefined" && navigator.onLine === false;

      if (isNetworkError && isMutation && isReallyOffline) {
        enqueue({
          method: err.config.method,
          url: err.config.url,
          data: err.config.data ? JSON.parse(err.config.data) : undefined,
          params: err.config.params,
        });
        // Shaped like a normal axios error so every existing
        // `e.response?.data?.detail` error handler across the app
        // displays this without needing its own special case.
        return Promise.reject({
          isQueuedOffline: true,
          response: {
            data: {
              detail: "You're offline. This has been saved on your device and will sync automatically once you're back online.",
            },
          },
        });
      }

      return Promise.reject(err);
    }
  );
}

/** React hook: returns { isOnline, pendingCount, isSyncing, flush } */
import { useState, useEffect, useCallback } from "react";

export function useOfflineSync(axiosInstance) {
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [pendingCount, setPendingCount] = useState(getQueue().length);
  const [isSyncing, setIsSyncing] = useState(false);

  useEffect(() => {
    const unsub = subscribeQueue((q) => setPendingCount(q.length));
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      unsub();
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  // Auto-flush when coming back online
  useEffect(() => {
    if (isOnline && pendingCount > 0 && axiosInstance) {
      setIsSyncing(true);
      flushQueue(axiosInstance).finally(() => setIsSyncing(false));
    }
  }, [isOnline]);

  const flush = useCallback(async () => {
    if (!axiosInstance) return;
    setIsSyncing(true);
    try { await flushQueue(axiosInstance); } finally { setIsSyncing(false); }
  }, [axiosInstance]);

  return { isOnline, pendingCount, isSyncing, flush };
}
