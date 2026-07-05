import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_settings.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_service.dart';
import '../../providers/business_provider.dart';

class QuickPosScreen extends StatefulWidget {
  const QuickPosScreen({super.key});

  @override
  State<QuickPosScreen> createState() => _QuickPosScreenState();
}

class _CartItem {
  final Map<String, dynamic> product;
  double qty = 1;
  double price;
  double discount = 0;

  _CartItem({required this.product, required this.price});

  double get lineTotal => (price * qty) - discount;
  int get productId => product['id'] as int;
  String get name => product['name']?.toString() ?? '';
}

class _QuickPosScreenState extends State<QuickPosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final List<_CartItem> _cart = [];

  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _customers = [];

  String _paymentMethod = 'CASH';
  String _notes = '';
  bool _loading = false;
  bool _saving = false;

  static const _paymentMethods = [
    {'key': 'CASH',   'label': 'Cash',   'icon': Icons.payments_rounded},
    {'key': 'BANK',   'label': 'Bank',   'icon': Icons.account_balance_rounded},
    {'key': 'ESEWA',  'label': 'eSewa',  'icon': Icons.phone_android_rounded},
    {'key': 'KHALTI', 'label': 'Khalti', 'icon': Icons.phone_android_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final r1 = await api.get('/inventory/products/');
      final r2 = await api.get('/parties/', params: {'party_type': 'CUSTOMER'});
      _allProducts = List<Map<String, dynamic>>.from((r1.data as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)));
      _customers = List<Map<String, dynamic>>.from((r2.data as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _filterProducts(String q) {
    if (q.isEmpty) {
      setState(() => _filteredProducts = []);
      return;
    }
    final query = q.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts
          .where((p) =>
              (p['name']?.toString().toLowerCase().contains(query) ?? false) ||
              (p['barcode']?.toString().contains(q) ?? false))
          .take(8)
          .toList();
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    final price = double.tryParse(product['selling_price']?.toString() ?? '0') ?? 0;
    final existing = _cart.indexWhere((c) => c.productId == (product['id'] as int));
    if (existing >= 0) {
      setState(() => _cart[existing].qty += 1);
    } else {
      setState(() => _cart.add(_CartItem(product: product, price: price)));
    }
    _searchCtrl.clear();
    setState(() => _filteredProducts = []);
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  double get _subtotal =>
      _cart.fold(0, (s, item) => s + item.lineTotal);

  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to cart')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final biz = context.read<BusinessProvider>();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final saleData = {
        'sale_date': dateStr,
        'status': 'CONFIRMED',
        'payment_method': _paymentMethod,
        'notes': _notes,
        if (_selectedCustomer != null) 'party': _selectedCustomer!['id'],
        'items': _cart.map((item) => {
              'product': item.productId,
              'quantity': item.qty,
              'unit_price': item.price,
              'discount': item.discount,
            }).toList(),
      };

      final result = await biz.createSale(saleData);
      if (!mounted) return;

      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.errorMessage(e)), backgroundColor: AppColors.error),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showSuccessDialog(Map<String, dynamic> sale) {
    final settings = context.read<AppSettings>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sale Saved!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              sale['invoice_number']?.toString() ?? '',
              style: const TextStyle(color: AppColors.navy500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              settings.formatAmount(_subtotal),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCart();
            },
            child: const Text('New Sale'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.home_rounded, size: 16),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _selectedCustomer = null;
      _paymentMethod = 'CASH';
      _notes = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final isDark = settings.isDark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        title: const Text(
          'Quick POS',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                _buildSearchBar(isDark, surface),
                // Search results dropdown
                if (_filteredProducts.isNotEmpty)
                  _buildSearchDropdown(surface, settings),
                // Customer selector
                _buildCustomerBar(surface, settings),
                // Cart
                Expanded(
                  child: _cart.isEmpty
                      ? _buildEmptyCart()
                      : _buildCart(settings),
                ),
                // Bottom checkout bar
                _buildCheckoutBar(settings, surface),
              ],
            ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color surface) {
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _filterProducts,
        autofocus: _cart.isEmpty,
        decoration: InputDecoration(
          hintText: 'Search item by name or barcode...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.orange),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _filteredProducts = []);
                  },
                )
              : const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.navy500),
          filled: true,
          fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchDropdown(Color surface, AppSettings settings) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _filteredProducts.length,
        itemBuilder: (ctx, i) {
          final p = _filteredProducts[i];
          final price = double.tryParse(p['selling_price']?.toString() ?? '0') ?? 0;
          final stock = p['current_stock']?.toString() ?? '0';
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.orange, size: 20),
            ),
            title: Text(p['name']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Stock: $stock',
                style: const TextStyle(fontSize: 11, color: AppColors.navy500)),
            trailing: Text(
              settings.formatAmount(price),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                  fontSize: 14),
            ),
            onTap: () => _addToCart(p),
          );
        },
      ),
    );
  }

  Widget _buildCustomerBar(Color surface, AppSettings settings) {
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => _pickCustomer(settings),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _selectedCustomer != null
                ? AppColors.orange.withOpacity(0.08)
                : AppColors.lightBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedCustomer != null
                  ? AppColors.orange.withOpacity(0.4)
                  : AppColors.lightBorder,
            ),
          ),
          child: Row(children: [
            Icon(
              Icons.person_rounded,
              size: 18,
              color: _selectedCustomer != null
                  ? AppColors.orange
                  : AppColors.navy500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCustomer != null
                    ? _selectedCustomer!['name']?.toString() ?? 'Customer'
                    : 'Select Customer (optional)',
                style: TextStyle(
                  color: _selectedCustomer != null
                      ? AppColors.orange
                      : AppColors.navy500,
                  fontWeight: _selectedCustomer != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (_selectedCustomer != null)
              GestureDetector(
                onTap: () => setState(() => _selectedCustomer = null),
                child: const Icon(Icons.clear_rounded,
                    size: 16, color: AppColors.navy500),
              )
            else
              const Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.navy500),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 48, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cart is empty',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search and add items above',
            style: TextStyle(color: AppColors.navy500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCart(AppSettings settings) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: _cart.length,
        itemBuilder: (ctx, i) {
          final item = _cart[i];
          return _CartItemTile(
            item: item,
            settings: settings,
            onRemove: () => _removeFromCart(i),
            onChanged: () => setState(() {}),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutBar(AppSettings settings, Color surface) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Payment method selector
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _paymentMethods.map((pm) {
                final selected = _paymentMethod == pm['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _paymentMethod = pm['key'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.orange
                            : AppColors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected
                              ? AppColors.orange
                              : AppColors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          pm['icon'] as IconData,
                          size: 14,
                          color: selected ? Colors.white : AppColors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pm['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.orange,
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Total row + save button
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_cart.length} item${_cart.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.navy500),
                  ),
                  Text(
                    settings.formatAmount(_subtotal),
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _saveSale,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _saving ? 'Saving...' : 'Save Sale',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _pickCustomer(AppSettings settings) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CustomerPicker(customers: _customers),
    );
    if (result != null) {
      setState(() => _selectedCustomer = result);
    }
  }
}

class _CartItemTile extends StatefulWidget {
  final _CartItem item;
  final AppSettings settings;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _CartItemTile({
    required this.item,
    required this.settings,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl =
        TextEditingController(text: widget.item.qty.toStringAsFixed(0));
    _priceCtrl =
        TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _discCtrl =
        TextEditingController(text: widget.item.discount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  void _update() {
    widget.item.qty = double.tryParse(_qtyCtrl.text) ?? 1;
    widget.item.price = double.tryParse(_priceCtrl.text) ?? 0;
    widget.item.discount = double.tryParse(_discCtrl.text) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final item = widget.item;
    final isDark = settings.isDark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            // Qty stepper
            _buildQtyField(),
            const SizedBox(width: 8),
            // Price
            Expanded(
              child: _SmallField(
                controller: _priceCtrl,
                label: 'Price',
                prefix: 'Rs.',
                onChanged: (_) => _update(),
              ),
            ),
            const SizedBox(width: 8),
            // Discount
            Expanded(
              child: _SmallField(
                controller: _discCtrl,
                label: 'Disc.',
                prefix: '-',
                onChanged: (_) => _update(),
              ),
            ),
            const SizedBox(width: 8),
            // Line total
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 10, color: AppColors.navy500)),
                Text(
                  settings.formatAmount(item.lineTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.orange,
                      fontSize: 13),
                ),
              ],
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildQtyField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () {
            if (widget.item.qty > 1) {
              widget.item.qty -= 1;
              _qtyCtrl.text = widget.item.qty.toStringAsFixed(0);
              widget.onChanged();
            }
          },
          icon: const Icon(Icons.remove_rounded,
              size: 16, color: AppColors.orange),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
        SizedBox(
          width: 36,
          child: TextField(
            controller: _qtyCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: (_) => _update(),
          ),
        ),
        IconButton(
          onPressed: () {
            widget.item.qty += 1;
            _qtyCtrl.text = widget.item.qty.toStringAsFixed(0);
            widget.onChanged();
          },
          icon: const Icon(Icons.add_rounded,
              size: 16, color: AppColors.orange),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

class _SmallField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String prefix;
  final ValueChanged<String> onChanged;

  const _SmallField({
    required this.controller,
    required this.label,
    required this.prefix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.navy500)),
        const SizedBox(height: 2),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixText: '$prefix ',
              prefixStyle: const TextStyle(
                  fontSize: 11, color: AppColors.navy500),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.orange, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerPicker extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  const _CustomerPicker({required this.customers});

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? widget.customers
          : widget.customers
              .where((c) =>
                  (c['name']?.toString().toLowerCase().contains(q.toLowerCase()) ??
                      false) ||
                  (c['phone']?.toString().contains(q) ?? false))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _filter,
              decoration: const InputDecoration(
                hintText: 'Search customer...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: _filtered.isEmpty
                ? const Center(child: Text('No customers found'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final c = _filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.orange.withOpacity(0.15),
                          child: Text(
                            (c['name']?.toString() ?? 'C').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(c['name']?.toString() ?? ''),
                        subtitle: Text(c['phone']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12)),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
