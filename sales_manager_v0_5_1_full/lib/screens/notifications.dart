import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import 'details_sheets.dart';

IconData notificationIcon(String kind) {
  switch (kind) {
    case 'sale':
      return Icons.receipt_long_rounded;
    case 'sale_cancelled':
    case 'purchase_cancelled':
      return Icons.block_rounded;
    case 'purchase':
      return Icons.shopping_cart_rounded;
    case 'product_added':
      return Icons.inventory_2_rounded;
    case 'low_stock':
    case 'out_of_stock':
      return Icons.warning_amber_rounded;
    case 'customer_added':
      return Icons.person_add_alt_1_rounded;
    case 'supplier_added':
      return Icons.local_shipping_rounded;
    case 'expense':
      return Icons.money_off_csred_rounded;
    case 'payment_in':
      return Icons.south_west_rounded;
    case 'payment_out':
      return Icons.north_east_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color notificationColor(String kind) {
  switch (kind) {
    case 'sale':
    case 'payment_in':
      return Colors.green.shade700;
    case 'sale_cancelled':
    case 'purchase_cancelled':
    case 'out_of_stock':
    case 'expense':
      return Colors.red.shade700;
    case 'low_stock':
    case 'payment_out':
      return Colors.orange.shade800;
    case 'purchase':
      return Colors.blue.shade700;
    default:
      return AppTheme.primary;
  }
}

class NotificationsPage extends StatefulWidget {
  final String? businessId;
  final void Function(int index)? onNavigate;
  const NotificationsPage({super.key, this.businessId, this.onNavigate});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final DateTime seenAtOpen;

  @override
  void initState() {
    super.initState();
    final svc = NotificationService.instance;
    seenAtOpen = svc.lastSeenAt;
    svc.items.addListener(_markRead);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    NotificationService.instance.items.removeListener(_markRead);
    super.dispose();
  }

  void _markRead() {
    if (mounted) NotificationService.instance.markAllRead();
  }

  Future<void> _clear() async {
    final ok = await confirmDelete(
      context,
      title: 'مسح الإشعارات',
      message: 'سيتم حذف كل الإشعارات من كل الأجهزة. العمليات نفسها لن تتأثر.',
      confirmLabel: 'مسح الكل',
    );
    if (!ok) return;
    try {
      await NotificationService.instance.clearAll();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _test() async {
    final ok = await NotificationService.instance.sendTest();
    if (!mounted) return;
    showSnack(
      context,
      ok
          ? 'تم إرسال إشعار تجريبي.'
          : 'إشعارات النظام متاحة على أندرويد فقط، وعلى هذا الجهاز ستظهر تنبيهات داخل التطبيق.',
    );
  }

  void _open(Map<String, dynamic> n) {
    final kind = '${n['kind']}';
    final ref = n['ref_id'] as String?;
    switch (kind) {
      case 'sale':
      case 'sale_cancelled':
        if (ref != null) showSaleDetails(context, ref);
        break;
      case 'purchase':
      case 'purchase_cancelled':
        if (ref != null) showPurchaseDetails(context, ref);
        break;
      case 'expense':
        if (ref != null) showExpenseDetails(context, ref);
        break;
      case 'payment_in':
      case 'payment_out':
        if (ref != null) showPaymentDetails(context, ref);
        break;
      case 'low_stock':
      case 'out_of_stock':
        widget.onNavigate?.call(6);
        break;
      case 'product_added':
        widget.onNavigate?.call(1);
        break;
      case 'customer_added':
        widget.onNavigate?.call(3);
        break;
      case 'supplier_added':
        widget.onNavigate?.call(7);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService.instance;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageTitle(
          'الإشعارات',
          subtitle: 'كل عملية جديدة على النشاط من أي جهاز',
          actions: [
            IconButton(
              tooltip: 'مسح الكل',
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.card(radius: 16),
          child: Row(children: [
            Icon(Icons.phone_android_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                svc.isAndroid
                    ? 'ستصلك إشعارات على هاتفك عند أي عملية جديدة من جهاز آخر، طالما التطبيق يعمل في الخلفية.'
                    : 'تظهر التنبيهات داخل التطبيق فور حدوث أي عملية من جهاز آخر.',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _test, child: const Text('تجربة')),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: svc.items,
            builder: (context, items, _) {
              if (items.isEmpty) {
                return const EmptyBox('لا توجد إشعارات بعد.', icon: Icons.notifications_none_rounded);
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = items[i];
                  final kind = '${n['kind']}';
                  final color = notificationColor(kind);
                  final created = DateTime.tryParse('${n['created_at']}');
                  final isNew = created != null && created.isAfter(seenAtOpen);
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _open(n),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: AppTheme.card(radius: 16),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(notificationIcon(kind), color: color, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            if ((n['body'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('${n['body']}',
                                    style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                              ),
                            const SizedBox(height: 4),
                            Text(timeAgo(n['created_at']),
                                style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                          ]),
                        ),
                        if (isNew) Pill('جديد', color),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
