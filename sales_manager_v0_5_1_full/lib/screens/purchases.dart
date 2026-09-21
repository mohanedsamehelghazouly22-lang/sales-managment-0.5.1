import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/purchase_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import 'details_sheets.dart';
import 'new_purchase.dart';

/// رصيد المورد: موجب = علينا له، سالب = له عندنا.
String supplierBalanceText(num b) {
  if (b > 0) return 'علينا ${money(b)}';
  if (b < 0) return 'لنا عنده ${money(-b)}';
  return 'مسوّى';
}

Color supplierBalanceColor(num b) {
  if (b > 0) return Colors.orange.shade800;
  if (b < 0) return Colors.green.shade700;
  return AppTheme.muted;
}

/// المشتريات والموردون.
class PurchasesPage extends StatelessWidget {
  final String? businessId;
  const PurchasesPage({super.key, this.businessId});

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
          const PageTitle('المشتريات والموردون', subtitle: 'فواتير الشراء وحسابات الموردين'),
          const SizedBox(height: 10),
          const TabBar(tabs: [
            Tab(text: 'فواتير الشراء'),
            Tab(text: 'الموردون'),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(children: [
              _PurchasesTab(businessId: businessId!),
              _SuppliersTab(businessId: businessId!),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── فواتير الشراء ─────────────────────────

class _PurchasesTab extends StatefulWidget {
  final String businessId;
  const _PurchasesTab({required this.businessId});
  @override
  State<_PurchasesTab> createState() => _PurchasesTabState();
}

class _PurchasesTabState extends State<_PurchasesTab> {
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
      rows = await PurchaseService.list(widget.businessId);
      error = null;
    } catch (e) {
      error = friendlyError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _new() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewPurchasePage(businessId: widget.businessId)),
    );
    if (saved == true) load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _new,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('فاتورة شراء جديدة'),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? EmptyBox(error!, icon: Icons.error_outline)
                : rows.isEmpty
                    ? const EmptyBox('لا توجد فواتير شراء بعد.', icon: Icons.shopping_cart_outlined)
                    : RefreshIndicator(
                        onRefresh: () => load(silent: true),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _tile(rows[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _tile(Map<String, dynamic> p) {
    final cancelled = p['status'] == 'cancelled';
    final due = toNum(p['total']) - toNum(p['paid']);
    final sup = (p['suppliers'] as Map?)?['name'];
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showPurchaseDetails(context, p['id'] as String, onChanged: load),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: AppTheme.card(radius: 16),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade700.withOpacity(.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.shopping_cart_rounded, color: Colors.blue.shade700, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('فاتورة شراء #${p['invoice_number']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  )),
              const SizedBox(height: 2),
              Text('${sup ?? 'بدون مورد'} • ${dateTimeText(p['created_at'])}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(p['total']), style: const TextStyle(fontWeight: FontWeight.w900)),
            if (cancelled)
              Pill('ملغاة', Colors.red.shade700)
            else if (due > 0)
              Pill('متبقي ${money(due)}', Colors.orange.shade800),
          ]),
        ]),
      ),
    );
  }
}

// ───────────────────────── الموردون ─────────────────────────

class _SuppliersTab extends StatefulWidget {
  final String businessId;
  const _SuppliersTab({required this.businessId});
  @override
  State<_SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<_SuppliersTab> {
  Future<void> _openForm({Map<String, dynamic>? supplier}) async {
    final res = await showDialog<_SupplierForm>(
      context: context,
      builder: (_) => _SupplierDialog(supplier: supplier),
    );
    if (res == null) return;
    try {
      if (supplier == null) {
        await SupplierService.add(
          businessId: widget.businessId, name: res.name, phone: res.phone, address: res.address,
        );
        if (mounted) showSnack(context, 'تمت إضافة المورد.');
      } else {
        await SupplierService.update(
          supplier['id'] as String, name: res.name, phone: res.phone, address: res.address,
        );
        if (mounted) showSnack(context, 'تم حفظ التعديلات.');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<bool> _delete(Map<String, dynamic> s) async {
    final b = toNum(s['balance']);
    final warn = b != 0 ? '\nتنبيه: رصيد المورد الحالي (${supplierBalanceText(b)}) وسيُحذف معه.' : '';
    final ok = await confirmDelete(
      context,
      title: 'حذف المورد',
      message: 'هل أنت متأكد من حذف "${s['name']}"؟\nلن تُحذف فواتير الشراء السابقة.$warn',
    );
    if (!ok) return false;
    try {
      await SupplierService.delete(s['id'] as String);
      NotificationService.instance.bump();
      if (mounted) showSnack(context, 'تم حذف المورد.');
      return true;
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
      return false;
    }
  }

  void _details(Map<String, dynamic> s) {
    showDetailSheet<void>(
      context,
      _SupplierSheet(
        businessId: widget.businessId,
        supplierId: s['id'] as String,
        onEdit: (sup) => _openForm(supplier: sup),
        onDelete: _delete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('إضافة مورد'),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupplierService.stream(widget.businessId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snap.data ?? [];
            if (rows.isEmpty) {
              return const EmptyBox('لا يوجد موردون بعد.', icon: Icons.local_shipping_outlined);
            }
            final owed = rows.fold<double>(0, (a, s) {
              final b = toNum(s['balance']).toDouble();
              return b > 0 ? a + b : a;
            });
            return ListView.separated(
              itemCount: rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return StatGrid([
                    StatBox('عدد الموردين', '${rows.length}', Icons.local_shipping_outlined),
                    StatBox('إجمالي المستحق للموردين', money(owed), Icons.account_balance_wallet_outlined,
                        color: Colors.orange.shade800),
                  ]);
                }
                final s = rows[i - 1];
                final b = toNum(s['balance']);
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _details(s),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppTheme.card(radius: 16),
                    child: Row(children: [
                      const CircleAvatar(child: Icon(Icons.local_shipping_rounded, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${s['phone'] ?? 'بدون رقم هاتف'}',
                              style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                        ]),
                      ),
                      Text(supplierBalanceText(b),
                          style: TextStyle(color: supplierBalanceColor(b), fontWeight: FontWeight.w800)),
                      const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _SupplierForm {
  final String name, phone, address;
  const _SupplierForm(this.name, this.phone, this.address);
}

class _SupplierDialog extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  const _SupplierDialog({this.supplier});
  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final TextEditingController name, phone, address;
  String? nameError;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    name = TextEditingController(text: s == null ? '' : '${s['name'] ?? ''}');
    phone = TextEditingController(text: s == null ? '' : '${s['phone'] ?? ''}');
    address = TextEditingController(text: s == null ? '' : '${s['address'] ?? ''}');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  void _submit() {
    final n = name.text.trim();
    if (n.isEmpty) {
      setState(() => nameError = 'اسم المورد مطلوب');
      return;
    }
    Navigator.pop(context, _SupplierForm(n, phone.text.trim(), address.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? 'إضافة مورد' : 'تعديل المورد'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: 'اسم المورد', errorText: nameError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
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

// ───────────────────────── كشف حساب المورد ─────────────────────────

class _SupplierSheet extends StatefulWidget {
  final String businessId;
  final String supplierId;
  final Future<void> Function(Map<String, dynamic> supplier) onEdit;
  final Future<bool> Function(Map<String, dynamic> supplier) onDelete;
  const _SupplierSheet({
    required this.businessId,
    required this.supplierId,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends State<_SupplierSheet> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final supplier = await SupplierService.get(widget.supplierId);
    final st = await SupplierService.statement(widget.supplierId);
    return {'supplier': supplier, 'purchases': st['purchases'], 'payments': st['payments']};
  }

  void _reload() => setState(() => future = _fetch());

  Future<void> _pay(Map<String, dynamic> s) async {
    final b = toNum(s['balance']);
    final p = await askPayment(
      context,
      title: 'سداد دفعة لـ ${s['name']}',
      hint: 'الرصيد الحالي: ${supplierBalanceText(b)}',
      initialAmount: b > 0 ? b.toDouble() : null,
    );
    if (p == null) return;
    try {
      await SupplierService.pay(
        businessId: widget.businessId,
        supplierId: widget.supplierId,
        amount: p.amount,
        method: p.method,
        note: p.note.isEmpty ? null : p.note,
      );
      NotificationService.instance.bump();
      if (mounted) {
        showSnack(context, 'تم تسجيل السداد.');
        _reload();
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return SizedBox(height: 220, child: EmptyBox(friendlyError(snap.error ?? 'error')));
        }
        final s = Map<String, dynamic>.from(snap.data!['supplier'] as Map);
        final purchases = List<Map<String, dynamic>>.from(snap.data!['purchases'] as List);
        final payments = List<Map<String, dynamic>>.from(snap.data!['payments'] as List);
        final b = toNum(s['balance']);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${s['name']}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const Divider(height: 18),
            InfoRow('الرصيد', supplierBalanceText(b), valueColor: supplierBalanceColor(b), bold: true),
            if (s['phone'] != null) InfoRow('الهاتف', '${s['phone']}'),
            if (s['address'] != null) InfoRow('العنوان', '${s['address']}'),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _pay(s),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('سداد دفعة'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.onEdit(s);
                  if (mounted) _reload();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final deleted = await widget.onDelete(s);
                  if (deleted) nav.pop();
                },
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                label: Text('حذف', style: TextStyle(color: Colors.red.shade700)),
              ),
            ]),
            const SizedBox(height: 20),
            const Text('فواتير الشراء', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            if (purchases.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد فواتير.', style: TextStyle(color: AppTheme.muted)),
              ),
            for (final p in purchases)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => showPurchaseDetails(context, p['id'] as String, onChanged: _reload),
                title: Text('#${p['invoice_number']}  •  ${money(p['total'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(dateTimeText(p['created_at'])),
                trailing: p['status'] == 'cancelled'
                    ? Pill('ملغاة', Colors.red.shade700)
                    : (toNum(p['total']) > toNum(p['paid'])
                        ? Pill('متبقي ${money(toNum(p['total']) - toNum(p['paid']))}', Colors.orange.shade800)
                        : null),
              ),
            const SizedBox(height: 14),
            const Text('الدفعات المسددة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد دفعات.', style: TextStyle(color: AppTheme.muted)),
              ),
            for (final p in payments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => showPaymentDetails(context, p['id'] as String),
                title: Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${dateTimeText(p['created_at'])}  •  ${paymentLabel(p['method'] as String?)}'),
              ),
          ]),
        );
      },
    );
  }
}
