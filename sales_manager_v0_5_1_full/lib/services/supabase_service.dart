import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'tracking_client.dart';

class SupabaseService {
  static Future<void> initialize() async {
    if (!AppConfig.cloudEnabled) return;

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabasePublishableKey,
      httpClient: TrackingClient(),
    );
  }

  static SupabaseClient? get client =>
      AppConfig.cloudEnabled ? Supabase.instance.client : null;

  static User? get currentUser => client?.auth.currentUser;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final c = client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    return c.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await client?.auth.signOut();
  }

  static Future<List<Map<String, dynamic>>> products(String businessId) async {
    final c = client;
    if (c == null) return [];
    final result = await c
        .from('products')
        .select()
        .eq('business_id', businessId)
        .order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Stream<List<Map<String, dynamic>>> productStream(
      String businessId) {
    final c = client;
    if (c == null) return const Stream.empty();

    return c
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('name');
  }

  static Future<void> addProduct({
    required String businessId,
    required String name,
    required double salePrice,
    required double purchasePrice,
    int stock = 0,
    int minimumStock = 0,
    String? barcode,
  }) async {
    final c = client;
    if (c == null) throw StateError('Cloud backend is not configured.');

    await c.from('products').insert({
      'business_id': businessId,
      'name': name,
      'sale_price': salePrice,
      'purchase_price': purchasePrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'barcode': barcode,
    });
  }
}
