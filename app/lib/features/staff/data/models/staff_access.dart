/// How much of one feature (module) a staff member gets — the choices the owner
/// picks from when creating or editing staff. Each maps onto the
/// {view, create, edit, delete} flags the server enforces per module.
enum StaffAccess { none, view, add, edit, full }

/// The features an owner can grant or withhold, as (server key, label).
const staffModules = <(String, String)>[
  ('sales', 'Sales'),
  ('purchases', 'Purchases'),
  ('expenses', 'Expenses'),
  ('inventory', 'Inventory'),
  ('parties', 'Parties'),
  ('payments', 'Payments'),
  ('banking', 'Banking'),
  ('reports', 'Reports & profit'),
  ('staff', 'Staff management'),
];

String accessLabel(StaffAccess a) => switch (a) {
      StaffAccess.none => 'No access',
      StaffAccess.view => 'View only',
      StaffAccess.add => 'View & add',
      StaffAccess.edit => 'View, add & edit',
      StaffAccess.full => 'Full (can delete)',
    };

/// The exact flags for a level.
Map<String, bool> permissionsForAccess(StaffAccess a) => {
      'view': a != StaffAccess.none,
      'create': a == StaffAccess.add || a == StaffAccess.edit || a == StaffAccess.full,
      'edit': a == StaffAccess.edit || a == StaffAccess.full,
      'delete': a == StaffAccess.full,
    };

/// Which level [flags] amounts to, or null when it's a combination none of the
/// levels describe (e.g. edit without add) - shown as "Custom" and left as is
/// until the owner picks a level.
StaffAccess? accessOf(Map? flags) {
  if (flags == null) return null;
  bool on(String k) => flags[k] != false; // a flag not mentioned counts as allowed, like the server
  for (final level in StaffAccess.values) {
    final want = permissionsForAccess(level);
    if (want.entries.every((e) => on(e.key) == e.value)) return level;
  }
  return null;
}

/// The level for [module] in a full permission map. A module the owner never
/// configured is allowed - except "staff", which is never implied - exactly as
/// the server treats it.
StaffAccess? accessFor(Map<String, dynamic> permissions, String module) {
  final entry = permissions[module];
  if (entry is! Map) return module == 'staff' ? StaffAccess.none : StaffAccess.full;
  return accessOf(entry);
}

/// A copy of [permissions] with [module] set to [level].
Map<String, dynamic> withAccess(Map<String, dynamic> permissions, String module, StaffAccess level) => {
      ...permissions,
      module: permissionsForAccess(level),
    };

/// Whether two permission maps grant the same thing everywhere.
bool samePermissions(Map<String, dynamic> a, Map<String, dynamic> b) {
  for (final (module, _) in staffModules) {
    final x = a[module], y = b[module];
    for (final action in const ['view', 'create', 'edit', 'delete']) {
      bool flag(dynamic m) => m is Map ? m[action] != false : module != 'staff';
      if (flag(x) != flag(y)) return false;
    }
  }
  return true;
}
