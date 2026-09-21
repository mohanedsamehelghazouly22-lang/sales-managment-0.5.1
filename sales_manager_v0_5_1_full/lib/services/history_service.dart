import 'supabase_service.dart';

class HistoryService {
  /// سجل العمليات الموحّد (مبيعات، مشتريات، مصروفات، دفعات، تسويات مخزون).
  static Future<List<Map<String, dynamic>>> operations(
    String businessId, {
    String? kind,
    DateTime? since,
    DateTime? until,
    int limit = 100,
  }) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    var q = c.from('operations_log').select().eq('business_id', businessId);
    if (kind != null) q = q.eq('kind', kind);
    if (since != null) q = q.gte('created_at', since.toUtc().toIso8601String());
    if (until != null) q = q.lt('created_at', until.toUtc().toIso8601String());
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> payment(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c
        .from('payments')
        .select('*, customers(name,phone), suppliers(name,phone)')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<Map<String, dynamic>> movement(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c
        .from('stock_movements')
        .select('*, products(name,unit)')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }
}
