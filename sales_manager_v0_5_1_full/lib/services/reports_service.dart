import 'supabase_service.dart';

class ReportsService {
  static Future<List<Map<String, dynamic>>> salesSince(
      String businessId, DateTime since) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final result = await c
        .from('sales')
        .select('id,invoice_number,total,payment_method,status,created_at')
        .eq('business_id', businessId)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result)
        .where((s) => s['status'] != 'cancelled')
        .toList();
  }

  static Future<Map<String, dynamic>> profit(String businessId, DateTime from, DateTime to) async {
    final c = SupabaseService.client;
    if (c == null) return {};
    final res = await c.rpc('report_profit', params: {
      'p_business_id': businessId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<List<Map<String, dynamic>>> topProducts(
      String businessId, DateTime from, DateTime to, {int limit = 10}) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final res = await c.rpc('report_top_products', params: {
      'p_business_id': businessId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_limit': limit,
    });
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<List<Map<String, dynamic>>> customers(String businessId) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final res = await c.rpc('report_customers', params: {'p_business_id': businessId});
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<List<Map<String, dynamic>>> purchasesBetween(
      String businessId, DateTime from, DateTime to) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final rows = await c
        .from('purchases')
        .select('id,invoice_number,total,paid,status,created_at,suppliers(name)')
        .eq('business_id', businessId)
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows)
        .where((p) => p['status'] != 'cancelled')
        .toList();
  }
}
