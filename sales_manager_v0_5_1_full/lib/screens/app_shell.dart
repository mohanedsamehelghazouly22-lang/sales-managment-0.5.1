import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'dashboard.dart';
import 'products.dart';
import 'sales.dart';
import 'customers.dart';
import 'reports.dart';
import 'history.dart';
import 'inventory.dart';
import 'purchases.dart';
import 'expenses.dart';
import 'notifications.dart';
import 'more.dart';

class AppShell extends StatefulWidget {
  final String? businessId;
  const AppShell({super.key, this.businessId});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  static const int _salesIndex = 2;
  static const int _notificationsIndex = 9;
  static const int _moreIndex = 10;

  // صفحة البيع تفضل شغالة في الخلفية عشان الفاتورة ما تضيعش لما تتنقل بين الأقسام.
  late final Widget _salesPage = SalesPage(businessId: widget.businessId);

  void goTo(int i) => setState(() => index = i);

  @override
  void initState() {
    super.initState();
    final id = widget.businessId;
    if (id != null) NotificationService.instance.start(id);
    NotificationService.instance.latest.addListener(_onLatest);
  }

  @override
  void dispose() {
    NotificationService.instance.latest.removeListener(_onLatest);
    NotificationService.instance.stop();
    super.dispose();
  }

  /// تنبيه داخل التطبيق (على ويندوز) عند وصول عملية جديدة من جهاز آخر.
  void _onLatest() {
    final n = NotificationService.instance.latest.value;
    if (n == null || !mounted || NotificationService.instance.isAndroid) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('${n['title']}${(n['body'] ?? '').toString().isEmpty ? '' : ' — ${n['body']}'}'),
      action: SnackBarAction(label: 'عرض', onPressed: () => goTo(_notificationsIndex)),
    ));
  }

  Widget _page(int i) {
    switch (i) {
      case 0:
        return DashboardPage(businessId: widget.businessId, onNavigate: goTo);
      case 1:
        return ProductsPage(businessId: widget.businessId);
      case 3:
        return CustomersPage(businessId: widget.businessId);
      case 4:
        return ReportsPage(businessId: widget.businessId);
      case 5:
        return HistoryPage(businessId: widget.businessId);
      case 6:
        return InventoryPage(businessId: widget.businessId);
      case 7:
        return PurchasesPage(businessId: widget.businessId);
      case 8:
        return ExpensesPage(businessId: widget.businessId);
      case 9:
        return NotificationsPage(businessId: widget.businessId, onNavigate: goTo);
      default:
        return MorePage(onNavigate: goTo);
    }
  }

  Widget _body() {
    return Stack(children: [
      Positioned.fill(child: Offstage(offstage: index != _salesIndex, child: _salesPage)),
      if (index != _salesIndex) Positioned.fill(child: _page(index)),
    ]);
  }

  // أقسام الشريط الجانبي (ويندوز / الشاشات الكبيرة)
  final labels = ['الرئيسية','المنتجات','المبيعات','العملاء','التقارير','سجل العمليات','المخزون','المشتريات والموردون','المصروفات','الإشعارات'];
  final icons = [
    Icons.grid_view_rounded, Icons.inventory_2_rounded, Icons.receipt_long_rounded,
    Icons.people_alt_rounded, Icons.bar_chart_rounded, Icons.history_rounded,
    Icons.inventory_rounded, Icons.shopping_cart_rounded, Icons.money_off_csred_rounded,
    Icons.notifications_rounded,
  ];

  // شريط الهاتف السفلي: 4 أقسام رئيسية + المزيد
  final navLabels = ['الرئيسية','المنتجات','المبيعات','العملاء','المزيد'];
  final navIcons = [
    Icons.grid_view_rounded, Icons.inventory_2_rounded, Icons.receipt_long_rounded,
    Icons.people_alt_rounded, Icons.apps_rounded,
  ];

  int get _navSelected => index < 4 ? index : 4;

  void _onNavTap(int i) => setState(() => index = i < 4 ? i : _moreIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Row(children: [
        if (wide) _sidebar(),
        Expanded(child: SafeArea(child: _body())),
      ]),
      bottomNavigationBar: wide ? null : _pillNav(),
    );
  }

  Widget _unreadDot(Widget icon) => ValueListenableBuilder<int>(
    valueListenable: NotificationService.instance.unread,
    builder: (_, n, __) => n > 0
        ? Stack(clipBehavior: Clip.none, children: [
            icon,
            Positioned(
              top: -2, right: -2,
              child: Container(
                width: 9, height: 9,
                decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle),
              ),
            ),
          ])
        : icon,
  );

  Widget _pillNav() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    // زجاج حقيقي (Backdrop Blur) بدل الحاوية السودة الصلبة القديمة —
    // الشريط بقى شفاف ومعتّم وبيوري لمعة اللي وراه.
    child: AppTheme.glass(
      radius: 34,
      blur: 24,
      opacity: .5,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 68,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(navLabels.length, (i) {
            final selected = _navSelected == i;
            final icon = Icon(navIcons[i], size: 22, color: selected ? Colors.white : AppTheme.muted);
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _onNavTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
                  padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 0, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(colors: [AppTheme.primary, AppTheme.accent])
                        : null,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: selected
                        ? [BoxShadow(color: AppTheme.primary.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 6))]
                        : null,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    i == 4 ? _unreadDot(icon) : icon,
                    if (selected) ...[
                      const SizedBox(width: 5),
                      Flexible(child: Text(navLabels[i],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                    ],
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );

  Widget _sidebar() => SizedBox(
    width: 245,
    // نفس فكرة الزجاج الحقيقي مطبّقة على القائمة الجانبية (نسخة الشاشات
    // الكبيرة/ويندوز) بدل اللون شبه الصلب القديم.
    child: AppTheme.glass(
      radius: 0,
      blur: 30,
      opacity: .5,
      border: const Border(right: BorderSide(color: AppTheme.glassBorder)),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width:42,height:42,
            decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),
              gradient:const LinearGradient(colors:[AppTheme.primary,AppTheme.accent])),
            child:const Icon(Icons.bar_chart_rounded, color: Colors.white)),
          const SizedBox(width:10),
          const Expanded(child: Text('Sales Manager', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.text))),
        ]),
        const SizedBox(height: 26),
        Expanded(
          child: ListView(children: List.generate(labels.length, (i) {
            final selected = index == i;
            final leading = Icon(icons[i], color: selected ? AppTheme.primary : AppTheme.muted);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(
                dense: true,
                selected: selected,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                selectedTileColor: AppTheme.primary.withOpacity(.12),
                leading: leading,
                title: Text(labels[i], style: TextStyle(
                  color: selected ? AppTheme.text : AppTheme.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                trailing: i == _notificationsIndex
                    ? ValueListenableBuilder<int>(
                        valueListenable: NotificationService.instance.unread,
                        builder: (_, n, __) => n > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                              )
                            : const SizedBox.shrink(),
                      )
                    : null,
                onTap: () => setState(() => index = i),
              ),
            );
          })),
        ),
        const Divider(color: Colors.black12),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: AppTheme.muted),
          title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.muted)),
          onTap: () async => SupabaseService.signOut(),
        ),
      ]),
    ),
  );
}
