import 'dart:async';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Stream "حي" لجدول في Supabase.
///
/// Realtime بيبعت INSERT/UPDATE بس، وأحداث الحذف (DELETE) مش بتوصل لما
/// بنستخدم فلتر (business_id) — عشان كده الصنف المحذوف كان بيفضل ظاهر.
/// هنا أي حدث Realtime أو أي عملية محلية (NotificationService.bump)
/// بتعمل إعادة جلب للجدول، فالقائمة دايمًا مطابقة للقاعدة.
final Map<String, _LiveTable> _liveTables = <String, _LiveTable>{};

Stream<List<Map<String, dynamic>>> liveTable({
  required String table,
  required String businessId,
  String orderBy = 'name',
  bool ascending = true,
}) {
  if (SupabaseService.client == null) return const Stream.empty();
  return _liveTables
      .putIfAbsent(
        '$table|$businessId|$orderBy|$ascending',
        () => _LiveTable(table, businessId, orderBy, ascending),
      )
      .stream;
}

class _LiveTable {
  _LiveTable(this.table, this.businessId, this.orderBy, this.ascending) {
    _ctrl = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
    stream = _ctrl.stream;
  }

  final String table;
  final String businessId;
  final String orderBy;
  final bool ascending;

  late final StreamController<List<Map<String, dynamic>>> _ctrl;
  late final Stream<List<Map<String, dynamic>>> stream;

  StreamSubscription<dynamic>? _rt;
  bool _active = false;
  bool _busy = false;
  bool _again = false;
  bool _hasData = false;

  void _start() {
    final c = SupabaseService.client;
    if (c == null) return;
    _active = true;
    _hasData = false;
    NotificationService.instance.dataTick.addListener(_refetch);
    var first = true;
    _rt = c
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .listen((_) {
      // أول حدث هو اللقطة الأولية — إحنا بنجلبها بنفسنا.
      if (first) {
        first = false;
        return;
      }
      _refetch();
    }, onError: (_) {});
    _refetch();
  }

  Future<void> _stop() async {
    _active = false;
    NotificationService.instance.dataTick.removeListener(_refetch);
    final old = _rt;
    _rt = null;
    await old?.cancel();
  }

  Future<void> _refetch() async {
    if (!_active) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final c = SupabaseService.client;
        if (c == null) return;
        final rows = await c
            .from(table)
            .select()
            .eq('business_id', businessId)
            .order(orderBy, ascending: ascending);
        if (!_active) return;
        _hasData = true;
        _ctrl.add(List<Map<String, dynamic>>.from(rows));
      } while (_again && _active);
    } catch (e) {
      if (_active && !_hasData) _ctrl.addError(e);
    } finally {
      _busy = false;
    }
  }
}
