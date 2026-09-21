import 'package:intl/intl.dart';

/// تحويل أي قيمة قادمة من قاعدة البيانات إلى رقم بأمان.
num toNum(dynamic v) {
  if (v is num) return v;
  return num.tryParse('${v ?? ''}') ?? 0;
}

final NumberFormat _moneyFmt = NumberFormat('#,##0.##');
final NumberFormat _qtyFmt = NumberFormat('#,##0.###');
final DateFormat _dateTimeFmt = DateFormat('yyyy/MM/dd  HH:mm');
final DateFormat _dayFmt = DateFormat('yyyy/MM/dd');

String money(dynamic v) => '${_moneyFmt.format(toNum(v))} ج';

String qtyText(dynamic v) => _qtyFmt.format(toNum(v));

DateTime? parseDate(dynamic v) => DateTime.tryParse('${v ?? ''}')?.toLocal();

String dateTimeText(dynamic v) {
  final d = parseDate(v);
  return d == null ? '—' : _dateTimeFmt.format(d);
}

String dayText(dynamic v) {
  final d = parseDate(v);
  return d == null ? '—' : _dayFmt.format(d);
}

String paymentLabel(String? m) => switch (m) {
      'cash' => 'نقدي',
      'card' => 'بطاقة',
      'transfer' => 'تحويل',
      'credit' => 'آجل',
      _ => m ?? '—',
    };

/// قراءة رقم مكتوب من المستخدم (يدعم الأرقام العربية والفاصلة).
double? parseAmount(String input) {
  var t = input.trim();
  if (t.isEmpty) return null;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(arabic[i], '$i');
  }
  t = t.replaceAll('٫', '.').replaceAll('،', '.').replaceAll(',', '.');
  return double.tryParse(t);
}

/// "منذ ..." مختصرة للإشعارات.
String timeAgo(dynamic iso) {
  final d = parseDate(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return _dayFmt.format(d);
}
