import 'supabase_service.dart';
import 'live_table.dart';

class CustomerService {
  static Future<List<Map<String, dynamic>>> list(String businessId) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final result = await c.from('customers')
        .select('id,name,phone,address,balance,credit_limit')
        .eq('business_id', businessId)
        .order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Stream<List<Map<String, dynamic>>> stream(String businessId) =>
      liveTable(table: 'customers', businessId: businessId);

  static Future<Map<String, dynamic>> get(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c.from('customers').select().eq('id', id).single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> add({
    required String businessId,
    required String name,
    String? phone,
    String? address,
    double creditLimit = 0,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('customers').insert({
      'business_id': businessId,
      'name': name.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'address': (address == null || address.trim().isEmpty) ? null : address.trim(),
      'credit_limit': creditLimit,
    });
  }

  static Future<void> update(
    String id, {
    required String name,
    String? phone,
    String? address,
    required double creditLimit,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('customers').update({
      'name': name.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'address': (address == null || address.trim().isEmpty) ? null : address.trim(),
      'credit_limit': creditLimit,
    }).eq('id', id);
  }

  static Future<void> delete(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('customers').delete().eq('id', id);
  }

  /// كشف حساب العميل: فواتيره ودفعاته.
  static Future<Map<String, List<Map<String, dynamic>>>> statement(String customerId) async {
    final c = SupabaseService.client;
    if (c == null) return {'sales': [], 'payments': []};
    final sales = await c.from('sales')
        .select('id,invoice_number,total,paid,status,payment_method,created_at')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(50);
    final payments = await c.from('payments')
        .select('id,amount,method,note,created_at')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false)
        .limit(50);
    return {
      'sales': List<Map<String, dynamic>>.from(sales),
      'payments': List<Map<String, dynamic>>.from(payments),
    };
  }

  static Future<void> receivePayment({
    required String businessId,
    required String customerId,
    required double amount,
    required String method,
    String? note,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.rpc('receive_customer_payment', params: {
      'p_business_id': businessId,
      'p_customer_id': customerId,
      'p_amount': amount,
      'p_method': method,
      'p_note': note,
    });
  }
}
