import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/product_service.dart';
import '../services/customer_service.dart';
import '../services/sales_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/common.dart';

class CartItem {
  final String productId;
  final String name;
  final double unitPrice;
  final double available;
  double quantity;
  CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.available,
    this.quantity = 1,
  });
  double get total => unitPrice * quantity;
}

class SalesPage extends StatefulWidget {
  final String? businessId;
  const SalesPage({super.key, this.businessId});
  @override State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> customers = [];
  final List<CartItem> cart = [];
  final search = TextEditingController();
  final discountCtl = TextEditingController();
  final paidCtl = TextEditingController();
  String query = '';
  String? customerId;
  String payment = 'cash';
  double discount = 0;
  double? paidInput; // null = المبلغ كامل
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
    NotificationService.instance.dataTick.addListener(_onRemoteChange);
  }

  @override
  void dispose() {
    NotificationService.instance.dataTick.removeListener(_onRemoteChange);
    search.dispose();
    discountCtl.dispose();
    paidCtl.dispose();
    super.dispose();
  }

  void _onRemoteChange() {
    if (mounted && !saving) load(silent: true);
  }

  Future<void> load({bool silent = false}) async {
    if (widget.businessId == null) {
      setState(() => loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        ProductService.list(widget.businessId!),
        CustomerService.list(widget.businessId!),
      ]);
      products = List<Map<String, dynamic>>.from(results[0]);
      customers = List<Map<String, dynamic>>.from(results[1]);
      // حدّث الكميات المتاحة للأصناف الموجودة في الفاتورة
      for (final item in cart.toList()) {
        final p = products.where((e) => e['id'] == item.productId);
        if (p.isEmpty) {
          cart.remove(item);
        }
      }
    } catch (_) {
      if (!silent && mounted) showSnack(context, 'تعذر تحميل البيانات.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double get subtotal => cart.fold(0, (a, b) => a + b.total);
  double get total => (subtotal - discount).clamp(0, double.infinity).toDouble();
  double get paidEffective =>
      payment == 'credit' ? 0 : (paidInput ?? total).clamp(0, total).toDouble();
  double get due => (total - paidEffective).clamp(0, double.infinity).toDouble();

  void addProduct(Map<String, dynamic> p) {
    final stock = (p['stock'] as num?)?.toDouble() ?? 0;
    if (stock <= 0) {
      showSnack(context, 'المنتج غير متوفر في المخزون.');
      return;
    }
    final id = p['id'] as String;
    final existing = cart.where((e) => e.productId == id);
    if (existing.isNotEmpty) {
      final item = existing.first;
      if (item.quantity < item.available) {
        setState(() => item.quantity += 1);
      } else {
        showSnack(context, 'وصلت للحد الأقصى المتاح من هذا الصنف.');
      }
      return;
    }
    setState(() => cart.add(CartItem(
          productId: id,
          name: '${p['name']}',
          unitPrice: (p['sale_price'] as num?)?.toDouble() ?? 0,
          available: stock,
        )));
  }

  Future<void> removeItem(CartItem item) async {
    setState(() => cart.remove(item));
  }

  Future<void> clearCart() async {
    if (cart.isEmpty) return;
    final ok = await confirmDelete(
      context,
      title: 'تفريغ الفاتورة',
      message: 'سيتم حذف كل الأصناف من الفاتورة الحالية. هل أنت متأكد؟',
      confirmLabel: 'تفريغ',
    );
    if (ok && mounted) setState(() => cart.clear());
  }

  Future<void> editQuantity(CartItem item) async {
    final v = await askText(
      context,
      title: item.name,
      message: 'المتاح في المخزون: ${qtyText(item.available)}',
      label: 'الكمية',
      confirmLabel: 'تعديل',
    );
    if (v == null) return;
    final q = parseAmount(v);
    if (q == null || q <= 0) {
      if (mounted) showSnack(context, 'أدخل كمية صحيحة.');
      return;
    }
    if (q > item.available) {
      if (mounted) showSnack(context, 'الكمية أكبر من المتاح (${qtyText(item.available)}).');
      return;
    }
    setState(() => item.quantity = q);
  }

  void onSearchSubmitted(String v, List<Map<String, dynamic>> filtered) {
    final q = v.trim().toLowerCase();
    if (q.isEmpty) return;
    final exact = products.where((p) => '${p['barcode'] ?? ''}'.toLowerCase() == q).toList();
    if (exact.isNotEmpty) {
      addProduct(exact.first);
    } else if (filtered.length == 1) {
      addProduct(filtered.first);
    } else {
      return;
    }
    search.clear();
    setState(() => query = '');
  }

  Future<void> checkout() async {
    if (widget.businessId == null || cart.isEmpty || saving) return;
    if (payment == 'credit' && customerId == null) {
      showSnack(context, 'اختر عميلًا عند البيع الآجل.');
      return;
    }
    if (payment != 'credit' && due > 0 && customerId == null) {
      showSnack(context, 'المبلغ المدفوع أقل من الإجمالي — اختر عميلًا لتسجيل المتبقي عليه.');
      return;
    }
    setState(() => saving = true);
    try {
      final result = await SalesService.createSale(
        businessId: widget.businessId!,
        customerId: customerId,
        items: cart.map((e) => {
          'product_id': e.productId,
          'quantity': e.quantity,
          'unit_price': e.unitPrice,
        }).toList(),
        discount: discount,
        paid: paidEffective,
        paymentMethod: payment,
      );
      if (!mounted) return;
      final invoice = result['invoice_number'];
      setState(() {
        cart.clear();
        customerId = null;
        discount = 0;
        paidInput = null;
        discountCtl.clear();
        paidCtl.clear();
      });
      NotificationService.instance.bump();
      await load(silent: true);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 40),
            title: const Text('تمت عملية البيع', textAlign: TextAlign.center),
            content: Text(
              'رقم الفاتورة: #$invoice\nالإجمالي: ${money(result['total'])}'
              '${toNum(result['due']) > 0 ? '\nالمتبقي: ${money(result['due'])}' : ''}',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.businessId == null) {
      return const Center(child: Text('قم بإعداد النشاط والاتصال بالسحابة أولًا.'));
    }
    if (loading) return const Center(child: CircularProgressIndicator());

    final filtered = products.where((p) {
      final q = query.toLowerCase();
      return '${p['name']}'.toLowerCase().contains(q) ||
          '${p['barcode'] ?? ''}'.toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 7, child: _products(filtered)),
              const SizedBox(width: 18),
              SizedBox(width: 390, child: _cart()),
            ])
          : Column(children: [
              Expanded(child: _products(filtered)),
              const SizedBox(height: 14),
              SizedBox(height: 430, child: _cart()),
            ]),
      );
    });
  }

  Widget _products(List<Map<String, dynamic>> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نقطة البيع', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text('ابحث عن المنتج وأضفه للفاتورة', style: TextStyle(color: AppTheme.muted)),
      ])),
      FilledButton.icon(onPressed: cart.isEmpty ? null : clearCart,
        icon: const Icon(Icons.delete_sweep_outlined), label: const Text('تفريغ')),
    ]),
    const SizedBox(height: 16),
    TextField(
      controller: search,
      onChanged: (v) => setState(() => query = v),
      onSubmitted: (v) => onSearchSubmitted(v, list),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.qr_code_scanner_rounded),
        hintText: 'اسم المنتج أو الباركود...',
      ),
    ),
    const SizedBox(height: 14),
    Expanded(
      child: list.isEmpty
        ? const Center(child: Text('لا توجد منتجات مطابقة.'))
        : LayoutBuilder(builder: (_, gc) => GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gc.maxWidth >= 700 ? 3 : 2,
              crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: 1.55,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              final stock = (p['stock'] as num?)?.toDouble() ?? 0;
              final url = p['image_url'] as String?;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => addProduct(p),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: AppTheme.card(radius: 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 34, height: 34,
                        child: (url != null && url.isNotEmpty)
                            ? Image.network(url, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppTheme.primary))
                            : const Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
                      ),
                    ),
                    const Spacer(),
                    Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(money(p['sale_price']), style: const TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text('متاح: ${qtyText(stock)}',
                        style: TextStyle(
                          color: stock <= 0 ? Colors.red.shade700 : AppTheme.muted,
                          fontSize: 12,
                          fontWeight: stock <= 0 ? FontWeight.w800 : FontWeight.w400)),
                    ]),
                  ]),
                ),
              );
            },
          )),
    ),
  ]);

  Widget _cartRow(CartItem item) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(money(item.unitPrice), style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
    ])),
    IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => setState(() {
        item.quantity = (item.quantity - 1).clamp(1, item.available).toDouble();
      }),
      icon: const Icon(Icons.remove_circle_outline, size: 20)),
    InkWell(
      onTap: () => editQuantity(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(qtyText(item.quantity), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
    IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => setState(() {
        if (item.quantity < item.available) item.quantity += 1;
      }),
      icon: const Icon(Icons.add_circle_outline, size: 20)),
    SizedBox(width: 74, child: Text(money(item.total), textAlign: TextAlign.end,
      style: const TextStyle(fontWeight: FontWeight.w700))),
    IconButton(
      tooltip: 'حذف من الفاتورة',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      onPressed: () => removeItem(item),
      icon: Icon(Icons.close_rounded, size: 20, color: Colors.red.shade700)),
  ]);

  Widget _cart() => Container(
    padding: const EdgeInsets.all(18),
    decoration: AppTheme.card(radius: 24),
    child: SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('الفاتورة الحالية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          Text('${cart.length} أصناف', style: const TextStyle(color: AppTheme.muted)),
        ]),
        const SizedBox(height: 12),
        cart.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('السلة فارغة', style: TextStyle(color: AppTheme.muted))),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cart.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.black12, height: 10),
                itemBuilder: (_, i) => _cartRow(cart[i]),
              ),
            ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: customerId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'العميل (اختياري)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('عميل نقدي')),
            ...customers.map((c) => DropdownMenuItem(
              value: c['id'] as String, child: Text('${c['name']}'))),
          ],
          onChanged: (v) => setState(() => customerId = v),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('الإجمالي قبل الخصم', style: TextStyle(color: AppTheme.muted))),
          Text(money(subtotal), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Expanded(child: Text('الخصم', style: TextStyle(color: AppTheme.muted))),
          SizedBox(width: 100, child: TextField(
            controller: discountCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => discount = parseAmount(v) ?? 0),
            decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: Text('طريقة الدفع', style: TextStyle(color: AppTheme.muted))),
          DropdownButton<String>(
            value: payment,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقدي')),
              DropdownMenuItem(value: 'card', child: Text('بطاقة')),
              DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
              DropdownMenuItem(value: 'credit', child: Text('آجل')),
            ],
            onChanged: (v) => setState(() {
              payment = v ?? 'cash';
              if (payment == 'credit') {
                paidInput = null;
                paidCtl.clear();
              }
            }),
          ),
        ]),
        if (payment != 'credit') ...[
          const SizedBox(height: 6),
          Row(children: [
            const Expanded(child: Text('المدفوع', style: TextStyle(color: AppTheme.muted))),
            SizedBox(width: 120, child: TextField(
              controller: paidCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => setState(() => paidInput = v.trim().isEmpty ? null : parseAmount(v)),
              decoration: InputDecoration(
                hintText: qtyText(total),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            )),
          ]),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
          ),
          child: Row(children: [
            const Expanded(child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w800))),
            Text(money(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ]),
        ),
        if (due > 0)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Text('متبقي على العميل: ${money(due)}', style: const TextStyle(color: Colors.orangeAccent))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
          onPressed: cart.isEmpty || saving ? null : checkout,
          icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
          label: Text(saving ? 'جارٍ حفظ الفاتورة...' : 'تأكيد البيع'),
        )),
      ]),
    ),
  );
}
