import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/reports_service.dart';
import '../services/expense_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'details_sheets.dart';

enum ReportPeriod { today, week, month, lastMonth, year }

const _periodOptions = <(String, ReportPeriod)>[
  ('اليوم', ReportPeriod.today),
  ('آخر 7 أيام', ReportPeriod.week),
  ('هذا الشهر', ReportPeriod.month),
  ('الشهر الماضي', ReportPeriod.lastMonth),
  ('هذه السنة', ReportPeriod.year),
];

(DateTime, DateTime) rangeOf(ReportPeriod p) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  switch (p) {
    case ReportPeriod.today:
      return (today, tomorrow);
    case ReportPeriod.week:
      return (today.subtract(const Duration(days: 6)), tomorrow);
    case ReportPeriod.month:
      return (DateTime(now.year, now.month, 1), tomorrow);
    case ReportPeriod.lastMonth:
      return (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 1));
    case ReportPeriod.year:
      return (DateTime(now.year, 1, 1), tomorrow);
  }
}

/// هيكل مشترك لصفحات التقارير: عنوان + اختيار الفترة + محتوى يتم تحميله.
class _ReportShell extends StatefulWidget {
  final String title;
  final bool withPeriod;
  final Future<Widget> Function(ReportPeriod period) build;
  const _ReportShell({required this.title, required this.build, this.withPeriod = true});
  @override
  State<_ReportShell> createState() => _ReportShellState();
}

class _ReportShellState extends State<_ReportShell> {
  ReportPeriod period = ReportPeriod.month;
  late Future<Widget> future;

  @override
  void initState() {
    super.initState();
    future = widget.build(period);
    // شاشات التقارير (الأرباح، العملاء، المشتريات، المصروفات) كلها
    // بتستخدم الهيكل ده — تحديث واحد هنا كافي يحدّثهم كلهم تلقائيًا
    // بعد أي عملية جديدة في أي مكان في التطبيق.
    NotificationService.instance.dataTick.addListener(_onTick);
  }

  @override
  void dispose() {
    NotificationService.instance.dataTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => setState(() => future = widget.build(period));

  void _set(ReportPeriod p) {
    setState(() {
      period = p;
      future = widget.build(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.withPeriod) ...[
                  FilterChips<ReportPeriod>(
                    options: _periodOptions,
                    selected: period,
                    onSelected: _set,
                  ),
                  const SizedBox(height: 14),
                ],
                Expanded(
                  child: FutureBuilder<Widget>(
                    future: future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return EmptyBox(friendlyError(snap.error!), icon: Icons.error_outline);
                      }
                      return snap.data!;
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── تقرير الأرباح ─────────────────────────

class ProfitReportPage extends StatelessWidget {
  final String businessId;
  const ProfitReportPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      title: 'تقرير الأرباح',
      build: (period) async {
        final r = rangeOf(period);
        final p = await ReportsService.profit(businessId, r.$1, r.$2);
        final top = await ReportsService.topProducts(businessId, r.$1, r.$2);
        final net = toNum(p['net_profit']);
        return ListView(children: [
          StatGrid([
            StatBox('الإيرادات', money(p['revenue']), Icons.payments_rounded, color: Colors.green.shade700),
            StatBox('تكلفة البضاعة المباعة', money(p['cogs']), Icons.inventory_2_outlined,
                color: Colors.orange.shade800),
            StatBox('مجمل الربح', money(p['gross_profit']), Icons.trending_up_rounded),
            StatBox('المصروفات', money(p['expenses']), Icons.money_off_csred_rounded,
                color: Colors.red.shade700),
            StatBox('صافي الربح', money(net), Icons.account_balance_rounded,
                color: net >= 0 ? Colors.green.shade700 : Colors.red.shade700),
            StatBox('عدد الفواتير', '${toNum(p['invoices']).toInt()}', Icons.receipt_long_rounded),
            StatBox('المشتريات', money(p['purchases']), Icons.shopping_cart_rounded,
                color: Colors.blue.shade700),
            StatBox('الخصومات', money(p['discounts']), Icons.percent_rounded),
          ]),
          const SizedBox(height: 10),
          const Text(
            'ملاحظة: التكلفة محسوبة من سعر الشراء المسجّل للصنف وقت البيع؛ الأصناف بدون سعر شراء تُحسب تكلفتها صفر.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          const Text('الأصناف الأكثر مبيعًا', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          if (top.isEmpty)
            const EmptyBox('لا توجد مبيعات في هذه الفترة.', icon: Icons.bar_chart_rounded)
          else
            for (final t in top)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: AppTheme.card(radius: 14),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('الكمية: ${qtyText(t['qty'])}',
                          style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(t['revenue']), style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('ربح ${money(t['profit'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: toNum(t['profit']) >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        )),
                  ]),
                ]),
              ),
        ]);
      },
    );
  }
}

// ───────────────────────── تقرير العملاء ─────────────────────────

class CustomersReportPage extends StatelessWidget {
  final String businessId;
  const CustomersReportPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      title: 'تقرير العملاء',
      withPeriod: false,
      build: (_) async {
        final rows = await ReportsService.customers(businessId);
        final debtors = rows.where((r) => toNum(r['balance']) > 0).toList()
          ..sort((a, b) => toNum(b['balance']).compareTo(toNum(a['balance'])));
        final debt = debtors.fold<double>(0, (a, r) => a + toNum(r['balance']).toDouble());
        final sales = rows.fold<double>(0, (a, r) => a + toNum(r['total_sales']).toDouble());
        return ListView(children: [
          StatGrid([
            StatBox('عدد العملاء', '${rows.length}', Icons.people_alt_rounded),
            StatBox('إجمالي مشترياتهم', money(sales), Icons.payments_rounded, color: Colors.green.shade700),
            StatBox('إجمالي المديونيات', money(debt), Icons.account_balance_wallet_outlined,
                color: Colors.orange.shade800),
            StatBox('عدد المدينين', '${debtors.length}', Icons.warning_amber_rounded,
                color: Colors.red.shade700),
          ]),
          const SizedBox(height: 18),
          const Text('أعلى العملاء شراءً', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          if (rows.isEmpty) const EmptyBox('لا يوجد عملاء بعد.', icon: Icons.people_outline),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: AppTheme.card(radius: 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      '${toNum(r['invoices']).toInt()} فاتورة • آخر شراء: ${r['last_purchase'] == null ? '—' : dayText(r['last_purchase'])}',
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(r['total_sales']), style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (toNum(r['balance']) > 0)
                    Text('عليه ${money(r['balance'])}',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
        ]);
      },
    );
  }
}

// ───────────────────────── تقرير المشتريات ─────────────────────────

class PurchasesReportPage extends StatelessWidget {
  final String businessId;
  const PurchasesReportPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      title: 'تقرير المشتريات',
      build: (period) async {
        final r = rangeOf(period);
        final rows = await ReportsService.purchasesBetween(businessId, r.$1, r.$2);
        final total = rows.fold<double>(0, (a, p) => a + toNum(p['total']).toDouble());
        final due = rows.fold<double>(0, (a, p) => a + (toNum(p['total']) - toNum(p['paid'])).toDouble());
        final bySupplier = <String, double>{};
        for (final p in rows) {
          final n = '${(p['suppliers'] as Map?)?['name'] ?? 'بدون مورد'}';
          bySupplier[n] = (bySupplier[n] ?? 0) + toNum(p['total']).toDouble();
        }
        final sup = bySupplier.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return ListView(children: [
          StatGrid([
            StatBox('إجمالي المشتريات', money(total), Icons.shopping_cart_rounded, color: Colors.blue.shade700),
            StatBox('عدد الفواتير', '${rows.length}', Icons.receipt_long_rounded),
            StatBox('المتبقي للموردين', money(due), Icons.account_balance_wallet_outlined,
                color: Colors.orange.shade800),
            StatBox('عدد الموردين', '${bySupplier.length}', Icons.local_shipping_outlined),
          ]),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const EmptyBox('لا توجد مشتريات في هذه الفترة.', icon: Icons.shopping_cart_outlined)
          else ...[
            const Text('حسب المورد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            for (final e in sup)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: AppTheme.card(radius: 14),
                child: Row(children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(money(e.value), style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
              ),
            const SizedBox(height: 14),
            const Text('الفواتير', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            for (final p in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => showPurchaseDetails(context, p['id'] as String),
                title: Text('#${p['invoice_number']}  •  ${money(p['total'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${(p['suppliers'] as Map?)?['name'] ?? 'بدون مورد'} • ${dateTimeText(p['created_at'])}'),
              ),
          ],
        ]);
      },
    );
  }
}

// ───────────────────────── تقرير المصروفات ─────────────────────────

class ExpensesReportPage extends StatelessWidget {
  final String businessId;
  const ExpensesReportPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return _ReportShell(
      title: 'تقرير المصروفات',
      build: (period) async {
        final r = rangeOf(period);
        final rows = await ExpenseService.since(businessId, r.$1, r.$2);
        final totals = <String, double>{};
        for (final e in rows) {
          final c = '${e['category']}';
          totals[c] = (totals[c] ?? 0) + toNum(e['amount']).toDouble();
        }
        final sum = totals.values.fold<double>(0, (a, b) => a + b);
        final cats = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return ListView(children: [
          StatGrid([
            StatBox('إجمالي المصروفات', money(sum), Icons.money_off_csred_rounded, color: Colors.red.shade700),
            StatBox('عدد المصروفات', '${rows.length}', Icons.receipt_long_outlined),
          ]),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const EmptyBox('لا توجد مصروفات في هذه الفترة.', icon: Icons.receipt_long_outlined)
          else ...[
            const Text('حسب التصنيف', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            for (final c in cats)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: AppTheme.card(radius: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c.key, style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text(money(c.value), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: sum <= 0 ? 0 : (c.value / sum).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: Colors.red.shade700,
                      backgroundColor: Colors.red.shade700.withOpacity(.12),
                    ),
                  ),
                ]),
              ),
          ],
        ]);
      },
    );
  }
}
