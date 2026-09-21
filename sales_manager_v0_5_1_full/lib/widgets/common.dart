import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

void showSnack(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<T?> showDetailSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xF2FFFFFF),
    constraints: const BoxConstraints(maxWidth: 720),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => child,
  );
}

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageTitle(this.title, {super.key, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: AppTheme.muted)),
          ],
        ]),
      ),
      if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
    ]);
  }
}

class EmptyBox extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyBox(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: AppTheme.muted),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
        ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const InfoRow(this.label, this.value, {super.key, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ),
      ]),
    );
  }
}

class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const StatBox(this.label, this.value, this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.card(radius: 16),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: c.withOpacity(.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: c, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        ),
      ]),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid(this.children, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : 2;
      final w = (c.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class FilterChips<T> extends StatelessWidget {
  final List<(String, T)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(o.$1),
              selected: o.$2 == selected,
              onSelected: (_) => onSelected(o.$2),
            ),
          ),
      ]),
    );
  }
}

/// مربع حوار لإدخال نص واحد (مثل سبب الإلغاء).
Future<String?> askText(
  BuildContext context, {
  required String title,
  String? message,
  required String label,
  String confirmLabel = 'تأكيد',
  bool danger = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskTextDialog(
      title: title, message: message, label: label,
      confirmLabel: confirmLabel, danger: danger,
    ),
  );
}

class _AskTextDialog extends StatefulWidget {
  final String title, label, confirmLabel;
  final String? message;
  final bool danger;
  const _AskTextDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.danger,
    this.message,
  });
  @override
  State<_AskTextDialog> createState() => _AskTextDialogState();
}

class _AskTextDialogState extends State<_AskTextDialog> {
  final TextEditingController ctl = TextEditingController();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: widget.danger
          ? Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 34)
          : null,
      title: Text(widget.title, textAlign: widget.danger ? TextAlign.center : TextAlign.start),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(controller: ctl, decoration: InputDecoration(labelText: widget.label)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
        FilledButton(
          style: widget.danger
              ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(context, ctl.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class PaymentInput {
  final double amount;
  final String method;
  final String note;
  const PaymentInput(this.amount, this.method, this.note);
}

/// حوار تحصيل / سداد دفعة.
Future<PaymentInput?> askPayment(
  BuildContext context, {
  required String title,
  String? hint,
  double? initialAmount,
}) {
  return showDialog<PaymentInput>(
    context: context,
    builder: (_) => _PaymentDialog(title: title, hint: hint, initialAmount: initialAmount),
  );
}

class _PaymentDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final double? initialAmount;
  const _PaymentDialog({required this.title, this.hint, this.initialAmount});
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController amount;
  final TextEditingController note = TextEditingController();
  String method = 'cash';
  String? error;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAmount;
    amount = TextEditingController(text: (a != null && a > 0) ? qtyText(a) : '');
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _submit() {
    final v = parseAmount(amount.text);
    if (v == null || v <= 0) {
      setState(() => error = 'أدخل مبلغًا صحيحًا');
      return;
    }
    Navigator.pop(context, PaymentInput(v, method, note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.hint != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(widget.hint!, style: const TextStyle(color: AppTheme.muted)),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'المبلغ', errorText: error),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'طريقة الدفع'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقدي')),
              DropdownMenuItem(value: 'card', child: Text('بطاقة')),
              DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
            ],
            onChanged: (v) => setState(() => method = v ?? 'cash'),
          ),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _submit, child: const Text('تأكيد')),
      ],
    );
  }
}
