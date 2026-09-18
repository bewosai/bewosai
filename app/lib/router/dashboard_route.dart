/// The address that takes you to a tab of the main shell (0 Home, 1 Transactions,
/// 2 Parties, 3 Inventory, 4 More), optionally with a Transactions sub-tab
/// (0 Sales, 1 Purchases).
///
/// Every call carries a fresh `t` marker on purpose. The shell stays mounted
/// once it's open and switches its own tab locally, so asking for "/dashboard"
/// (or "?tab=1") again looked like *no change* to the router and nothing
/// happened — e.g. the Home button did nothing while you were on the Parties
/// tab. A new marker makes each request count.
int _requestCounter = 0;

String dashboardLocation({int tab = 0, int? subtab}) => Uri(
      path: '/dashboard',
      queryParameters: {
        'tab': '$tab',
        if (subtab != null) 'subtab': '$subtab',
        // The counter guarantees uniqueness even for two calls in one clock tick.
        't': '${DateTime.now().microsecondsSinceEpoch}-${_requestCounter++}',
      },
    ).toString();
