import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'sales_report.dart';
import 'report_pages.dart';
import 'inventory.dart';

class ReportsPage extends StatelessWidget {
  final String? businessId;
  const ReportsPage({super.key, this.businessId});

  void _openSalesReport(BuildContext context) {
    if (businessId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SalesReportPage(businessId: businessId!),
    ));
  }

  void _open(BuildContext context, Widget page) {
    if (businessId == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('التقارير والتحليلات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('تقارير المبيعات والأرباح والمخزون والعملاء', style: TextStyle(color: AppTheme.muted)),
      const SizedBox(height: 24),
      Expanded(child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 3 : 1,
        crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: MediaQuery.sizeOf(context).width > 900 ? 1.3 : 1.6,
        children: [
          _card(context, Icons.payments_rounded, 'تقرير المبيعات', 'اليومي • الأسبوعي • الشهري',
              () => _openSalesReport(context)),
          _card(context, Icons.trending_up_rounded, 'تقرير الأرباح', 'المبيعات - التكلفة - المصروفات',
              () => _open(context, ProfitReportPage(businessId: businessId!))),
          _card(context, Icons.inventory_2_rounded, 'تقرير المخزون', 'حركة الأصناف والتنبيهات',
              () => _open(context, Scaffold(
                    appBar: AppBar(title: const Text('تقرير المخزون')),
                    body: SafeArea(child: InventoryPage(businessId: businessId)),
                  ))),
          _card(context, Icons.people_alt_rounded, 'تقرير العملاء', 'المشتريات والمديونيات',
              () => _open(context, CustomersReportPage(businessId: businessId!))),
          _card(context, Icons.shopping_cart_rounded, 'تقرير المشتريات', 'الموردون وفواتير الشراء',
              () => _open(context, PurchasesReportPage(businessId: businessId!))),
          _card(context, Icons.receipt_long_rounded, 'تقرير المصروفات', 'حسب التصنيف والفترة',
              () => _open(context, ExpensesReportPage(businessId: businessId!))),
        ],
      )),
    ]),
  );

  Widget _card(BuildContext context, IconData icon, String title, String sub, VoidCallback onTap) => Container(
    decoration: AppTheme.card(radius: 20),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 50, height: 50,
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(.12), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: AppTheme.primary)),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(sub, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 10),
          const Row(children: [
            Text('فتح التقرير', style: TextStyle(color: AppTheme.primary)),
            Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.primary),
          ]),
        ]),
      ),
    ),
  ),
  );
}
