import 'supabase_service.dart';
import 'live_table.dart';

class PurchaseService {
  static Future<List<Map<String, dynamic>>> list(String businessId, {int limit = 100}) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final rows = await c
        .from('purchases')
        .select('id,invoice_number,total,paid,status,created_at,suppliers(name)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> details(String purchaseId) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c
        .from('purchases')
        .select('*, suppliers(name,phone), purchase_items(id,quantity,unit_price,total,products(name))')
        .eq('id', purchaseId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<Map<String, dynamic>> create({
    required String businessId,
    String? supplierId,
    required List<Map<String, dynamic>> items,
    required double paid,
    String? note,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final res = await c.rpc('create_purchase', params: {
      'p_business_id': businessId,
      'p_supplier_id': supplierId,
      'p_items': items,
      'p_paid': paid,
      'p_note': note,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> cancel(String purchaseId) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.rpc('cancel_purchase', params: {'p_purchase_id': purchaseId});
  }
}

class SupplierService {
  static Stream<List<Map<String, dynamic>>> stream(String businessId) =>
      liveTable(table: 'suppliers', businessId: businessId);

  static Future<List<Map<String, dynamic>>> list(String businessId) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final rows = await c
        .from('suppliers')
        .select('id,name,phone,address,balance')
        .eq('business_id', businessId)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> get(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c.from('suppliers').select().eq('id', id).single();
    return Map<String, dynamic>.from(row);
  }

  static Future<void> add({
    required String businessId,
    required String name,
    String? phone,
    String? address,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('suppliers').insert({
      'business_id': businessId,
      'name': name.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'address': (address == null || address.trim().isEmpty) ? null : address.trim(),
    });
  }

  static Future<void> update(String id, {required String name, String? phone, String? address}) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('suppliers').update({
      'name': name.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'address': (address == null || address.trim().isEmpty) ? null : address.trim(),
    }).eq('id', id);
  }

  static Future<void> delete(String id) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('suppliers').delete().eq('id', id);
  }

  static Future<Map<String, List<Map<String, dynamic>>>> statement(String supplierId) async {
    final c = SupabaseService.client;
    if (c == null) return {'purchases': [], 'payments': []};
    final purchases = await c
        .from('purchases')
        .select('id,invoice_number,total,paid,status,created_at')
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false)
        .limit(50);
    final payments = await c
        .from('payments')
        .select('id,amount,method,note,created_at')
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false)
        .limit(50);
    return {
      'purchases': List<Map<String, dynamic>>.from(purchases),
      'payments': List<Map<String, dynamic>>.from(payments),
    };
  }

  static Future<void> pay({
    required String businessId,
    required String supplierId,
    required double amount,
    required String method,
    String? note,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.rpc('pay_supplier', params: {
      'p_business_id': businessId,
      'p_supplier_id': supplierId,
      'p_amount': amount,
      'p_method': method,
      'p_note': note,
    });
  }
}
