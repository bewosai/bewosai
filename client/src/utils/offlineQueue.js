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
      // Only queue mutations that fail with a network error (no response = offline)
      const isNetworkError = !err.response && err.config;
      const isMutation = ["post", "patch", "put", "delete"].includes(
        err.config?.method?.toLowerCase()
      );

      if (isNetworkError && isMutation) {
        enqueue({
          method: err.config.method,
          url: err.config.url,
          data: err.config.data ? JSON.parse(err.config.data) : undefined,
          params: err.config.params,
        });
        return Promise.resolve({ data: { __queued: true }, status: 202 });
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
