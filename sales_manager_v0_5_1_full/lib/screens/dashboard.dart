import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../config/app_config.dart';
import '../services/dashboard_service.dart';
import '../services/notification_service.dart';

class DashboardPage extends StatefulWidget {
  final String? businessId;
  final void Function(int index)? onNavigate;
  const DashboardPage({super.key, this.businessId, this.onNavigate});
  @override State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardSummary> future;

  @override
  void initState() {
    super.initState();
    future = _load();
    // أي عملية (بيع، شراء، دفعة، مصروف...) بتعمل bump() على dataTick
    // من أي مكان في التطبيق (أو تصل عن طريق Realtime من جهاز تاني) —
    // فلوحة التحكم بتحدّث نفسها فورًا من غير ما المستخدم يعمل Pull to refresh.
    NotificationService.instance.dataTick.addListener(_onTick);
  }

  @override
  void dispose() {
    NotificationService.instance.dataTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() => _refresh();

  Future<DashboardSummary> _load() {
    final id = widget.businessId;
    if (id == null) return Future.value(DashboardSummary.empty());
    return DashboardService.summary(id);
  }

  Future<void> _refresh() async {
    final s = await _load();
    if (mounted) setState(() => future = Future.value(s));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data ?? DashboardSummary.empty();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _header(),
              const SizedBox(height: 22),
              LayoutBuilder(builder: (context, c) {
                final n = c.maxWidth > 1100 ? 4 : c.maxWidth > 700 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: n, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.6,
                  children: [
                    StatCard(title: 'مبيعات اليوم', value: '${data.todaySales.toStringAsFixed(0)} ج', change: '', icon: Icons.payments_rounded),
                    StatCard(title: 'طلبات اليوم', value: '${data.todayOrders}', change: '', icon: Icons.shopping_bag_rounded),
                    StatCard(title: 'العملاء', value: '${data.customerCount}', change: '', icon: Icons.people_alt_rounded),
                    StatCard(title: 'إجمالي آخر 7 أيام', value: '${data.last7DaysTotals.fold<double>(0, (a, b) => a + b).toStringAsFixed(0)} ج', change: '', icon: Icons.trending_up_rounded),
                  ],
                );
              }),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 800) {
                  return Column(children: [_salesChart(data), const SizedBox(height: 18), _quickActions()]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: _salesChart(data)),
                  const SizedBox(width: 18),
                  Expanded(child: _quickActions()),
                ]);
              }),
              const SizedBox(height: 18),
              _recentSales(data),
            ]),
          ),
        );
      },
    );
  }

  Widget _header() => Row(children: [
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('لوحة التحكم', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      SizedBox(height: 6),
      Text('نظرة سريعة على أداء نشاطك اليوم', style: TextStyle(color: AppTheme.muted)),
    ])),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.card(radius: 14),
      child: Row(children: [
        Icon(Icons.cloud_done_rounded, color: AppConfig.cloudEnabled ? Colors.green.shade700 : Colors.orangeAccent, size: 18),
        const SizedBox(width: 7), const Text('متصل ومتزامن', style: TextStyle(fontSize: 12))
      ]),
    )
  ]);

  Widget _salesChart(DashboardSummary data) => Container(
    height: 330, padding: const EdgeInsets.all(20),
    decoration: AppTheme.card(radius: 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('المبيعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('آخر 7 أيام', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
      const SizedBox(height: 18),
      Expanded(child: LineChart(LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData(
          isCurved: true, barWidth: 4,
          dotData: const FlDotData(show: false),
          spots: [
            for (int i = 0; i < data.last7DaysTotals.length; i++)
              FlSpot(i.toDouble(), data.last7DaysTotals[i]),
          ],
        )],
      )))
    ]),
  );

  Widget _quickActions() => Container(
    padding: const EdgeInsets.all(20),
    decoration: AppTheme.card(radius: 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      _action(Icons.add_shopping_cart_rounded, 'بيع جديد', () => widget.onNavigate?.call(2)),
      _action(Icons.add_box_rounded, 'إضافة منتج', () => widget.onNavigate?.call(1)),
      _action(Icons.person_add_alt_1_rounded, 'إضافة عميل', () => widget.onNavigate?.call(3)),
      _action(Icons.receipt_long_rounded, 'الفواتير', () => widget.onNavigate?.call(2)),
    ]),
  );

  Widget _action(IconData icon, String text, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: AppTheme.panel2.withOpacity(.65),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: AppTheme.primary), const SizedBox(width: 12),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(), const Icon(Icons.chevron_right_rounded, color: AppTheme.muted)
          ]),
        ),
      ),
    ),
  );

  Widget _recentSales(DashboardSummary data) => Container(
    padding: const EdgeInsets.all(20),
    decoration: AppTheme.card(radius: 22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('آخر المبيعات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 15),
      if (data.recentSales.isEmpty)
        const Text('لا توجد مبيعات بعد.', style: TextStyle(color: AppTheme.muted))
      else
        ...data.recentSales.map((s) {
          final customer = s['customers'] as Map<String, dynamic>?;
          final name = customer?['name'] as String? ?? 'عميل نقدي';
          final total = (s['total'] as num?)?.toDouble() ?? 0;
          final method = switch (s['payment_method']) {
            'cash' => 'نقدي',
            'card' => 'بطاقة',
            'credit' => 'آجل',
            'transfer' => 'تحويل',
            _ => '${s['payment_method']}',
          };
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(.12), child: const Icon(Icons.receipt, color: AppTheme.primary)),
            title: Text('#${s['invoice_number']}  •  $name'),
            subtitle: Text(method, style: const TextStyle(color: AppTheme.muted)),
            trailing: Text('${total.toStringAsFixed(0)} ج', style: const TextStyle(fontWeight: FontWeight.w800)),
          );
        }),
    ]),
  );
}
