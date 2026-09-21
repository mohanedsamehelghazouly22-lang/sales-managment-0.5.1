import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/product_service.dart';
import '../services/purchase_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class _Line {
  final String productId;
  final String name;
  double quantity;
  double cost;
  _Line(this.productId, this.name, this.quantity, this.cost);
  double get total => quantity * cost;
}

/// شاشة فاتورة شراء جديدة (استلام بضاعة من مورد).
class NewPurchasePage extends StatefulWidget {
  final String businessId;
  const NewPurchasePage({super.key, required this.businessId});
  @override
  State<NewPurchasePage> createState() => _NewPurchasePageState();
}

class _NewPurchasePageState extends State<NewPurchasePage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> suppliers = [];
  final List<_Line> lines = [];
  final TextEditingController paidCtl = TextEditingController();
  final TextEditingController noteCtl = TextEditingController();
  String? supplierId;
  double? paidInput;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    paidCtl.dispose();
    noteCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ProductService.list(widget.businessId);
      final s = await SupplierService.list(widget.businessId);
      products = p;
      suppliers = s;
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر تحميل البيانات.');
    }
    if (mounted) setState(() => loading = false);
  }

  double get total => lines.fold(0, (a, l) => a + l.total);
  double get paid => (paidInput ?? total).clamp(0, total).toDouble();
  double get due => total - paid;

  Future<void> _addProduct() async {
    final p = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.panel,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProductPicker(products: products),
    );
    if (p == null) return;
    final id = p['id'] as String;
    if (lines.any((l) => l.productId == id)) {
      if (mounted) showSnack(context, 'هذا الصنف مضاف بالفعل — عدّل كميته من القائمة.');
      return;
    }
    final line = _Line(id, '${p['name']}', 1, toNum(p['purchase_price']).toDouble());
    setState(() => lines.add(line));
    await _editLine(line);
  }

  Future<void> _editLine(_Line l) async {
    final res = await showDialog<(double, double)>(
      context: context,
      builder: (_) => _LineDialog(line: l),
    );
    if (res == null) return;
    setState(() {
      l.quantity = res.$1;
      l.cost = res.$2;
    });
  }

  Future<void> _save() async {
    if (lines.isEmpty || saving) return;
    if (due > 0 && supplierId == null) {
      showSnack(context, 'اختر مورّدًا لتسجيل المبلغ المتبقي عليه.');
      return;
    }
    setState(() => saving = true);
    try {
      final r = await PurchaseService.create(
        businessId: widget.businessId,
        supplierId: supplierId,
        items: lines.map((l) => {
          'product_id': l.productId,
          'quantity': l.quantity,
          'unit_price': l.cost,
        }).toList(),
        paid: paid,
        note: noteCtl.text.trim().isEmpty ? null : noteCtl.text.trim(),
      );
      NotificationService.instance.bump();
      if (!mounted) return;
      showSnack(context, 'تم حفظ فاتورة الشراء #${r['invoice_number']}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة شراء جديدة')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    DropdownButtonFormField<String>(
                      value: supplierId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'المورد (اختياري)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('بدون مورد')),
                        ...suppliers.map((s) => DropdownMenuItem(
                              value: s['id'] as String, child: Text('${s['name']}'))),
                      ],
                      onChanged: (v) => setState(() => supplierId = v),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Expanded(
                        child: Text('الأصناف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                      FilledButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة صنف'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: EmptyBox('أضف الأصناف المستلمة من المورد.', icon: Icons.add_shopping_cart_rounded),
                      ),
                    for (final l in lines)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.card(radius: 14),
                        child: Row(children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _editLine(l),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text('${qtyText(l.quantity)} × ${money(l.cost)}',
                                    style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                              ]),
                            ),
                          ),
                          Text(money(l.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () => _editLine(l),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'حذف من الفاتورة',
                            onPressed: () => setState(() => lines.remove(l)),
                            icon: Icon(Icons.close_rounded, size: 20, color: Colors.red.shade700),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: paidCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => setState(() => paidInput = v.trim().isEmpty ? null : parseAmount(v)),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع للمورد',
                        hintText: qtyText(total),
                        helperText: 'اتركه فارغًا لو دفعت الإجمالي كاملًا',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: noteCtl, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                      ),
                      child: Column(children: [
                        Row(children: [
                          const Expanded(child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w800))),
                          Text(money(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ]),
                        if (due > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(children: [
                              const Expanded(child: Text('المتبقي للمورد')),
                              Text(money(due), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: lines.isEmpty || saving ? null : _save,
                        icon: saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ فاتورة الشراء'),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}

// ───────────────────────── اختيار صنف ─────────────────────────

class _ProductPicker extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  const _ProductPicker({required this.products});
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.products.where((p) {
      final t = q.trim().toLowerCase();
      return t.isEmpty ||
          '${p['name']}'.toLowerCase().contains(t) ||
          '${p['barcode'] ?? ''}'.toLowerCase().contains(t);
    }).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن صنف...'),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: list.isEmpty
              ? const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد أصناف مطابقة.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text('${p['name']}'),
                      subtitle: Text('المخزون: ${qtyText(p['stock'])} • آخر تكلفة: ${money(p['purchase_price'])}'),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ───────────────────────── تعديل بند ─────────────────────────

class _LineDialog extends StatefulWidget {
  final _Line line;
  const _LineDialog({required this.line});
  @override
  State<_LineDialog> createState() => _LineDialogState();
}

class _LineDialogState extends State<_LineDialog> {
  late final TextEditingController qty;
  late final TextEditingController cost;
  String? qtyError, costError;

  @override
  void initState() {
    super.initState();
    qty = TextEditingController(text: qtyText(widget.line.quantity));
    cost = TextEditingController(text: widget.line.cost > 0 ? qtyText(widget.line.cost) : '');
  }

  @override
  void dispose() {
    qty.dispose();
    cost.dispose();
    super.dispose();
  }

  void _submit() {
    final q = parseAmount(qty.text);
    final c = parseAmount(cost.text);
    setState(() {
      qtyError = (q == null || q <= 0) ? 'أدخل كمية صحيحة' : null;
      costError = (c == null || c < 0) ? 'أدخل سعرًا صحيحًا' : null;
    });
    if (qtyError != null || costError != null) return;
    Navigator.pop(context, (q!, c!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.line.name),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: qty,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'الكمية المستلمة', errorText: qtyError),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'سعر الشراء للوحدة', errorText: costError),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('تم')),
      ],
    );
  }
}
