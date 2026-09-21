import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'live_table.dart';

class ProductService {
  static const imagesBucket = 'product-images';

  static Future<List<Map<String, dynamic>>> list(String businessId) async {
    final c = SupabaseService.client;
    if (c == null) return [];
    final result = await c.from('products')
        .select('id,name,barcode,sku,purchase_price,sale_price,wholesale_price,stock,minimum_stock,unit,is_active,category_id,image_url')
        .eq('business_id', businessId)
        .order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Stream<List<Map<String, dynamic>>> stream(String businessId) =>
      liveTable(table: 'products', businessId: businessId);

  static Future<void> upsert({
    String? id,
    required String businessId,
    required String name,
    String? barcode,
    String? sku,
    required double purchasePrice,
    required double salePrice,
    required double wholesalePrice,
    required double stock,
    required double minimumStock,
    required String unit,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final payload = {
      if (id != null) 'id': id,
      'business_id': businessId,
      'name': name.trim(),
      'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      'sku': sku?.trim().isEmpty == true ? null : sku?.trim(),
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'wholesale_price': wholesalePrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'unit': unit.trim().isEmpty ? 'قطعة' : unit.trim(),
    };
    await c.from('products').upsert(payload);
  }

  /// إضافة منتج جديد وترجع الـ id بتاعه.
  static Future<String> create({
    required String businessId,
    required String name,
    String? barcode,
    required double purchasePrice,
    required double salePrice,
    required double wholesalePrice,
    required double stock,
    required double minimumStock,
    required String unit,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final row = await c.from('products').insert({
      'business_id': businessId,
      'name': name.trim(),
      'barcode': (barcode == null || barcode.trim().isEmpty) ? null : barcode.trim(),
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'wholesale_price': wholesalePrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'unit': unit.trim().isEmpty ? 'قطعة' : unit.trim(),
    }).select('id').single();
    return row['id'] as String;
  }

  /// تعديل الحقول المذكورة فقط (باقي الحقول زي ما هي).
  static Future<void> update(String id, Map<String, dynamic> changes) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('products').update({
      ...changes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// رفع صورة المنتج وترجع الرابط العام.
  static Future<String> uploadImage({
    required String businessId,
    required String productId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    // اسم فريد لكل رفع عشان الكاش ما يعرضش الصورة القديمة.
    final path = '$businessId/${productId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await c.storage.from(imagesBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return c.storage.from(imagesBucket).getPublicUrl(path);
  }

  /// مسح ملف الصورة من التخزين (لو فشل مش مشكلة).
  static Future<void> deleteImage(String? url) async {
    if (url == null || url.isEmpty) return;
    final c = SupabaseService.client;
    if (c == null) return;
    final marker = '/$imagesBucket/';
    final i = url.indexOf(marker);
    if (i < 0) return;
    final path = Uri.decodeComponent(url.substring(i + marker.length).split('?').first);
    try {
      await c.storage.from(imagesBucket).remove([path]);
    } catch (_) {}
  }

  static Future<void> delete(String id, {String? imageUrl}) async {
    final c = SupabaseService.client;
    if (c == null) throw StateError('Cloud backend is not configured.');
    await c.from('products').delete().eq('id', id);
    await deleteImage(imageUrl);
  }
}
