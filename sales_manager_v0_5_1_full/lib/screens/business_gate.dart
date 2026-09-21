import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/business_service.dart';

class BusinessGate extends StatefulWidget {
  final void Function(String businessId) onOpen;
  const BusinessGate({super.key, required this.onOpen});
  @override State<BusinessGate> createState() => _BusinessGateState();
}

class _BusinessGateState extends State<BusinessGate> {
  List<Map<String, dynamic>> businesses = [];
  bool loading = true;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      businesses = await BusinessService.myBusinesses();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> createBusiness() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنشاء نشاط جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المحل / الشركة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('إنشاء')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    setState(() => creating = true);
    try {
      final id = await BusinessService.create(name);
      if (!mounted) return;
      widget.onOpen(id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء النشاط. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void open(String id) => widget.onOpen(id);

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('اختر نشاطك', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              const Text('البيانات والفواتير والمخزون ستظل مرتبطة بهذا النشاط.', style: TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 22),
              ...businesses.map((b) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store_rounded)),
                  title: Text('${b['name'] ?? 'بدون اسم'}'),
                  subtitle: Text('${b['currency_code'] ?? 'EGP'}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => open(b['id'] as String),
                ),
              )),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
                onPressed: creating ? null : createBusiness,
                icon: const Icon(Icons.add_business_rounded),
                label: Text(creating ? 'جارٍ الإنشاء...' : 'إنشاء نشاط جديد'),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}
