/**
 * Tracks "recently picked" ids per business + item kind (e.g. products in
 * Sales, products in Purchases) so pickers can surface them first — the
 * common case of re-adding whatever you just used shouldn't require typing.
 * Scoped per business so switching businesses doesn't mix up recommendations.
 */
const MAX_RECENT = 8;

function storageKey(businessId, kind) {
  return `bw_recent_${kind}_${businessId}`;
}

export function getRecentIds(businessId, kind) {
  if (!businessId) return [];
  try {
    return JSON.parse(localStorage.getItem(storageKey(businessId, kind))) || [];
  } catch {
    return [];
  }
}

export function pushRecentId(businessId, kind, id) {
  if (!businessId || !id) return [];
  const existing = getRecentIds(businessId, kind).filter((x) => String(x) !== String(id));
  const updated = [id, ...existing].slice(0, MAX_RECENT);
  try {
    localStorage.setItem(storageKey(businessId, kind), JSON.stringify(updated));
  } catch {
    // Storage full/blocked — recommendations just won't persist, not fatal.
  }
  return updated;
}
