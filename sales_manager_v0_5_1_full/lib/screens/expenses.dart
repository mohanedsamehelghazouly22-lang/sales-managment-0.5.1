import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/expense_service.dart';
import '../services/notification_service.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'details_sheets.dart';

enum _ExpPeriod { today, month, all }

class ExpensesPage extends StatefulWidget {
  final String? businessId;
  const ExpensesPage({super.key, this.businessId});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  _ExpPeriod period = _ExpPeriod.month;
  String? category;

  Future<void> _add() async {
    final bid = widget.businessId;
    if (bid == null) return;
    final res = await showDialog<(String, double, String)>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (res == null) return;
    try {
      await ExpenseService.add(
        businessId: bid,
        category: res.$1,
        amount: res.$2,
        note: res.$3,
      );
      NotificationService.instance.bump();
      if (mounted) showSnack(context, 'تم تسجيل المصروف.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  bool _inPeriod(Map<String, dynamic> e) {
    final d = parseDate(e['created_at']);
    if (d == null) return false;
    final now = DateTime.now();
    switch (period) {
      case _ExpPeriod.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case _ExpPeriod.month:
        return d.year == now.year && d.month == now.month;
      case _ExpPeriod.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bid = widget.businessId;
    if (bid == null) {
      return const EmptyBox('قم بإعداد النشاط والاتصال بالسحابة أولًا.');
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageTitle(
          'المصروفات',
          subtitle: 'إيجار، كهرباء، رواتب، وأي مصروف آخر',
          actions: [
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('مصروف'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilterChips<_ExpPeriod>(
          options: const [
            ('اليوم', _ExpPeriod.today),
            ('هذا الشهر', _ExpPeriod.month),
            ('الكل', _ExpPeriod.all),
          ],
          selected: period,
          onSelected: (v) => setState(() {
            period = v;
            category = null;
          }),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: ExpenseService.stream(bid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final inPeriod = (snap.data ?? []).where(_inPeriod).toList();
              if (inPeriod.isEmpty) {
                return const EmptyBox('لا توجد مصروفات في هذه الفترة.', icon: Icons.receipt_long_outlined);
              }
              final totals = <String, double>{};
              for (final e in inPeriod) {
                final c = '${e['category']}';
                totals[c] = (totals[c] ?? 0) + toNum(e['amount']).toDouble();
              }
              final sum = totals.values.fold<double>(0, (a, b) => a + b);
              final cats = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final rows = category == null
                  ? inPeriod
                  : inPeriod.where((e) => '${e['category']}' == category).toList();

              return ListView.separated(
                itemCount: rows.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      StatGrid([
                        StatBox('إجمالي المصروفات', money(sum), Icons.money_off_csred_rounded,
                            color: Colors.red.shade700),
                        StatBox('عدد المصروفات', '${inPeriod.length}', Icons.receipt_long_outlined),
                      ]),
                      const SizedBox(height: 12),
                      const Text('حسب التصنيف', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      FilterChips<String?>(
                        options: [
                          ('الكل', null),
                          for (final c in cats) ('${c.key} • ${money(c.value)}', c.key),
                        ],
                        selected: category,
                        onSelected: (v) => setState(() => category = v),
                      ),
                    ]);
                  }
                  final e = rows[i - 1];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showExpenseDetails(context, e['id'] as String),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: AppTheme.card(radius: 16),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700.withOpacity(.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.money_off_csred_rounded, color: Colors.red.shade700, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${e['category']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              [dateTimeText(e['created_at']), if ((e['note'] ?? '').toString().isNotEmpty) '${e['note']}'].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                            ),
                          ]),
                        ),
                        Text(money(e['amount']),
                            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red.shade700)),
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

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final TextEditingController category = TextEditingController();
  final TextEditingController amount = TextEditingController();
  final TextEditingController note = TextEditingController();
  String? catError, amountError;

  static const _suggestions = ['إيجار', 'كهرباء', 'مياه', 'إنترنت', 'رواتب', 'نقل', 'صيانة', 'تسويق', 'أخرى'];

  @override
  void dispose() {
    category.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _submit() {
    final c = category.text.trim();
    final a = parseAmount(amount.text);
    setState(() {
      catError = c.isEmpty ? 'اختر أو اكتب التصنيف' : null;
      amountError = (a == null || a <= 0) ? 'أدخل مبلغًا صحيحًا' : null;
    });
    if (catError != null || amountError != null) return;
    Navigator.pop(context, (c, a!, note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة مصروف'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in _suggestions)
                ActionChip(label: Text(s), onPressed: () => setState(() => category.text = s)),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: category,
              decoration: InputDecoration(labelText: 'التصنيف', errorText: catError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'المبلغ', errorText: amountError),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
