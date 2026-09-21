import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

/// قائمة "المزيد" على الهاتف: باقي أقسام البرنامج.
class MorePage extends StatelessWidget {
  final void Function(int index) onNavigate;
  const MorePage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String, IconData, int)>[
      ('سجل العمليات', 'كل العمليات وتفاصيلها', Icons.history_rounded, 5),
      ('المخزون', 'الكميات والتسويات والحركات', Icons.inventory_rounded, 6),
      ('المشتريات والموردون', 'فواتير الشراء وحسابات الموردين', Icons.shopping_cart_rounded, 7),
      ('المصروفات', 'تسجيل ومتابعة المصروفات', Icons.money_off_csred_rounded, 8),
      ('التقارير', 'المبيعات والأرباح والعملاء', Icons.bar_chart_rounded, 4),
      ('الإشعارات', 'آخر العمليات من كل الأجهزة', Icons.notifications_rounded, 9),
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageTitle('المزيد', subtitle: 'كل أقسام البرنامج'),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onNavigate(e.$4),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.card(radius: 18),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(e.$3, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(e.$2, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                        ]),
                      ),
                      if (e.$4 == 9)
                        ValueListenableBuilder<int>(
                          valueListenable: NotificationService.instance.unread,
                          builder: (_, n, __) => n > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$n',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                )
                              : const SizedBox.shrink(),
                        ),
                      const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async => SupabaseService.signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('تسجيل الخروج'),
            ),
          ]),
        ),
      ]),
    );
  }
}
