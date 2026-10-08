// Staff roles and the access each starts with. A role only picks the starting
// ticks — the owner can change any of them, and what the server enforces is
// always the saved permission table. Kept in step with the app's
// defaultPermissionsFor() (app/lib/features/staff/data/services/staff_service.dart).

export const MODULES = ["sales", "purchases", "expenses", "inventory", "parties", "payments", "banking", "reports", "staff"];
export const ACTIONS = ["view", "create", "edit", "delete"];

export const MODULE_LABELS = {
  sales: "Sales",
  purchases: "Purchases",
  expenses: "Expenses",
  inventory: "Inventory",
  parties: "Customers & suppliers",
  payments: "Payments",
  banking: "Banking",
  reports: "Reports & profit",
  staff: "Staff management",
};

const FULL = { view: true, create: true, edit: true, delete: false };
const ALL = { view: true, create: true, edit: true, delete: true };
const ADD = { view: true, create: true, edit: false, delete: false };
const VIEW = { view: true, create: false, edit: false, delete: false };
const NONE = { view: false, create: false, edit: false, delete: false };

const preset = (map, rest = NONE) => Object.fromEntries(MODULES.map((m) => [m, { ...(map[m] || rest) }]));

export const ROLES = [
  {
    key: "PARTNER", label: "Business Partner", summary: "Everything in the business. Can't manage staff.",
    permissions: preset({ staff: NONE }, ALL),
  },
  {
    key: "MANAGER", label: "Manager", summary: "Runs daily work. Can't delete. Views banking and reports.",
    permissions: preset({
      sales: FULL, purchases: FULL, expenses: FULL, inventory: FULL, parties: FULL, payments: FULL,
      banking: VIEW, staff: VIEW, reports: VIEW,
    }),
  },
  {
    key: "ACCOUNTANT", label: "Accountant", summary: "Money: expenses, payments, banking and reports.",
    permissions: preset({
      sales: VIEW, purchases: VIEW, expenses: FULL, inventory: VIEW, parties: FULL, payments: FULL,
      banking: FULL, reports: VIEW,
    }),
  },
  {
    key: "SALESPERSON", label: "Salesperson", summary: "Makes sales, adds customers, takes payments. Sees stock.",
    permissions: preset({ sales: FULL, parties: ADD, inventory: VIEW, payments: ADD }),
  },
  {
    key: "CASHIER", label: "Cashier", summary: "Creates sales, expenses and payments. Views stock and reports.",
    permissions: preset({
      sales: ADD, expenses: ADD, inventory: VIEW, parties: ADD, payments: ADD, reports: VIEW,
    }),
  },
  {
    key: "ENTRY", label: "Entry Person", summary: "Enters sales, purchases, expenses and stock. Can't edit or delete.",
    permissions: preset({
      sales: ADD, purchases: ADD, expenses: ADD, inventory: ADD, parties: ADD, payments: ADD,
    }),
  },
  {
    key: "INVENTORY_MANAGER", label: "Inventory Manager", summary: "Stock and purchases. Sees suppliers.",
    permissions: preset({ inventory: FULL, purchases: FULL, parties: VIEW }),
  },
  {
    key: "VIEWER", label: "Viewer", summary: "Can look at everything, change nothing.",
    permissions: preset({ staff: NONE }, VIEW),
  },
];

export const ROLE_BY_KEY = Object.fromEntries(ROLES.map((r) => [r.key, r]));

export function roleLabel(key) {
  if (key === "OWNER") return "Admin";
  return ROLE_BY_KEY[key]?.label || key;
}

export function defaultPermissions(role) {
  return structuredClone((ROLE_BY_KEY[role] || ROLE_BY_KEY.CASHIER).permissions);
}

/** The full table with the server's defaults: not configured = allowed, except "staff". */
export function fullMatrix(permissions) {
  const p = permissions || {};
  return Object.fromEntries(MODULES.map((m) => {
    const row = p[m];
    if (!row || typeof row !== "object") return [m, Object.fromEntries(ACTIONS.map((a) => [a, m !== "staff"]))];
    return [m, Object.fromEntries(ACTIONS.map((a) => [a, row[a] !== false]))];
  }));
}

export function staffInviteUrl(token) {
  return `${window.location.origin}/staff/invite/${token}`;
}

export function inviteMessage(name, businessName, url) {
  return `Hi${name ? ` ${name}` : ""}, you're invited to join ${businessName || "our business"} on Bewosai. `
    + `Open this link, verify your email and accept:\n${url}\n\nThe link works once and expires in 7 days.`;
}
