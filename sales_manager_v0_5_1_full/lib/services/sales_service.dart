import 'supabase_service.dart';

class SalesService {
  static Future<Map<String, dynamic>> createSale({
    required String businessId,
    String? customerId,
    required List<Map<String, dynamic>> items,
    double discount = 0,
    double tax = 0,
    required double paid,
    required String paymentMethod,
    String? note,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');

    final result = await c.rpc('create_sale', params: {
      'p_business_id': businessId,
      'p_customer_id': customerId,
      'p_items': items,
      'p_discount': discount,
      'p_tax': tax,
      'p_paid': paid,
      'p_payment_method': paymentMethod,
      'p_note': note,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<List<Map<String, dynamic>>> recent(String businessId) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final result = await c
        .from('sales')
        .select('id,invoice_number,customer_id,total,paid,payment_method,status,created_at')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(result);
  }

  /// تفاصيل فاتورة بيع كاملة (العميل + الأصناف).
  static Future<Map<String, dynamic>> details(String saleId) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c
        .from('sales')
        .select('*, customers(name,phone), sale_items(id,quantity,unit_price,total,products(name))')
        .eq('id', saleId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> cancel(String saleId, {String? reason}) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.rpc('cancel_sale', params: {
      'p_sale_id': saleId,
      'p_reason': reason,
    });
  }
}
