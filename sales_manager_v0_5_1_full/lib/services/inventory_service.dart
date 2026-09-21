import 'supabase_service.dart';

class InventoryService {
  /// تسوية المخزون: mode = add | remove | set | damage
  static Future<void> adjust({
    required String businessId,
    required String productId,
    required String mode,
    required double quantity,
    String? reason,
    double? minStock,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.rpc('adjust_stock', params: {
      'p_business_id': businessId,
      'p_product_id': productId,
      'p_mode': mode,
      'p_quantity': quantity,
      'p_reason': reason,
      'p_min_stock': minStock,
    });
  }

  /// سجل حركات المخزون (لكل الأصناف أو لصنف واحد).
  static Future<List<Map<String, dynamic>>> movements(
    String businessId, {
    String? productId,
    String? type,
    int limit = 200,
  }) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    var q = c
        .from('stock_movements')
        .select('id,movement_type,quantity,note,created_at,reference_id,products(name,unit)')
        .eq('business_id', businessId);
    if (productId != null) q = q.eq('product_id', productId);
    if (type != null) q = q.eq('movement_type', type);
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  static String typeLabel(String? t) => switch (t) {
        'sale' => 'بيع',
        'purchase' => 'شراء',
        'return' => 'مرتجع / إلغاء',
        'adjustment' => 'تسوية',
        'damage' => 'تالف',
        _ => t ?? '—',
      };
}
