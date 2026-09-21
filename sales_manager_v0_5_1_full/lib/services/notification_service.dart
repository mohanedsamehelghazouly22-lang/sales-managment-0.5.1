import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'tracking_client.dart';

/// يستمع لجدول notifications في Supabase (Realtime).
/// أي عملية جديدة (فاتورة، منتج، عميل، مصروف...) بتظهر هنا فورًا،
/// وعلى الأندرويد بتتحول لإشعار على شاشة الهاتف.
class NotificationService with WidgetsBindingObserver {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// آخر الإشعارات (الأحدث أولًا).
  final ValueNotifier<List<Map<String, dynamic>>> items =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);

  /// عدد الإشعارات غير المقروءة.
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// بيزيد كل ما تحصل عملية جديدة — الصفحات بتستخدمه لتحديث نفسها.
  final ValueNotifier<int> dataTick = ValueNotifier<int>(0);

  /// آخر إشعار وصل (لعرضه كتنبيه داخل التطبيق على ويندوز).
  final ValueNotifier<Map<String, dynamic>?> latest =
      ValueNotifier<Map<String, dynamic>?>(null);

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _pluginReady = false;
  StreamSubscription<dynamic>? _sub;
  String? _businessId;
  final Set<String> _seen = <String>{};
  bool _first = true;
  DateTime _lastSeenAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  int _nextId = 1;

  DateTime get lastSeenAt => _lastSeenAt;

  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// لتحديث الصفحات المفتوحة بعد أي عملية محلية.
  void bump() => dataTick.value++;

  Future<void> _initPlugin() async {
    if (_pluginReady || !isAndroid) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
      _pluginReady = true;
    } catch (_) {
      _pluginReady = false;
    }
  }

  Future<void> start(String businessId) async {
    if (_businessId == businessId && _sub != null) return;
    await stop();
    if (SupabaseService.client == null) return;
    _businessId = businessId;
    _first = true;
    _seen.clear();
    await _initPlugin();
    final prefs = await SharedPreferences.getInstance();
    _lastSeenAt = DateTime.tryParse(prefs.getString('notif_seen_$businessId') ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    await _sub?.cancel();
    _sub = null;
    _businessId = null;
    _seen.clear();
    items.value = <Map<String, dynamic>>[];
    unread.value = 0;
  }

  void _subscribe() {
    final c = SupabaseService.client;
    final id = _businessId;
    if (c == null || id == null) return;
    _sub?.cancel();
    _sub = c
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('business_id', id)
        .order('created_at', ascending: false)
        .limit(100)
        .listen(_onRows, onError: (_) {});
  }

  /// لما التطبيق يرجع للواجهة نعيد الاشتراك لجلب اللي فات.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _businessId != null) {
      _subscribe();
    }
  }

  void _onRows(dynamic event) {
    final rows = List<Map<String, dynamic>>.from(event as List);
    rows.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    items.value = rows;

    final fresh = rows.where((r) => !_seen.contains('${r['id']}')).toList();
    for (final r in rows) {
      _seen.add('${r['id']}');
    }

    if (_first) {
      _first = false;
    } else if (fresh.isNotEmpty) {
      dataTick.value++;
      _notifyFresh(fresh);
    }
    _recount();
  }

  bool _suppressed(Map<String, dynamic> r) {
    final mine = r['created_by'] != null &&
        r['created_by'] == SupabaseService.currentUser?.id;
    final recentlyWroteHere =
        DateTime.now().difference(TrackingClient.lastWrite) < const Duration(seconds: 10);
    return mine && recentlyWroteHere;
  }

  void _notifyFresh(List<Map<String, dynamic>> fresh) {
    final visible = fresh.where((r) => !_suppressed(r)).toList()
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    if (visible.isEmpty) return;
    latest.value = visible.last;
    if (!_pluginReady) return;
    if (visible.length <= 3) {
      for (final r in visible) {
        _show('${r['title']}', '${r['body'] ?? ''}');
      }
    } else {
      _show('عمليات جديدة', '${visible.length} عمليات جديدة على النشاط');
    }
  }

  Future<void> _show(String title, String body) async {
    if (!_pluginReady) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sales_events',
        'إشعارات المبيعات',
        channelDescription: 'تنبيهات بالعمليات الجديدة على النشاط',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.show(_nextId++, title, body, details);
    } catch (_) {}
  }

  /// زرار "تجربة إشعار" في صفحة الإشعارات.
  Future<bool> sendTest() async {
    await _initPlugin();
    if (!_pluginReady) return false;
    await _show('تجربة الإشعارات', 'لو وصلك ده يبقى الإشعارات شغالة على جهازك ✓');
    return true;
  }

  void _recount() {
    unread.value = items.value.where((r) {
      final d = DateTime.tryParse('${r['created_at']}');
      return d != null && d.isAfter(_lastSeenAt);
    }).length;
  }

  Future<void> markAllRead() async {
    final id = _businessId;
    if (id == null || items.value.isEmpty) return;
    final newest = items.value
        .map((r) => DateTime.tryParse('${r['created_at']}'))
        .whereType<DateTime>()
        .fold<DateTime>(_lastSeenAt, (a, b) => b.isAfter(a) ? b : a);
    _lastSeenAt = newest;
    unread.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_seen_$id', newest.toUtc().toIso8601String());
  }

  Future<void> clearAll() async {
    final c = SupabaseService.client;
    final id = _businessId;
    if (c == null || id == null) return;
    await c.from('notifications').delete().eq('business_id', id);
    items.value = <Map<String, dynamic>>[];
    unread.value = 0;
  }
}
