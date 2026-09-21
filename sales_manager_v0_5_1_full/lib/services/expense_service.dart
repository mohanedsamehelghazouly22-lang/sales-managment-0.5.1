import 'supabase_service.dart';
import 'live_table.dart';

class ExpenseService {
  static Stream<List<Map<String, dynamic>>> stream(String businessId) =>
      liveTable(table: 'expenses', businessId: businessId, orderBy: 'created_at', ascending: false);

  static Future<List<Map<String, dynamic>>> since(String businessId, DateTime? from, DateTime? to) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    var q = c.from('expenses').select().eq('business_id', businessId);
    if (from != null) q = q.gte('created_at', from.toUtc().toIso8601String());
    if (to != null) q = q.lt('created_at', to.toUtc().toIso8601String());
    final rows = await q.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> get(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c.from('expenses').select().eq('id', id).single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> add({
    required String businessId,
    required String category,
    required double amount,
    String? note,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('expenses').insert({
      'business_id': businessId,
      'user_id': c.auth.currentUser?.id,
      'category': category.trim(),
      'amount': amount,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }

  static Future<void> delete(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('expenses').delete().eq('id', id);
  }
}
