import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/sales_service.dart';
import '../services/purchase_service.dart';
import '../services/expense_service.dart';
import '../services/history_service.dart';
import '../services/inventory_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';

// ───────────────────────── نقاط الدخول ─────────────────────────

Future<void> showSaleDetails(BuildContext context, String saleId, {VoidCallback? onChanged}) =>
    showDetailSheet<void>(context, _SaleSheet(saleId: saleId, onChanged: onChanged));

Future<void> showPurchaseDetails(BuildContext context, String purchaseId, {VoidCallback? onChanged}) =>
    showDetailSheet<void>(context, _PurchaseSheet(purchaseId: purchaseId, onChanged: onChanged));

Future<void> showExpenseDetails(BuildContext context, String expenseId, {VoidCallback? onChanged}) =>
    showDetailSheet<void>(context, _ExpenseSheet(expenseId: expenseId, onChanged: onChanged));

Future<void> showPaymentDetails(BuildContext context, String paymentId) =>
    showDetailSheet<void>(context, _PaymentSheet(paymentId: paymentId));

Future<void> showMovementDetails(BuildContext context, String movementId) =>
    showDetailSheet<void>(context, _MovementSheet(movementId: movementId));

// ───────────────────────── عناصر مشتركة ─────────────────────────

String _who(dynamic id) =>
    id != null && id == SupabaseService.currentUser?.id ? 'أنت' : 'مستخدم آخر';

class _FutureSheet extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  final Widget Function(BuildContext, Map<String, dynamic>) builder;
  const _FutureSheet({required this.future, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return SizedBox(
            height: 220,
            child: EmptyBox(friendlyError(snap.error ?? 'error'), icon: Icons.error_outline),
          );
        }
        return builder(context, snap.data!);
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  final String title;
  final Widget? badge;
  final List<Widget> children;
  const _SheetBody({required this.title, this.badge, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          if (badge != null) ...[badge!, const SizedBox(width: 6)],
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
        const Divider(height: 18),
        ...children,
      ]),
    );
  }
}

Widget _itemsTable(List items) {
  if (items.isEmpty) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('لا توجد أصناف', style: TextStyle(color: AppTheme.muted)),
    );
  }
  return Column(children: [
    for (final it in items)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(
              '${((it as Map)['products'] as Map?)?['name'] ?? 'صنف محذوف'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text('${qtyText(it['quantity'])} × ${money(it['unit_price'])}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(width: 10),
          Text(money(it['total']), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
  ]);
}

// ───────────────────────── فاتورة بيع ─────────────────────────

class _SaleSheet extends StatefulWidget {
  final String saleId;
  final VoidCallback? onChanged;
  const _SaleSheet({required this.saleId, this.onChanged});
  @override
  State<_SaleSheet> createState() => _SaleSheetState();
}

class _SaleSheetState extends State<_SaleSheet> {
  late Future<Map<String, dynamic>> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = SalesService.details(widget.saleId);
  }

  String _asText(Map<String, dynamic> s) {
    final b = StringBuffer();
    b.writeln('فاتورة بيع #${s['invoice_number']}');
    b.writeln('التاريخ: ${dateTimeText(s['created_at'])}');
    final cust = s['customers'] as Map?;
    if (cust != null) b.writeln('العميل: ${cust['name']}');
    b.writeln('------------------');
    for (final it in (s['sale_items'] as List? ?? const [])) {
      final m = it as Map;
      final name = (m['products'] as Map?)?['name'] ?? '—';
      b.writeln('$name  ${qtyText(m['quantity'])} × ${money(m['unit_price'])} = ${money(m['total'])}');
    }
    b.writeln('------------------');
    if (toNum(s['discount']) > 0) b.writeln('الخصم: ${money(s['discount'])}');
    b.writeln('الإجمالي: ${money(s['total'])}');
    b.writeln('المدفوع: ${money(s['paid'])}');
    final due = toNum(s['total']) - toNum(s['paid']);
    if (due > 0) b.writeln('المتبقي: ${money(due)}');
    return b.toString();
  }

  Future<void> _cancel(Map<String, dynamic> s) async {
    final reason = await askText(
      context,
      title: 'إلغاء الفاتورة #${s['invoice_number']}',
      message: 'سيتم إرجاع الأصناف إلى المخزون وتخفيض مديونية العميل (إن وجدت). لا يمكن التراجع عن هذا الإجراء.',
      label: 'سبب الإلغاء (اختياري)',
      confirmLabel: 'تأكيد الإلغاء',
      danger: true,
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await SalesService.cancel(widget.saleId, reason: reason.isEmpty ? null : reason);
      NotificationService.instance.bump();
      widget.onChanged?.call();
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم إلغاء الفاتورة وإرجاع الأصناف للمخزون.')));
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FutureSheet(
      future: future,
      builder: (context, s) {
        final cancelled = s['status'] == 'cancelled';
        final cust = s['customers'] as Map?;
        final items = (s['sale_items'] as List?) ?? const [];
        final due = toNum(s['total']) - toNum(s['paid']);
        return _SheetBody(
          title: 'فاتورة بيع #${s['invoice_number']}',
          badge: cancelled ? Pill('ملغاة', Colors.red.shade700) : Pill('مكتملة', Colors.green.shade700),
          children: [
            InfoRow('التاريخ', dateTimeText(s['created_at'])),
            InfoRow('العميل', '${cust?['name'] ?? 'عميل نقدي'}'),
            if (cust?['phone'] != null) InfoRow('الهاتف', '${cust!['phone']}'),
            InfoRow('طريقة الدفع', paymentLabel(s['payment_method'] as String?)),
            InfoRow('البائع', _who(s['cashier_id'])),
            if ((s['note'] ?? '').toString().isNotEmpty) InfoRow('ملاحظات', '${s['note']}'),
            if (cancelled) ...[
              InfoRow('تاريخ الإلغاء', dateTimeText(s['cancelled_at']), valueColor: Colors.red.shade700),
              InfoRow('ألغاها', _who(s['cancelled_by'])),
              if ((s['cancel_reason'] ?? '').toString().isNotEmpty)
                InfoRow('سبب الإلغاء', '${s['cancel_reason']}'),
            ],
            const SizedBox(height: 14),
            const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            _itemsTable(items),
            const Divider(height: 22),
            InfoRow('الإجمالي الفرعي', money(s['subtotal'])),
            if (toNum(s['discount']) > 0) InfoRow('الخصم', '- ${money(s['discount'])}'),
            if (toNum(s['tax']) > 0) InfoRow('الضريبة', money(s['tax'])),
            InfoRow('الإجمالي', money(s['total']), bold: true),
            InfoRow('المدفوع', money(s['paid'])),
            if (due > 0 && !cancelled)
              InfoRow('المتبقي', money(due), valueColor: Colors.orange.shade800, bold: true),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _asText(s)));
                    if (context.mounted) showSnack(context, 'تم نسخ الفاتورة.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ الفاتورة'),
                ),
              ),
              if (!cancelled) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: busy ? null : () => _cancel(s),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('إلغاء الفاتورة'),
                  ),
                ),
              ],
            ]),
          ],
        );
      },
    );
  }
}

// ───────────────────────── فاتورة شراء ─────────────────────────

class _PurchaseSheet extends StatefulWidget {
  final String purchaseId;
  final VoidCallback? onChanged;
  const _PurchaseSheet({required this.purchaseId, this.onChanged});
  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  late Future<Map<String, dynamic>> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = PurchaseService.details(widget.purchaseId);
  }

  Future<void> _cancel(Map<String, dynamic> p) async {
    final ok = await confirmDelete(
      context,
      title: 'إلغاء فاتورة الشراء #${p['invoice_number']}',
      message: 'سيتم خصم الكميات المستلمة من المخزون وتخفيض المستحق للمورد. لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'تأكيد الإلغاء',
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await PurchaseService.cancel(widget.purchaseId);
      NotificationService.instance.bump();
      widget.onChanged?.call();
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم إلغاء فاتورة الشراء.')));
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FutureSheet(
      future: future,
      builder: (context, p) {
        final cancelled = p['status'] == 'cancelled';
        final sup = p['suppliers'] as Map?;
        final items = (p['purchase_items'] as List?) ?? const [];
        final due = toNum(p['total']) - toNum(p['paid']);
        return _SheetBody(
          title: 'فاتورة شراء #${p['invoice_number']}',
          badge: cancelled ? Pill('ملغاة', Colors.red.shade700) : Pill('مكتملة', Colors.green.shade700),
          children: [
            InfoRow('التاريخ', dateTimeText(p['created_at'])),
            InfoRow('المورد', '${sup?['name'] ?? 'بدون مورد'}'),
            if (sup?['phone'] != null) InfoRow('الهاتف', '${sup!['phone']}'),
            InfoRow('المسجّل', _who(p['user_id'])),
            if ((p['note'] ?? '').toString().isNotEmpty) InfoRow('ملاحظات', '${p['note']}'),
            const SizedBox(height: 14),
            const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            _itemsTable(items),
            const Divider(height: 22),
            InfoRow('الإجمالي', money(p['total']), bold: true),
            InfoRow('المدفوع', money(p['paid'])),
            if (due > 0 && !cancelled)
              InfoRow('المتبقي للمورد', money(due), valueColor: Colors.orange.shade800, bold: true),
            if (!cancelled) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: busy ? null : () => _cancel(p),
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('إلغاء فاتورة الشراء'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ───────────────────────── مصروف ─────────────────────────

class _ExpenseSheet extends StatefulWidget {
  final String expenseId;
  final VoidCallback? onChanged;
  const _ExpenseSheet({required this.expenseId, this.onChanged});
  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = ExpenseService.get(widget.expenseId);
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final ok = await confirmDelete(
      context,
      title: 'حذف المصروف',
      message: 'هل أنت متأكد من حذف مصروف "${e['category']}" بقيمة ${money(e['amount'])}؟',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ExpenseService.delete(widget.expenseId);
      NotificationService.instance.bump();
      widget.onChanged?.call();
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم حذف المصروف.')));
    } catch (err) {
      if (mounted) showSnack(context, friendlyError(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FutureSheet(
      future: future,
      builder: (context, e) => _SheetBody(
        title: 'مصروف — ${e['category']}',
        children: [
          InfoRow('المبلغ', money(e['amount']), bold: true),
          InfoRow('التاريخ', dateTimeText(e['created_at'])),
          InfoRow('المسجّل', _who(e['user_id'])),
          if ((e['note'] ?? '').toString().isNotEmpty) InfoRow('ملاحظات', '${e['note']}'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _delete(e),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('حذف المصروف'),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── دفعة ─────────────────────────

class _PaymentSheet extends StatelessWidget {
  final String paymentId;
  const _PaymentSheet({required this.paymentId});

  @override
  Widget build(BuildContext context) {
    return _FutureSheet(
      future: HistoryService.payment(paymentId),
      builder: (context, p) {
        final isCustomer = p['party_type'] == 'customer';
        final party = (isCustomer ? p['customers'] : p['suppliers']) as Map?;
        return _SheetBody(
          title: isCustomer ? 'تحصيل من عميل' : 'سداد لمورد',
          children: [
            InfoRow('المبلغ', money(p['amount']), bold: true),
            InfoRow(isCustomer ? 'العميل' : 'المورد', '${party?['name'] ?? 'محذوف'}'),
            if (party?['phone'] != null) InfoRow('الهاتف', '${party!['phone']}'),
            InfoRow('طريقة الدفع', paymentLabel(p['method'] as String?)),
            InfoRow('التاريخ', dateTimeText(p['created_at'])),
            InfoRow('المسجّل', _who(p['user_id'])),
            if ((p['note'] ?? '').toString().isNotEmpty) InfoRow('ملاحظات', '${p['note']}'),
          ],
        );
      },
    );
  }
}

// ───────────────────────── حركة مخزون ─────────────────────────

class _MovementSheet extends StatelessWidget {
  final String movementId;
  const _MovementSheet({required this.movementId});

  @override
  Widget build(BuildContext context) {
    return _FutureSheet(
      future: HistoryService.movement(movementId),
      builder: (context, m) {
        final prod = m['products'] as Map?;
        final q = toNum(m['quantity']);
        return _SheetBody(
          title: 'حركة مخزون',
          children: [
            InfoRow('الصنف', '${prod?['name'] ?? 'محذوف'}'),
            InfoRow('نوع الحركة', InventoryService.typeLabel(m['movement_type'] as String?)),
            InfoRow(
              'الكمية',
              '${q > 0 ? '+' : ''}${qtyText(q)}',
              valueColor: q >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              bold: true,
            ),
            InfoRow('التاريخ', dateTimeText(m['created_at'])),
            InfoRow('المسجّل', _who(m['user_id'])),
            if ((m['note'] ?? '').toString().isNotEmpty) InfoRow('ملاحظات', '${m['note']}'),
          ],
        );
      },
    );
  }
}
