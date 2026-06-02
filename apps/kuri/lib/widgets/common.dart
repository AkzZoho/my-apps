import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

// ─── Avatar ──────────────────────────────────────────────────────────────────

Color _colorFromName(String name) {
  final colors = [
    const Color(0xFF6366f1),
    const Color(0xFF8b5cf6),
    const Color(0xFFec4899),
    const Color(0xFFf43f5e),
    const Color(0xFFf97316),
    const Color(0xFFeab308),
    const Color(0xFF22c55e),
    const Color(0xFF14b8a6),
    const Color(0xFF0ea5e9),
    const Color(0xFF3b82f6),
  ];
  int hash = 0;
  for (final ch in name.codeUnits) {
    hash = (hash * 31 + ch) & 0xFFFFFF;
  }
  return colors[hash % colors.length];
}

class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;

  const AvatarWidget({super.key, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFromName(name),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor ?? color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Section Title ───────────────────────────────────────────────────────────

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: c.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── App Card ────────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
            )
          : Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    );
  }
}

// ─── Loading Overlay ─────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;

  const LoadingOverlay({super.key, required this.loading, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        child,
        if (loading)
          Container(
            color: Colors.black45,
            child: Center(child: CircularProgressIndicator(color: c.primary)),
          ),
      ],
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.textDim, size: 48),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(color: c.textMuted, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(color: c.textDim, fontSize: 13), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Date Formatter ───────────────────────────────────────────────────────────

String formatDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate);
    return DateFormat('dd MMM yyyy').format(dt);
  } catch (_) {
    return isoDate;
  }
}

String formatMonthKey(String monthKey) {
  try {
    final parts = monthKey.split('-');
    if (parts.length < 2) return monthKey;
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMM yyyy').format(dt);
  } catch (_) {
    return monthKey;
  }
}

String monthKeyFromDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
}

List<String> generateMonths(String startDateStr, {bool includeFuture = false}) {
  final months = <String>[];
  try {
    final start = DateTime.parse(startDateStr);
    final startMonthKey = monthKeyFromDate(DateTime(start.year, start.month));
    final now = DateTime.now();
    var end = DateTime(now.year, now.month);
    if (includeFuture) {
      end = DateTime(now.year, now.month + 1);
    }
    var current = DateTime(start.year, start.month);
    while (!current.isAfter(end)) {
      months.add(monthKeyFromDate(current));
      current = DateTime(current.year, current.month + 1);
    }
    // startMonthKey is computed but months list suffices
    startMonthKey.toString(); // prevent unused variable lint
  } catch (_) {}
  return months;
}

// ─── Copy Button ─────────────────────────────────────────────────────────────

class CopyButton extends StatelessWidget {
  final String text;
  const CopyButton(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      icon: Icon(Icons.copy, size: 16, color: c.textMuted),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
        );
      },
      tooltip: 'Copy',
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

// ─── Divider ─────────────────────────────────────────────────────────────────

class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Divider(color: c.border, height: 1);
  }
}

// ─── Confirm Dialog ──────────────────────────────────────────────────────────

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color? confirmColor,
}) async {
  final c = context.colors;
  final effectiveConfirmColor = confirmColor ?? c.danger;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cc = ctx.colors;
      return AlertDialog(
        backgroundColor: cc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cc.border),
        ),
        title: Text(title, style: TextStyle(color: cc.text)),
        content: Text(message, style: TextStyle(color: cc.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: cc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: effectiveConfirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

// ─── Error Snackbar ──────────────────────────────────────────────────────────

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: context.colors.danger,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: context.colors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ─── Bottom Sheet Helper ─────────────────────────────────────────────────────

Future<T?> showAppBottomSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}
