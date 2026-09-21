import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/customer_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import 'details_sheets.dart';

/// رصيد العميل: موجب = عليه (مدين لنا)، سالب = له (دائن).
String customerBalanceText(num b) {
  if (b > 0) return 'عليه ${money(b)}';
  if (b < 0) return 'له ${money(-b)}';
  return 'مسوّى';
}

Color customerBalanceColor(num b) {
  if (b > 0) return Colors.orange.shade800;
  if (b < 0) return Colors.green.shade700;
  return AppTheme.muted;
}

class CustomersPage extends StatefulWidget {
  final String? businessId;
  const CustomersPage({super.key, this.businessId});
  @override State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String search = '';

  Future<void> _openForm({Map<String, dynamic>? customer}) async {
    final bid = widget.businessId;
    if (bid == null) return;
    final res = await showDialog<_CustomerForm>(
      context: context,
      builder: (_) => _CustomerDialog(customer: customer),
    );
    if (res == null) return;
    try {
      if (customer == null) {
        await CustomerService.add(
          businessId: bid, name: res.name, phone: res.phone,
          address: res.address, creditLimit: res.creditLimit,
        );
        if (mounted) showSnack(context, 'تمت إضافة العميل.');
      } else {
        await CustomerService.update(
          customer['id'] as String, name: res.name, phone: res.phone,
          address: res.address, creditLimit: res.creditLimit,
        );
        if (mounted) showSnack(context, 'تم حفظ التعديلات.');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<bool> _delete(Map<String, dynamic> c) async {
    final balance = toNum(c['balance']);
    final name = '${c['name'] ?? 'بدون اسم'}';
    final warn = balance != 0
        ? '\nتنبيه: رصيد العميل الحالي (${customerBalanceText(balance)}) وسيُحذف معه.'
        : '';
    final ok = await confirmDelete(
      context,
      title: 'حذف العميل',
      message: 'هل أنت متأكد من حذف "$name"؟\nلن تُحذف فواتيره السابقة لكنها ستظهر بدون اسم عميل.$warn',
    );
    if (!ok) return false;
    try {
      await CustomerService.delete(c['id'] as String);
      NotificationService.instance.bump();
      if (mounted) showSnack(context, 'تم حذف العميل.');
      return true;
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
      return false;
    }
  }

  void _openDetails(Map<String, dynamic> c) {
    final bid = widget.businessId;
    if (bid == null) return;
    showDetailSheet<void>(
      context,
      _CustomerSheet(
        businessId: bid,
        customerId: c['id'] as String,
        onEdit: (cust) => _openForm(customer: cust),
        onDelete: _delete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloud = widget.businessId != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageTitle(
          'العملاء والحسابات',
          subtitle: 'أرصدة العملاء وكشف الحساب والتحصيل',
          actions: [
            if (cloud)
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة عميل'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => search = v.trim().toLowerCase()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث بالاسم أو رقم الهاتف...',
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: cloud
            ? StreamBuilder<List<Map<String, dynamic>>>(
                stream: CustomerService.stream(widget.businessId!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? [];
                  final rows = all.where((c) =>
                      '${c['name'] ?? ''}'.toLowerCase().contains(search) ||
                      '${c['phone'] ?? ''}'.toLowerCase().contains(search)).toList();
                  if (rows.isEmpty) {
                    return EmptyBox(all.isEmpty ? 'لا يوجد عملاء بعد.' : 'لا توجد نتائج مطابقة.',
                        icon: Icons.people_outline);
                  }
                  final debt = all.fold<double>(0, (a, c) {
                    final b = toNum(c['balance']).toDouble();
                    return b > 0 ? a + b : a;
                  });
                  return ListView.separated(
                    itemCount: rows.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return StatGrid([
                          StatBox('عدد العملاء', '${all.length}', Icons.people_alt_rounded),
                          StatBox('إجمالي المديونيات', money(debt), Icons.account_balance_wallet_outlined,
                              color: Colors.orange.shade800),
                        ]);
                      }
                      return _row(rows[i - 1]);
                    },
                  );
                },
              )
            : const EmptyBox('يجب اختيار نشاط لعرض العملاء.'),
        ),
      ]),
    );
  }

  String _initial(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty) return '?';
    return n.substring(0, 1);
  }

  Widget _row(Map<String, dynamic> c) {
    final balance = toNum(c['balance']);
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => _openDetails(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.card(radius: 17),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: AppTheme.accent.withOpacity(.18),
            child: Text(_initial(c['name'] as String?)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['name'] ?? 'بدون اسم'}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${c['phone'] ?? 'بدون رقم هاتف'}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          ])),
          Text(
            customerBalanceText(balance),
            style: TextStyle(color: customerBalanceColor(balance), fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
        ]),
      ),
    );
  }
}

// ───────────────────────── نموذج العميل ─────────────────────────

class _CustomerForm {
  final String name, phone, address;
  final double creditLimit;
  const _CustomerForm(this.name, this.phone, this.address, this.creditLimit);
}

class _CustomerDialog extends StatefulWidget {
  final Map<String, dynamic>? customer;
  const _CustomerDialog({this.customer});
  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  late final TextEditingController name, phone, address, limit;
  String? nameError, limitError;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    name = TextEditingController(text: c == null ? '' : '${c['name'] ?? ''}');
    phone = TextEditingController(text: c == null ? '' : '${c['phone'] ?? ''}');
    address = TextEditingController(text: c == null ? '' : '${c['address'] ?? ''}');
    final l = c == null ? 0 : toNum(c['credit_limit']);
    limit = TextEditingController(text: l > 0 ? qtyText(l) : '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    limit.dispose();
    super.dispose();
  }

  void _submit() {
    final n = name.text.trim();
    final lim = limit.text.trim().isEmpty ? 0.0 : parseAmount(limit.text);
    setState(() {
      nameError = n.isEmpty ? 'اسم العميل مطلوب' : null;
      limitError = (lim == null || lim < 0) ? 'أدخل رقمًا صحيحًا' : null;
    });
    if (nameError != null || limitError != null) return;
    Navigator.pop(context, _CustomerForm(n, phone.text.trim(), address.text.trim(), lim!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'إضافة عميل' : 'تعديل العميل'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: 'اسم العميل', errorText: nameError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
            const SizedBox(height: 10),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
            const SizedBox(height: 10),
            TextField(
              controller: limit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الحد الائتماني (اختياري)',
                helperText: 'اتركه فارغًا لعدم التحديد',
                errorText: limitError,
              ),
            ),
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

// ───────────────────────── كشف حساب العميل ─────────────────────────

class _CustomerSheet extends StatefulWidget {
  final String businessId;
  final String customerId;
  final Future<void> Function(Map<String, dynamic> customer) onEdit;
  final Future<bool> Function(Map<String, dynamic> customer) onDelete;
  const _CustomerSheet({
    required this.businessId,
    required this.customerId,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final customer = await CustomerService.get(widget.customerId);
    final st = await CustomerService.statement(widget.customerId);
    return {'customer': customer, 'sales': st['sales'], 'payments': st['payments']};
  }

  void _reload() => setState(() => future = _fetch());

  Future<void> _receive(Map<String, dynamic> c) async {
    final balance = toNum(c['balance']);
    final p = await askPayment(
      context,
      title: 'تحصيل دفعة من ${c['name']}',
      hint: 'الرصيد الحالي: ${customerBalanceText(balance)}',
      initialAmount: balance > 0 ? balance.toDouble() : null,
    );
    if (p == null) return;
    try {
      await CustomerService.receivePayment(
        businessId: widget.businessId,
        customerId: widget.customerId,
        amount: p.amount,
        method: p.method,
        note: p.note.isEmpty ? null : p.note,
      );
      NotificationService.instance.bump();
      if (mounted) {
        showSnack(context, 'تم تسجيل الدفعة.');
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
        final c = Map<String, dynamic>.from(snap.data!['customer'] as Map);
        final sales = List<Map<String, dynamic>>.from(snap.data!['sales'] as List);
        final payments = List<Map<String, dynamic>>.from(snap.data!['payments'] as List);
        final balance = toNum(c['balance']);
        final limit = toNum(c['credit_limit']);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${c['name']}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const Divider(height: 18),
            InfoRow('الرصيد', customerBalanceText(balance),
                valueColor: customerBalanceColor(balance), bold: true),
            if (c['phone'] != null) InfoRow('الهاتف', '${c['phone']}'),
            if (c['address'] != null) InfoRow('العنوان', '${c['address']}'),
            if (limit > 0) InfoRow('الحد الائتماني', money(limit)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => _receive(c),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('تحصيل دفعة'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.onEdit(c);
                  if (mounted) _reload();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final deleted = await widget.onDelete(c);
                  if (deleted) nav.pop();
                },
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                label: Text('حذف', style: TextStyle(color: Colors.red.shade700)),
              ),
            ]),
            const SizedBox(height: 20),
            const Text('آخر الفواتير', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            if (sales.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد فواتير.', style: TextStyle(color: AppTheme.muted)),
              ),
            for (final s in sales)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => showSaleDetails(context, s['id'] as String, onChanged: _reload),
                title: Text('#${s['invoice_number']}  •  ${money(s['total'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${dateTimeText(s['created_at'])}  •  ${paymentLabel(s['payment_method'] as String?)}'),
                trailing: s['status'] == 'cancelled'
                    ? Pill('ملغاة', Colors.red.shade700)
                    : (toNum(s['total']) > toNum(s['paid'])
                        ? Pill('متبقي ${money(toNum(s['total']) - toNum(s['paid']))}', Colors.orange.shade800)
                        : null),
              ),
            const SizedBox(height: 14),
            const Text('الدفعات المحصّلة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
