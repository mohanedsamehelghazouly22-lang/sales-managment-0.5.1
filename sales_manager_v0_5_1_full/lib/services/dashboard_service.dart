import 'supabase_service.dart';

class DashboardSummary {
  final double todaySales;
  final int todayOrders;
  final int customerCount;
  final List<double> last7DaysTotals;
  final List<Map<String, dynamic>> recentSales;

  DashboardSummary({
    required this.todaySales,
    required this.todayOrders,
    required this.customerCount,
    required this.last7DaysTotals,
    required this.recentSales,
  });

  static DashboardSummary empty() => DashboardSummary(
        todaySales: 0,
        todayOrders: 0,
        customerCount: 0,
        last7DaysTotals: List.filled(7, 0),
        recentSales: const [],
      );
}

class DashboardService {
  static Future<DashboardSummary> summary(String businessId) async {
    final c = SupabaseService.client;
    if (c == null) return DashboardSummary.empty();

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = startOfToday.subtract(const Duration(days: 6));

    final salesRows = await c
        .from('sales')
        .select('total,created_at,status')
        .eq('business_id', businessId)
        .gte('created_at', sevenDaysAgo.toIso8601String())
        .order('created_at');

    final sales = List<Map<String, dynamic>>.from(salesRows)
        .where((s) => s['status'] != 'cancelled')
        .toList();

    double todaySales = 0;
    int todayOrders = 0;
    final dayTotals = List<double>.filled(7, 0);

    for (final s in sales) {
      final total = (s['total'] as num?)?.toDouble() ?? 0;
      final created = DateTime.tryParse(s['created_at'] as String? ?? '');
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      final dayIndex = day.difference(sevenDaysAgo).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        dayTotals[dayIndex] += total;
      }
      if (day == startOfToday) {
        todaySales += total;
        todayOrders++;
      }
    }

    final customerCountResult = await c
        .from('customers')
        .select('id')
        .eq('business_id', businessId)
        .count();
    final customerCount = customerCountResult.count;

    final recentRows = await c
        .from('sales')
        .select('id,invoice_number,total,payment_method,status,created_at,customers(name)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(4);

    return DashboardSummary(
      todaySales: todaySales,
      todayOrders: todayOrders,
      customerCount: customerCount,
      last7DaysTotals: dayTotals,
      recentSales: List<Map<String, dynamic>>.from(recentRows),
    );
  }
}
