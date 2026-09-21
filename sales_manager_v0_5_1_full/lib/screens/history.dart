import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'details_sheets.dart';

enum _Period { today, week, month, all, custom }

/// سجل العمليات: كل ما حدث في النشاط، ومع تفاصيل كل عملية عند الضغط عليها.
class HistoryPage extends StatefulWidget {
  final String? businessId;
  const HistoryPage({super.key, this.businessId});
  @override State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String kind = 'all';
  _Period period = _Period.week;
  DateTimeRange? custom;
  String search = '';
  int limit = 100;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = [];

  static const _kinds = <(String, String)>[
    ('الكل', 'all'),
    ('مبيعات', 'sale'),
    ('مشتريات', 'purchase'),
    ('مصروفات', 'expense'),
    ('تحصيلات', 'payment_in'),
    ('سداد موردين', 'payment_out'),
    ('تسويات مخزون', 'stock_adjustment'),
  ];

  @override
  void initState() {
    super.initState();
    load();
    NotificationService.instance.dataTick.addListener(_onTick);
  }

  @override
  void dispose() {
    NotificationService.instance.dataTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) load(silent: true);
  }

  DateTime? get _since {
    final now = DateTime.now();
    switch (period) {
      case _Period.today:
        return DateTime(now.year, now.month, now.day);
      case _Period.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case _Period.month:
        return DateTime(now.year, now.month, 1);
      case _Period.custom:
        return custom?.start;
      case _Period.all:
        return null;
    }
  }

  DateTime? get _until {
    if (period == _Period.custom && custom != null) {
      final e = custom!.end;
      return DateTime(e.year, e.month, e.day).add(const Duration(days: 1));
    }
    return null;
  }

  Future<void> load({bool silent = false}) async {
    final id = widget.businessId;
    if (id == null) {
      setState(() => loading = false);
      return;
    }
    if (!silent) setState(() => loading = true);
    try {
      final r = await HistoryService.operations(
        id,
        kind: kind == 'all' ? null : kind,
        since: _since,
        until: _until,
        limit: limit,
      );
      rows = r;
      error = null;
    } catch (e) {
      error = friendlyError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: custom,
    );
    if (r == null) return;
    setState(() {
      custom = r;
      period = _Period.custom;
    });
    load();
  }

  void _setPeriod(_Period p) {
    if (p == _Period.custom) {
      _pickRange();
      return;
    }
    setState(() => period = p);
    load();
  }

  ({IconData icon, Color color, String title}) _meta(Map<String, dynamic> r) {
    final party = r['party'] as String?;
    switch ('${r['kind']}') {
      case 'sale':
        return (icon: Icons.receipt_long_rounded, color: Colors.green.shade700, title: 'فاتورة بيع #${r['ref']}');
      case 'purchase':
        return (icon: Icons.shopping_cart_rounded, color: Colors.blue.shade700, title: 'فاتورة شراء #${r['ref']}');
      case 'expense':
        return (icon: Icons.money_off_csred_rounded, color: Colors.red.shade700, title: 'مصروف — ${party ?? ''}');
      case 'payment_in':
        return (icon: Icons.south_west_rounded, color: Colors.teal.shade700, title: 'تحصيل من ${party ?? 'عميل'}');
      case 'payment_out':
        return (icon: Icons.north_east_rounded, color: Colors.deepOrange.shade700, title: 'سداد لـ ${party ?? 'مورد'}');
      default:
        return (icon: Icons.tune_rounded, color: Colors.purple.shade700, title: 'تسوية مخزون — ${party ?? ''}');
    }
  }

  void _open(Map<String, dynamic> r) {
    final id = r['id'] as String;
    switch ('${r['kind']}') {
      case 'sale':
        showSaleDetails(context, id, onChanged: load);
        break;
      case 'purchase':
        showPurchaseDetails(context, id, onChanged: load);
        break;
      case 'expense':
        showExpenseDetails(context, id, onChanged: load);
        break;
      case 'payment_in':
      case 'payment_out':
        showPaymentDetails(context, id);
        break;
      default:
        showMovementDetails(context, id);
    }
  }

  Widget _tile(Map<String, dynamic> r) {
    final m = _meta(r);
    final kindName = '${r['kind']}';
    final cancelled = r['status'] == 'cancelled';
    final party = r['party'] as String?;
    final sub = switch (kindName) {
      'sale' => '${party ?? 'عميل نقدي'} • ${paymentLabel(r['method'] as String?)}',
      'purchase' => '${party ?? 'بدون مورد'}',
      'payment_in' || 'payment_out' => paymentLabel(r['method'] as String?),
      'stock_adjustment' => InventoryLabel.of(r['method'] as String?),
      _ => '',
    };
    final amount = toNum(r['amount']);
    final amountText = kindName == 'stock_adjustment'
        ? '${amount > 0 ? '+' : ''}${qtyText(amount)}'
        : money(amount);
    final amountColor = cancelled
        ? AppTheme.muted
        : (kindName == 'sale' || kindName == 'payment_in')
            ? Colors.green.shade700
            : (kindName == 'stock_adjustment' ? null : Colors.red.shade700);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(r),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: AppTheme.card(radius: 16),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: m.color.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(m.icon, color: m.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  )),
              const SizedBox(height: 2),
              Text(
                [if (sub.isNotEmpty) sub, dateTimeText(r['created_at'])].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amountText, style: TextStyle(fontWeight: FontWeight.w900, color: amountColor)),
            if (cancelled) ...[
              const SizedBox(height: 3),
              Pill('ملغاة', Colors.red.shade700),
            ],
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.businessId == null) {
      return const EmptyBox('قم بإعداد النشاط والاتصال بالسحابة أولًا.');
    }
    final q = search.trim().toLowerCase();
    final shown = q.isEmpty
        ? rows
        : rows.where((r) =>
            '${r['ref'] ?? ''}'.toLowerCase().contains(q) ||
            '${r['party'] ?? ''}'.toLowerCase().contains(q)).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageTitle('سجل العمليات', subtitle: 'كل العمليات — اضغط على أي عملية لعرض تفاصيلها'),
        const SizedBox(height: 14),
        FilterChips<String>(
          options: _kinds,
          selected: kind,
          onSelected: (v) {
            setState(() => kind = v);
            load();
          },
        ),
        const SizedBox(height: 8),
        FilterChips<_Period>(
          options: const [
            ('اليوم', _Period.today),
            ('آخر 7 أيام', _Period.week),
            ('هذا الشهر', _Period.month),
            ('الكل', _Period.all),
            ('فترة مخصصة', _Period.custom),
          ],
          selected: period,
          onSelected: _setPeriod,
        ),
        if (period == _Period.custom && custom != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('من ${dayText(custom!.start.toIso8601String())} إلى ${dayText(custom!.end.toIso8601String())}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث برقم الفاتورة أو اسم العميل / المورد...',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? EmptyBox(error!, icon: Icons.error_outline)
                  : shown.isEmpty
                      ? const EmptyBox('لا توجد عمليات في هذه الفترة.', icon: Icons.history_rounded)
                      : RefreshIndicator(
                          onRefresh: () => load(silent: true),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: shown.length + (rows.length >= limit ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              if (i >= shown.length) {
                                return Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() => limit += 100);
                                      load();
                                    },
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: const Text('تحميل المزيد'),
                                  ),
                                );
                              }
                              return _tile(shown[i]);
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

/// تسميات نوع حركة المخزون في سجل العمليات.
class InventoryLabel {
  static String of(String? t) => switch (t) {
        'damage' => 'تالف',
        'adjustment' => 'تسوية',
        _ => t ?? '',
      };
}
