import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/reports_service.dart';
import '../services/notification_service.dart';
import 'details_sheets.dart';

class SalesReportPage extends StatefulWidget {
  final String businessId;
  const SalesReportPage({super.key, required this.businessId});
  @override State<SalesReportPage> createState() => _SalesReportPageState();
}

enum _Range { daily, weekly, monthly }

class _SalesReportPageState extends State<SalesReportPage> {
  _Range range = _Range.daily;
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
    // تحديث تلقائي بعد أي عملية بيع/إلغاء جديدة في أي مكان في التطبيق.
    NotificationService.instance.dataTick.addListener(_onTick);
  }

  @override
  void dispose() {
    NotificationService.instance.dataTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => setState(() => future = _load());

  DateTime get _since {
    final now = DateTime.now();
    switch (range) {
      case _Range.daily:
        return DateTime(now.year, now.month, now.day);
      case _Range.weekly:
        return now.subtract(const Duration(days: 7));
      case _Range.monthly:
        return DateTime(now.year, now.month - 1, now.day);
    }
  }

  Future<List<Map<String, dynamic>>> _load() =>
      ReportsService.salesSince(widget.businessId, _since);

  void _setRange(_Range r) {
    setState(() {
      range = r;
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير المبيعات')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<_Range>(
            segments: const [
              ButtonSegment(value: _Range.daily, label: Text('اليومي')),
              ButtonSegment(value: _Range.weekly, label: Text('الأسبوعي')),
              ButtonSegment(value: _Range.monthly, label: Text('الشهري')),
            ],
            selected: {range},
            onSelectionChanged: (s) => _setRange(s.first),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data ?? [];
                final total = rows.fold<double>(
                    0, (a, r) => a + ((r['total'] as num?)?.toDouble() ?? 0));
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppTheme.card(radius: 18),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('إجمالي المبيعات', style: TextStyle(color: AppTheme.muted)),
                        const SizedBox(height: 4),
                        Text('${total.toStringAsFixed(0)} ج',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('عدد الفواتير', style: TextStyle(color: AppTheme.muted)),
                        const SizedBox(height: 4),
                        Text('${rows.length}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('لا توجد مبيعات في هذه الفترة.'))
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final r = rows[i];
                              final method = switch (r['payment_method']) {
                                'cash' => 'نقدي',
                                'card' => 'بطاقة',
                                'credit' => 'آجل',
                                'transfer' => 'تحويل',
                                _ => '${r['payment_method']}',
                              };
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => showSaleDetails(context, r['id'] as String,
                                    onChanged: () => setState(() => future = _load())),
                                child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: AppTheme.card(radius: 14),
                                child: Row(children: [
                                  Text('#${r['invoice_number']}',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 12),
                                  Text(method, style: const TextStyle(color: AppTheme.muted)),
                                  const Spacer(),
                                  Text('${(r['total'] as num?)?.toStringAsFixed(0) ?? 0} ج',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ]),
                              ));
                            },
                          ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
