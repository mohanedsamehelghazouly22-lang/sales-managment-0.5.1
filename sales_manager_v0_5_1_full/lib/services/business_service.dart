import 'supabase_service.dart';

class BusinessService {
  static Future<List<Map<String, dynamic>>> myBusinesses() async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final memberships = await c
        .from('business_members')
        .select('business_id, role, businesses(id, name, phone, address, currency_code)')
        .eq('user_id', c.auth.currentUser!.id);

    return (memberships as List)
        .map((e) => Map<String, dynamic>.from(e['businesses'] as Map))
        .toList();
  }

  static Future<String> create(String name) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final id = await c.rpc('create_business', params: {'p_name': name.trim()});
    return id as String;
  }
}
