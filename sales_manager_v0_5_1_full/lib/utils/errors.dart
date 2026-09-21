import 'package:supabase_flutter/supabase_flutter.dart';

/// رسائل خطأ مفهومة للمستخدم بدل رسائل قاعدة البيانات الخام.
String friendlyError(Object e) {
  final raw = e is PostgrestException
      ? '${e.message} ${e.details ?? ''} ${e.code ?? ''}'
      : '$e';
  final t = raw.toLowerCase();

  if (t.contains('insufficient stock')) {
    return 'الكمية المطلوبة أكبر من المتاح في المخزون.';
  }
  if (t.contains('credit limit exceeded')) {
    return 'تجاوز العميل الحد الائتماني المسموح.';
  }
  if (t.contains('only owner or manager')) {
    return 'هذه العملية متاحة للمالك أو المدير فقط.';
  }
  if (t.contains('not authorized')) {
    return 'ليست لديك صلاحية لهذه العملية.';
  }
  if (t.contains('already sold')) {
    return 'لا يمكن الإلغاء لأن جزءًا من الكمية المستلمة تم بيعه.';
  }
  if (t.contains('stock cannot be negative')) {
    return 'لا يمكن أن يصبح المخزون بالسالب.';
  }
  if (t.contains('paid amount cannot exceed')) {
    return 'المبلغ المدفوع أكبر من إجمالي الفاتورة.';
  }
  if (t.contains('supplier required')) {
    return 'اختر مورّدًا عند وجود مبلغ متبقٍ.';
  }
  if (t.contains('credit sale requires a customer')) {
    return 'اختر عميلًا عند البيع الآجل.';
  }
  if (t.contains('already cancelled')) {
    return 'هذه الفاتورة ملغاة بالفعل.';
  }
  if (t.contains('23503') || t.contains('foreign key')) {
    return 'لا يمكن الحذف لأن العنصر مرتبط بعمليات سابقة.';
  }
  if (t.contains('socketexception') ||
      t.contains('failed host lookup') ||
      t.contains('clientexception')) {
    return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
  }
  return 'تعذر إتمام العملية. حاول مرة أخرى.';
}
