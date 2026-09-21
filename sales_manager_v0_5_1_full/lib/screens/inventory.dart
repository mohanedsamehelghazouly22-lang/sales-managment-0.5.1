import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/product_service.dart';
import '../services/inventory_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'details_sheets.dart';

/// المخزون: نظرة عامة + تسوية الكميات + سجل حركات المخزون.
class InventoryPage extends StatelessWidget {
  final String? businessId;
  const InventoryPage({super.key, this.businessId});

  @override
  Widget build(BuildContext context) {
    if (businessId == null) {
      return const EmptyBox('قم بإعداد النشاط والاتصال بالسحابة أولًا.');
    }
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageTitle('المخزون', subtitle: 'الكميات والتنبيهات وحركة الأصناف'),
          const SizedBox(height: 10),
          const TabBar(tabs: [
            Tab(text: 'الأصناف'),
            Tab(text: 'سجل الحركات'),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(children: [
              _StockTab(businessId: businessId!),
              _MovementsTab(businessId: businessId!),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── تبويب الأصناف ─────────────────────────

enum _StockFilter { all, low, out }

class _StockTab extends StatefulWidget {
  final String businessId;
  const _StockTab({required this.businessId});
  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  _StockFilter filter = _StockFilter.all;
  String search = '';

  bool _isOut(Map<String, dynamic> p) => toNum(p['stock']) <= 0;
  bool _isLow(Map<String, dynamic> p) =>
      toNum(p['stock']) > 0 && toNum(p['stock']) <= toNum(p['minimum_stock']);

  Future<void> _adjust(Map<String, dynamic> p) async {
    final res = await showDialog<_AdjustResult>(
      context: context,
      builder: (_) => _AdjustDialog(product: p),
    );
    if (res == null) return;
    try {
      await InventoryService.adjust(
        businessId: widget.businessId,
        productId: p['id'] as String,
        mode: res.mode,
        quantity: res.quantity,
        reason: res.reason.isEmpty ? null : res.reason,
        minStock: res.minStock,
      );
      NotificationService.instance.bump();
      if (mounted) showSnack(context, 'تم تحديث المخزون.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  void _history(Map<String, dynamic> p) {
    showDetailSheet<void>(
      context,
      _ProductMovementsSheet(businessId: widget.businessId, product: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ProductService.stream(widget.businessId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = (snap.data ?? []).where((p) => p['is_active'] != false).toList();
        var costValue = 0.0;
        var saleValue = 0.0;
        var low = 0;
        var out = 0;
        for (final p in all) {
          final s = toNum(p['stock']).toDouble();
          if (s > 0) {
            costValue += s * toNum(p['purchase_price']).toDouble();
            saleValue += s * toNum(p['sale_price']).toDouble();
          }
          if (_isOut(p)) {
            out++;
          } else if (_isLow(p)) {
            low++;
          }
        }
        final q = search.trim().toLowerCase();
        final rows = all.where((p) {
          final match = q.isEmpty ||
              '${p['name']}'.toLowerCase().contains(q) ||
              '${p['barcode'] ?? ''}'.toLowerCase().contains(q);
          final f = switch (filter) {
            _StockFilter.all => true,
            _StockFilter.low => _isLow(p),
            _StockFilter.out => _isOut(p),
          };
          return match && f;
        }).toList();

        return ListView.separated(
          itemCount: rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatGrid([
                  StatBox('عدد الأصناف', '${all.length}', Icons.inventory_2_outlined),
                  StatBox('قيمة المخزون (تكلفة)', money(costValue), Icons.savings_outlined),
                  StatBox('قيمة المخزون (بيع)', money(saleValue), Icons.sell_outlined,
                      color: Colors.green.shade700),
                  StatBox('منخفض / نافد', '$low / $out', Icons.warning_amber_rounded,
                      color: (low + out) > 0 ? Colors.red.shade700 : Colors.green.shade700),
                ]),
                const SizedBox(height: 12),
                FilterChips<_StockFilter>(
                  options: const [
                    ('الكل', _StockFilter.all),
                    ('منخفض', _StockFilter.low),
                    ('نافد', _StockFilter.out),
                  ],
                  selected: filter,
                  onSelected: (v) => setState(() => filter = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث بالاسم أو الباركود...',
                  ),
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: EmptyBox('لا توجد أصناف مطابقة.'),
                  ),
              ]);
            }
            return _row(rows[i - 1]);
          },
        );
      },
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final stock = toNum(p['stock']);
    final min = toNum(p['minimum_stock']);
    final out = _isOut(p);
    final low = _isLow(p);
    final color = out
        ? Colors.red.shade700
        : low
            ? Colors.orange.shade800
            : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.card(radius: 16),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
          alignment: Alignment.center,
          child: Text(qtyText(stock),
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${p['unit'] ?? 'قطعة'} • الحد الأدنى: ${qtyText(min)}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            if (out || low) ...[
              const SizedBox(height: 4),
              Pill(out ? 'نفد المخزون' : 'مخزون منخفض', color),
            ],
          ]),
        ),
        IconButton(
          tooltip: 'سجل الحركات',
          onPressed: () => _history(p),
          icon: const Icon(Icons.history_rounded),
        ),
        IconButton(
          tooltip: 'تسوية المخزون',
          onPressed: () => _adjust(p),
          icon: const Icon(Icons.tune_rounded),
        ),
      ]),
    );
  }
}

// ───────────────────────── حوار التسوية ─────────────────────────

class _AdjustResult {
  final String mode;
  final double quantity;
  final String reason;
  final double? minStock;
  const _AdjustResult(this.mode, this.quantity, this.reason, this.minStock);
}

class _AdjustDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  const _AdjustDialog({required this.product});
  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  String mode = 'add';
  final TextEditingController qty = TextEditingController();
  final TextEditingController reason = TextEditingController();
  late final TextEditingController minStock;
  String? qtyError, minError;

  @override
  void initState() {
    super.initState();
    minStock = TextEditingController(text: qtyText(widget.product['minimum_stock']));
  }

  @override
  void dispose() {
    qty.dispose();
    reason.dispose();
    minStock.dispose();
    super.dispose();
  }

  void _submit() {
    final q = parseAmount(qty.text);
    final m = parseAmount(minStock.text);
    final origMin = toNum(widget.product['minimum_stock']).toDouble();
    setState(() {
      qtyError = (q == null || q < 0) ? 'أدخل كمية صحيحة' : null;
      minError = (m == null || m < 0) ? 'أدخل رقمًا صحيحًا' : null;
    });
    if (qtyError != null || minError != null) return;
    Navigator.pop(
      context,
      _AdjustResult(mode, q!, reason.text.trim(), m == origMin ? null : m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = toNum(widget.product['stock']);
    return AlertDialog(
      title: Text('تسوية: ${widget.product['name']}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الكمية الحالية: ${qtyText(stock)}', style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: mode,
              decoration: const InputDecoration(labelText: 'نوع التسوية'),
              items: const [
                DropdownMenuItem(value: 'add', child: Text('إضافة كمية')),
                DropdownMenuItem(value: 'remove', child: Text('خصم كمية')),
                DropdownMenuItem(value: 'damage', child: Text('تالف / هالك')),
                DropdownMenuItem(value: 'set', child: Text('جرد (تحديد الكمية الفعلية)')),
              ],
              onChanged: (v) => setState(() => mode = v ?? 'add'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qty,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: mode == 'set' ? 'الكمية الفعلية' : 'الكمية',
                errorText: qtyError,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: minStock,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'حد التنبيه (الحد الأدنى)',
                errorText: minError,
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب / ملاحظة')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}

// ───────────────────────── حركات صنف واحد ─────────────────────────

class _ProductMovementsSheet extends StatelessWidget {
  final String businessId;
  final Map<String, dynamic> product;
  const _ProductMovementsSheet({required this.businessId, required this.product});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: InventoryService.movements(businessId, productId: product['id'] as String, limit: 100),
      builder: (context, snap) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('حركات: ${product['name']}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            InfoRow('الكمية الحالية', qtyText(product['stock']), bold: true),
            const Divider(height: 18),
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              EmptyBox(friendlyError(snap.error!))
            else if ((snap.data ?? []).isEmpty)
              const EmptyBox('لا توجد حركات لهذا الصنف.')
            else
              for (final m in snap.data!) _MovementTile(m, showProduct: false),
          ]),
        );
      },
    );
  }
}

class _MovementTile extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool showProduct;
  const _MovementTile(this.m, {required this.showProduct});

  @override
  Widget build(BuildContext context) {
    final q = toNum(m['quantity']);
    final prod = (m['products'] as Map?)?['name'];
    final note = (m['note'] ?? '').toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () => showMovementDetails(context, m['id'] as String),
      leading: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (q >= 0 ? Colors.green.shade700 : Colors.red.shade700).withOpacity(.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('${q > 0 ? '+' : ''}${qtyText(q)}',
            style: TextStyle(
              color: q >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w900, fontSize: 12)),
      ),
      title: Text(
        showProduct ? '${prod ?? 'صنف محذوف'} — ${InventoryService.typeLabel(m['movement_type'] as String?)}'
                    : InventoryService.typeLabel(m['movement_type'] as String?),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [dateTimeText(m['created_at']), if (note.isNotEmpty) note].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ───────────────────────── تبويب الحركات ─────────────────────────

class _MovementsTab extends StatefulWidget {
  final String businessId;
  const _MovementsTab({required this.businessId});
  @override
  State<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<_MovementsTab> {
  String type = 'all';
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
    NotificationService.instance.dataTick.addListener(_onTick);
  }

  @override
  void dispose() {
    NotificationService.instance.dataTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) load(silent: true);
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      rows = await InventoryService.movements(
        widget.businessId,
        type: type == 'all' ? null : type,
      );
      error = null;
    } catch (e) {
      error = friendlyError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FilterChips<String>(
        options: const [
          ('الكل', 'all'),
          ('بيع', 'sale'),
          ('شراء', 'purchase'),
          ('مرتجع / إلغاء', 'return'),
          ('تسوية', 'adjustment'),
          ('تالف', 'damage'),
        ],
        selected: type,
        onSelected: (v) {
          setState(() => type = v);
          load();
        },
      ),
      const SizedBox(height: 8),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? EmptyBox(error!, icon: Icons.error_outline)
                : rows.isEmpty
                    ? const EmptyBox('لا توجد حركات.', icon: Icons.swap_vert_rounded)
                    : RefreshIndicator(
                        onRefresh: () => load(silent: true),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                          itemBuilder: (_, i) => _MovementTile(rows[i], showProduct: true),
                        ),
                      ),
      ),
    ]);
  }
}
