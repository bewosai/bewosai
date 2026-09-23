/**
 * What the signed-in person may do in the current business, from the
 * `my_permissions` table the server sends with each business
 * ({module: {view, create, edit, delete}}). The owner gets everything; a staff
 * member gets what the owner ticked.
 *
 * This only decides what to SHOW — the server refuses anything not allowed
 * regardless. If the table is missing (a session saved before it existed) we
 * show everything and let the server say no, rather than hide things wrongly.
 */
export function canDo(business, module, action = "view") {
  const table = business?.my_permissions;
  if (!table) return true;
  return table[module]?.[action] !== false;
}

/** Which permission module a page path belongs to (null = open to everyone signed in). */
const PATH_MODULES = [
  ["/sales", "sales"],
  ["/purchases", "purchases"],
  ["/expenses", "expenses"],
  ["/inventory", "inventory"],
  ["/parties", "parties"],
  ["/payments", "payments"],
  ["/banking", "banking"],
  ["/reports", "reports"],
  ["/staff", "staff"],
];

export function moduleForPath(path) {
  const clean = (path || "").split("?")[0];
  const hit = PATH_MODULES.find(([prefix]) => clean === prefix || clean.startsWith(prefix + "/"));
  return hit ? hit[1] : null;
}

const DELETABLE = ["sales", "purchases", "expenses", "inventory", "parties", "payments", "banking"];

/** Can this person reach the page at `path`? */
export function canOpenPath(business, path) {
  const clean = (path || "").split("?")[0];
  // Excel import writes products or parties.
  if (clean === "/import") return canDo(business, "inventory", "create") || canDo(business, "parties", "create");
  // The recycle bin only makes sense to someone who may delete something.
  if (clean === "/recycle-bin") return DELETABLE.some((m) => canDo(business, m, "delete"));
  const module = moduleForPath(clean);
  return module ? canDo(business, module, "view") : true;
}
