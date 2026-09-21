import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/product_service.dart';
import '../services/notification_service.dart';
import '../widgets/confirm_dialog.dart';

class ProductsPage extends StatefulWidget {
  final String? businessId;
  const ProductsPage({super.key, this.businessId});
  @override State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String search = '';
  final demo = const [
    ('iPhone 15','إلكترونيات','39900','25'),
    ('Samsung A55','إلكترونيات','19900','18'),
    ('AirPods Pro','إكسسوارات','9900','12'),
    ('Smart Watch','إكسسوارات','4900','20'),
  ];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// إضافة (product == null) أو تعديل منتج موجود.
  Future<void> _openForm({Map<String, dynamic>? product}) async {
    final bid = widget.businessId;
    if (bid == null) return;
    final res = await showDialog<_ProductFormResult>(
      context: context,
      builder: (_) => _ProductDialog(product: product),
    );
    if (res == null) return;

    try {
      final String id;
      final oldUrl = product?['image_url'] as String?;
      final barcode = res.barcode.isEmpty ? null : res.barcode;
      final unit = res.unit.isEmpty ? 'قطعة' : res.unit;

      if (product == null) {
        id = await ProductService.create(
          businessId: bid, name: res.name, barcode: barcode,
          purchasePrice: res.purchasePrice, salePrice: res.salePrice,
          wholesalePrice: res.salePrice, stock: res.stock,
          minimumStock: 0, unit: unit,
        );
      } else {
        id = product['id'] as String;
        await ProductService.update(id, {
          'name': res.name,
          'barcode': barcode,
          'unit': unit,
          'purchase_price': res.purchasePrice,
          'sale_price': res.salePrice,
          'stock': res.stock,
        });
      }

      var imageFailed = false;
      if (res.imageBytes != null) {
        try {
          final url = await ProductService.uploadImage(
            businessId: bid, productId: id,
            bytes: res.imageBytes!, extension: res.imageExt,
          );
          await ProductService.update(id, {'image_url': url});
          await ProductService.deleteImage(oldUrl);
        } catch (_) {
          imageFailed = true;
        }
      } else if (res.removeImage && oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await ProductService.update(id, {'image_url': null});
          await ProductService.deleteImage(oldUrl);
        } catch (_) {
          imageFailed = true;
        }
      }

      NotificationService.instance.bump();
      if (imageFailed) {
        _snack('تم حفظ المنتج لكن تعذر تحديث الصورة.');
      } else {
        _snack(product == null ? 'تمت إضافة المنتج.' : 'تم حفظ التعديلات.');
      }
    } catch (_) {
      _snack('تعذر حفظ المنتج.');
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await confirmDelete(
      context,
      title: 'حذف الصنف',
      message: 'هل أنت متأكد من حذف "${p['name']}"؟\nلا يمكن التراجع عن هذا الإجراء.',
    );
    if (!ok) return;
    try {
      await ProductService.delete(p['id'] as String, imageUrl: p['image_url'] as String?);
      NotificationService.instance.bump();
      _snack('تم حذف الصنف.');
    } on PostgrestException catch (e) {
      // 23503 = الصنف مربوط بفواتير سابقة
      _snack(e.code == '23503'
          ? 'لا يمكن حذف هذا الصنف لأنه مسجّل في فواتير سابقة.'
          : 'تعذر حذف الصنف.');
    } catch (_) {
      _snack('تعذر حذف الصنف.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = widget.businessId != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المنتجات والمخزون', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            SizedBox(height: 5), Text('إدارة المنتجات والأسعار والكميات', style: TextStyle(color: AppTheme.muted)),
          ])),
          if (cloud) FilledButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('إضافة منتج')),
        ]),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => search = v.toLowerCase()),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث بالاسم أو الباركود...'),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: cloud
            ? StreamBuilder<List<Map<String,dynamic>>>(
                stream: ProductService.stream(widget.businessId!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = (snap.data ?? []).where((p) =>
                    (p['name'] ?? '').toString().toLowerCase().contains(search) ||
                    (p['barcode'] ?? '').toString().toLowerCase().contains(search)).toList();
                  if (rows.isEmpty) return const Center(child: Text('لا توجد منتجات بعد.'));
                  return ListView.separated(
                    itemCount: rows.length, separatorBuilder: (_,__) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _row(rows[i]),
                  );
                },
              )
            : ListView.separated(
                itemCount: demo.length, separatorBuilder: (_,__) => const SizedBox(height: 8),
                itemBuilder: (_,i) => _demoRow(demo[i]),
              ),
        ),
      ]),
    );
  }

  Widget _row(Map<String,dynamic> p) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AppTheme.card(radius: 17),
    child: Row(children: [
      _thumb(p['image_url'] as String?), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('${p['unit'] ?? 'قطعة'} • ${p['barcode'] ?? 'بدون باركود'}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${p['sale_price']} ج', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('المخزون: ${p['stock']}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
      ]),
      IconButton(
        tooltip: 'تعديل',
        onPressed: () => _openForm(product: p),
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'حذف',
        onPressed: () => _delete(p),
        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
      ),
    ]),
  );

  Widget _demoRow((String,String,String,String) p) => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppTheme.card(radius: 17),
    child: Row(children:[
      _icon(),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(p.$1,style:const TextStyle(fontWeight:FontWeight.w800)),Text(p.$2,style:const TextStyle(color:AppTheme.muted,fontSize:12))
      ])),Text('${p.$3} ج',style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(width:28),
      Text('المخزون: ${p.$4}',style:const TextStyle(color:AppTheme.muted))
    ]),
  );

  Widget _thumb(String? url) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: SizedBox(
      width: 48, height: 48,
      child: (url != null && url.isNotEmpty)
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon())
          : _icon(),
    ),
  );

  Widget _icon()=>Container(width:48,height:48,decoration:BoxDecoration(color:AppTheme.panel2,borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.inventory_2_outlined,color:AppTheme.primary));
}

// ───────────────────────── نموذج الإضافة / التعديل ─────────────────────────

class _ProductFormResult {
  final String name, barcode, unit;
  final double purchasePrice, salePrice, stock;
  final Uint8List? imageBytes;
  final String imageExt;
  final bool removeImage;
  const _ProductFormResult({
    required this.name, required this.barcode, required this.unit,
    required this.purchasePrice, required this.salePrice, required this.stock,
    required this.imageBytes, required this.imageExt, required this.removeImage,
  });
}

class _ProductDialog extends StatefulWidget {
  final Map<String, dynamic>? product;
  const _ProductDialog({this.product});
  @override State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  static const _allowedExt = ['jpg', 'jpeg', 'png', 'webp'];
  static const _maxImageBytes = 3 * 1024 * 1024;

  late final TextEditingController name, barcode, unit, purchase, price, stock;
  Uint8List? newBytes;
  String newExt = 'jpg';
  bool removeImage = false;
  String? nameError, priceError, purchaseError, stockError, imageError;

  bool get editing => widget.product != null;
  String? get oldUrl => widget.product?['image_url'] as String?;
  bool get _hasImage => newBytes != null || (!removeImage && (oldUrl ?? '').isNotEmpty);

  static String _fmt(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0;
    return d == d.truncateToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  static double? _parse(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    if (v == null || v < 0) return null;
    return v;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p == null ? '' : '${p['name'] ?? ''}');
    barcode = TextEditingController(text: p == null ? '' : '${p['barcode'] ?? ''}');
    unit = TextEditingController(text: p == null ? 'قطعة' : '${p['unit'] ?? 'قطعة'}');
    purchase = TextEditingController(text: p == null ? '0' : _fmt(p['purchase_price']));
    price = TextEditingController(text: p == null ? '' : _fmt(p['sale_price']));
    stock = TextEditingController(text: p == null ? '0' : _fmt(p['stock']));
  }

  @override
  void dispose() {
    name.dispose(); barcode.dispose(); unit.dispose();
    purchase.dispose(); price.dispose(); stock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200, maxHeight: 1200, imageQuality: 85,
      );
      if (f == null) return;
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      if (!_allowedExt.contains(ext)) {
        setState(() => imageError = 'الصيغة غير مدعومة (JPG / PNG / WEBP فقط).');
        return;
      }
      final bytes = await f.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        setState(() => imageError = 'حجم الصورة كبير، الحد الأقصى 3 ميجا.');
        return;
      }
      setState(() {
        newBytes = bytes;
        newExt = ext;
        removeImage = false;
        imageError = null;
      });
    } catch (_) {
      setState(() => imageError = 'تعذر اختيار الصورة.');
    }
  }

  void _removeImage() {
    setState(() {
      newBytes = null;
      imageError = null;
      if ((oldUrl ?? '').isNotEmpty) removeImage = true;
    });
  }

  void _submit() {
    final n = name.text.trim();
    final sale = _parse(price.text);
    final buy = _parse(purchase.text);
    final st = _parse(stock.text);
    setState(() {
      nameError = n.isEmpty ? 'اسم المنتج مطلوب' : null;
      priceError = sale == null ? 'أدخل رقمًا صحيحًا' : null;
      purchaseError = buy == null ? 'أدخل رقمًا صحيحًا' : null;
      stockError = st == null ? 'أدخل رقمًا صحيحًا' : null;
    });
    if (nameError != null || priceError != null || purchaseError != null || stockError != null) return;
    Navigator.pop(
      context,
      _ProductFormResult(
        name: n,
        barcode: barcode.text.trim(),
        unit: unit.text.trim(),
        purchasePrice: buy!,
        salePrice: sale!,
        stock: st!,
        imageBytes: newBytes,
        imageExt: newExt,
        removeImage: removeImage,
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppTheme.panel2,
    child: const Icon(Icons.image_outlined, size: 40, color: AppTheme.muted),
  );

  Widget _preview() {
    final url = oldUrl;
    Widget child;
    if (newBytes != null) {
      child = Image.memory(newBytes!, fit: BoxFit.cover);
    } else if (!removeImage && url != null && url.isNotEmpty) {
      child = Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    } else {
      child = _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(width: 110, height: 110, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editing ? 'تعديل المنتج' : 'إضافة منتج'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _preview(),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_hasImage ? 'تغيير الصورة' : 'اختيار صورة'),
              ),
              if (_hasImage)
                TextButton.icon(
                  onPressed: _removeImage,
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  label: Text('حذف الصورة', style: TextStyle(color: Colors.red.shade700)),
                ),
            ]),
            if (imageError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(imageError!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: 'اسم المنتج', errorText: nameError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: barcode,
              decoration: const InputDecoration(labelText: 'الباركود (اختياري)'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعر البيع', errorText: priceError),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: purchase,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'سعر الشراء', errorText: purchaseError),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(
                controller: stock,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'الكمية', errorText: stockError),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'الوحدة'),
              )),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
