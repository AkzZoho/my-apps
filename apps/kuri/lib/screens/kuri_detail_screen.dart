import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../src/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common.dart';
import 'kuri_auction_screen.dart';

// ─── Receipt viewer helpers ───────────────────────────────────────────────────

Uint8List? _decodeBase64Bytes(String base64Data) {
  try {
    final data = base64Data.contains(',') ? base64Data.split(',').last : base64Data;
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

void _openReceiptViewer(BuildContext context, Uint8List bytes, String filename) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: true,
    builder: (_) => _ReceiptViewerDialog(bytes: bytes, filename: filename),
  );
}

Widget _receiptThumbnail(
  BuildContext context,
  String base64Data, {
  bool fullWidth = false,
  String filename = 'receipt.jpg',
}) {
  final bytes = _decodeBase64Bytes(base64Data);
  if (bytes == null) {
    return Icon(Icons.broken_image, color: context.colors.textDim);
  }
  return GestureDetector(
    onTap: () => _openReceiptViewer(context, bytes, filename),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Image.memory(
            bytes,
            width: fullWidth ? double.infinity : 80,
            height: fullWidth ? null : 64,
            fit: fullWidth ? BoxFit.contain : BoxFit.cover,
          ),
          Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
          ),
        ],
      ),
    ),
  );
}

class _ReceiptViewerDialog extends ConsumerWidget {
  final Uint8List bytes;
  final String filename;

  const _ReceiptViewerDialog({required this.bytes, required this.filename});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n(ref.watch(localeProvider));
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: l10n.close,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    if (kIsWeb)
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        tooltip: 'Download',
                        onPressed: _download,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _download() {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement()
      ..href = url
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class KuriDetailScreen extends ConsumerStatefulWidget {
  final String kuriId;

  const KuriDetailScreen({super.key, required this.kuriId});

  @override
  ConsumerState<KuriDetailScreen> createState() => _KuriDetailScreenState();
}

class _KuriDetailScreenState extends ConsumerState<KuriDetailScreen> {
  bool _loading = false;
  AppL10n? _l10n;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCreatorPayments());
  }

  Future<void> _ensureCreatorPayments() async {
    final data = ref.read(appDataProvider).valueOrNull;
    if (data == null) return;
    final user = ref.read(currentUserProvider);
    final kuri = data.kuris.firstWhere((k) => k.id == widget.kuriId,
        orElse: () => KuriPlan(id: '', name: '', contributionAmount: 0, currency: '', startDate: '', participantUserIds: [], notificationConfig: NotificationConfig(rules: []), createdBy: '', createdAt: ''));
    if (kuri.id.isEmpty || kuri.createdBy != user?.id) return;
    await dataService.ensureCreatorPayments(widget.kuriId);
    final fresh = await dataService.getData();
    if (mounted) ref.read(appDataProvider.notifier).updateState(fresh);
  }

  Future<void> _deleteKuri(KuriPlan kuri) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final confirmed = await confirmDialog(
      context,
      title: _l10n!.deleteKuri,
      message: '${_l10n!.areYouSureDelete} "${kuri.name}"? ${_l10n!.cannotUndo}',
      confirmLabel: _l10n!.delete,
    );
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    try {
      await dataService.deleteKuri(kuri.id, user.id);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) {
        context.pop();
        showSuccess(context, _l10n!.kuriDeleted);
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDrawWinnerSheet(KuriPlan kuri, AppData data) {
    showAppBottomSheet(
      context,
      _DrawWinnerSheet(
        kuri: kuri,
        data: data,
        currentUserId: ref.read(currentUserProvider)?.id ?? '',
      ),
    ).then((_) async {
      final fresh = await dataService.getData();
      if (mounted) ref.read(appDataProvider.notifier).updateState(fresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locale = ref.watch(localeProvider);
    final l10n = AppL10n(locale);
    _l10n = l10n;
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    // Use cached data so the screen never flashes a loading state during
    // navigation transitions (swipe-back gesture renders both screens per frame).
    final data = appDataAsync.valueOrNull;

    if (data == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(appDataAsync.hasError ? l10n.error : l10n.loading)),
        body: appDataAsync.hasError
            ? Center(child: Text('${appDataAsync.error}', style: TextStyle(color: c.danger)))
            : Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    final kuri = data.kuris.firstWhere(
      (k) => k.id == widget.kuriId,
      orElse: () => KuriPlan(
        id: '',
        name: l10n.kuriNotFound,
        contributionAmount: 0,
        currency: 'INR',
        startDate: '',
        participantUserIds: [],
        notificationConfig: NotificationConfig(rules: []),
        createdBy: '',
        createdAt: '',
      ),
    );

    if (kuri.id.isEmpty) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.appName)),
        body: Center(child: Text(l10n.kuriNotFound, style: TextStyle(color: c.textMuted))),
      );
    }

    final isCreator = user?.id == kuri.createdBy;
    final kuriPayments = data.payments.where((p) => p.kuriId == kuri.id).toList();
    final approvedPayments = kuriPayments.where((p) => p.status == 'approved').toList();
    final totalCollected = approvedPayments.fold<double>(0, (s, p) => s + p.amount);

    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: Text(kuri.name),
          actions: [
            if (isCreator)
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.danger),
                onPressed: () => _deleteKuri(kuri),
                tooltip: l10n.deleteKuri,
              ),
          ],
        ),
        body: isCreator
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KuriHeader(kuri: kuri, totalCollected: totalCollected, l10n: l10n),
                    _TotalsPanel(
                      kuri: kuri,
                      payments: kuriPayments,
                      data: data,
                      isCreator: true,
                      currentUserId: user?.id ?? '',
                      l10n: l10n,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          _NavTile(
                            icon: Icons.receipt_long_outlined,
                            label: l10n.receipts,
                            onTap: () => context.push('/kuri/${widget.kuriId}/receipts'),
                          ),
                          const SizedBox(height: 8),
                          if (kuri.kuriType == 'lelam') ...[
                            _NavTile(
                              icon: Icons.gavel,
                              label: l10n.auction,
                              onTap: () => context.push('/kuri/${widget.kuriId}/auction'),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (kuri.kuriType == 'changatha') ...[
                            _NavTile(
                              icon: Icons.casino_outlined,
                              label: l10n.drawWinner,
                              onTap: () => _showDrawWinnerSheet(kuri, data),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _NavTile(
                            icon: Icons.settings_outlined,
                            label: l10n.settings,
                            onTap: () => context.push('/kuri/${widget.kuriId}/settings'),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _KuriHeader(kuri: kuri, totalCollected: totalCollected, l10n: l10n),
                  _TotalsPanel(
                    kuri: kuri,
                    payments: kuriPayments,
                    data: data,
                    isCreator: false,
                    currentUserId: user?.id ?? '',
                    l10n: l10n,
                  ),
                  Expanded(
                    child: _MemberPaymentView(
                      kuri: kuri,
                      data: data,
                      currentUserId: user?.id ?? '',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Nav Tile ─────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(color: c.text, fontSize: 15)),
            ),
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Kuri Header ─────────────────────────────────────────────────────────────

class _KuriHeader extends StatelessWidget {
  final KuriPlan kuri;
  final double totalCollected;
  final AppL10n l10n;

  const _KuriHeader({required this.kuri, required this.totalCollected, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      color: c.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '₹${kuri.contributionAmount.toInt()}/mo',
                      style: TextStyle(
                          color: c.primary, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${kuri.participantUserIds.length} ${kuri.participantUserIds.length != 1 ? l10n.participants : l10n.participant}',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.started} ${formatDate(kuri.startDate)}',
                  style: TextStyle(color: c.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(l10n.totalCollected, style: TextStyle(color: c.textMuted, fontSize: 11)),
              Text(
                '₹${totalCollected.toInt()}',
                style: TextStyle(
                    color: c.green, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Totals Panel ─────────────────────────────────────────────────────────────

class _TotalsPanel extends StatelessWidget {
  final KuriPlan kuri;
  final List<KuriPayment> payments;
  final AppData data;
  final bool isCreator;
  final String currentUserId;
  final AppL10n l10n;

  const _TotalsPanel({
    required this.kuri,
    required this.payments,
    required this.data,
    required this.isCreator,
    required this.currentUserId,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final approved = payments.where((p) => p.status == 'approved').toList();
    final planTotal = approved.fold<double>(0, (s, p) => s + p.amount);

    if (isCreator) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.paymentSummary,
                style: TextStyle(
                    color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...kuri.participantUserIds.map((uid) {
              final participant = data.users.firstWhere(
                (u) => u.id == uid,
                orElse: () => AppUser(id: uid, name: l10n.unknown, email: ''),
              );
              final userPaid = approved
                  .where((p) => p.userId == uid)
                  .fold<double>(0, (s, p) => s + p.amount);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    AvatarWidget(name: participant.name, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(participant.name,
                            style: TextStyle(color: c.text, fontSize: 13))),
                    Text('₹${userPaid.toInt()}',
                        style: TextStyle(color: c.text, fontSize: 13)),
                  ],
                ),
              );
            }),
            Divider(color: c.border, height: 16),
            Row(
              children: [
                Expanded(
                    child: Text(l10n.totalCollected,
                        style: TextStyle(color: c.text, fontWeight: FontWeight.w600))),
                Text('₹${planTotal.toInt()}',
                    style: TextStyle(
                        color: c.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
    } else {
      final myPaid = approved
          .where((p) => p.userId == currentUserId)
          .fold<double>(0, (s, p) => s + p.amount);
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(l10n.yourPaid, style: TextStyle(color: c.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('₹${myPaid.toInt()}',
                      style: TextStyle(
                          color: c.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: c.border),
            Expanded(
              child: Column(
                children: [
                  Text(l10n.planTotal, style: TextStyle(color: c.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('₹${planTotal.toInt()}',
                      style: TextStyle(
                          color: c.green, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ─── Receipts Screen (full screen, extracted from _ReceiptsTab) ───────────────

class KuriReceiptsScreen extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final String currentUserId;

  const KuriReceiptsScreen({super.key, required this.kuri, required this.currentUserId});

  @override
  ConsumerState<KuriReceiptsScreen> createState() => _KuriReceiptsScreenState();
}

class _KuriReceiptsScreenState extends ConsumerState<KuriReceiptsScreen> {
  final Set<String> _expandedMonths = {};
  String? _reviewingPaymentId;
  final _rejectionNoteCtrl = TextEditingController();
  bool _reviewing = false;
  AppL10n? _l10n;

  @override
  void dispose() {
    _rejectionNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _reviewPayment(String paymentId, bool approved) async {
    setState(() => _reviewing = true);
    try {
      await dataService.reviewPayment(
        paymentId,
        widget.currentUserId,
        approved,
        _rejectionNoteCtrl.text.trim().isEmpty ? null : _rejectionNoteCtrl.text.trim(),
      );
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      setState(() {
        _reviewingPaymentId = null;
        _rejectionNoteCtrl.clear();
      });
      if (mounted) showSuccess(context, approved ? _l10n!.confirmed : _l10n!.rejected);
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    _l10n = l10n;
    final appDataAsync = ref.watch(appDataProvider);

    final data = appDataAsync.valueOrNull;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(l10n.receipts)),
      body: data == null
          ? Center(child: appDataAsync.hasError
              ? Text('${appDataAsync.error}')
              : CircularProgressIndicator(color: c.primary))
          : Builder(builder: (context) {
          final months = generateMonths(widget.kuri.startDate, includeFuture: false);
          final payments = data.payments.where((p) => p.kuriId == widget.kuri.id).toList();

          if (months.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long,
              title: l10n.noMonthsYet,
              subtitle: l10n.paymentsWhenStarts,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: months.reversed.map((month) {
              final monthPayments = payments.where((p) => p.month == month).toList();
              final confirmed = monthPayments.where((p) => p.status == 'approved').length;
              final pending = monthPayments.where((p) => p.status == 'submitted').length;
              final totalParticipants = widget.kuri.participantUserIds.length;
              final isExpanded = _expandedMonths.contains(month);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        if (isExpanded) {
                          _expandedMonths.remove(month);
                        } else {
                          _expandedMonths.add(month);
                        }
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatMonthKey(month),
                                style: TextStyle(
                                    color: c.text, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '$confirmed/$totalParticipants ${l10n.confirmedLower}',
                              style: TextStyle(color: c.green, fontSize: 12),
                            ),
                            if (pending > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.warn.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$pending ${l10n.pendingLower}',
                                  style: TextStyle(color: c.warn, fontSize: 11),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: c.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      Divider(color: c.border, height: 1),
                      ...widget.kuri.participantUserIds.map((uid) {
                        final participant = data.users.firstWhere(
                          (u) => u.id == uid,
                          orElse: () => AppUser(id: uid, name: l10n.unknown, email: ''),
                        );
                        final payment = monthPayments.firstWhere(
                          (p) => p.userId == uid,
                          orElse: () => KuriPayment(
                            id: '',
                            kuriId: '',
                            userId: uid,
                            month: month,
                            transactionId: '',
                            amount: 0,
                            status: '',
                            submittedAt: '',
                          ),
                        );
                        final isReviewing = _reviewingPaymentId == payment.id;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: c.border)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AvatarWidget(name: participant.name, size: 32),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(participant.name,
                                            style: TextStyle(
                                                color: c.text, fontWeight: FontWeight.w500)),
                                        if (payment.id.isNotEmpty)
                                          Text(
                                            'Txn: ${payment.transactionId} · ₹${payment.amount.toInt()}',
                                            style: TextStyle(color: c.textMuted, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  _paymentStatusBadge(c, payment.status),
                                ],
                              ),
                              // Receipt thumbnail — tappable for full view + download
                              if (payment.id.isNotEmpty &&
                                  payment.receiptBase64 != null &&
                                  payment.receiptBase64!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _receiptThumbnail(
                                  context,
                                  payment.receiptBase64!,
                                  filename: 'receipt_${payment.month}.jpg',
                                ),
                              ],
                              // Review button
                              if (payment.id.isNotEmpty &&
                                  payment.status == 'submitted' &&
                                  !isReviewing)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ElevatedButton(
                                    onPressed: () => setState(() {
                                      _reviewingPaymentId = payment.id;
                                      _rejectionNoteCtrl.clear();
                                    }),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    child: Text(l10n.review),
                                  ),
                                ),
                              // Inline review form
                              if (isReviewing) ...[
                                const SizedBox(height: 8),
                                if (payment.receiptBase64 != null &&
                                    payment.receiptBase64!.isNotEmpty) ...[
                                  _receiptThumbnail(
                                    context,
                                    payment.receiptBase64!,
                                    fullWidth: true,
                                    filename: 'receipt_${payment.month}.jpg',
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                TextField(
                                  controller: _rejectionNoteCtrl,
                                  style: TextStyle(color: c.text, fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: l10n.noteForRejection,
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _reviewing
                                            ? null
                                            : () => _reviewPayment(payment.id, true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: c.green),
                                        child: Text(l10n.approve,
                                            style: const TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _reviewing
                                            ? null
                                            : () => _reviewPayment(payment.id, false),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: c.danger),
                                        child: Text(l10n.reject,
                                            style: const TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () =>
                                          setState(() => _reviewingPaymentId = null),
                                      child: Text(l10n.cancel,
                                          style: TextStyle(color: c.textMuted)),
                                    ),
                                  ],
                                ),
                                if (payment.notes != null && payment.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${l10n.note} ${payment.notes}',
                                      style: TextStyle(color: c.textMuted, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        }),
    );
  }

  Widget _paymentStatusBadge(AppColors c, String status) {
    switch (status) {
      case 'approved':
        return StatusBadge(label: _l10n!.confirmed, color: c.green);
      case 'submitted':
        return StatusBadge(label: _l10n!.pendingReview, color: c.warn);
      case 'rejected':
        return StatusBadge(label: _l10n!.rejected, color: c.danger);
      default:
        return StatusBadge(label: _l10n!.notSubmitted, color: c.textDim);
    }
  }

}

// ─── Settings Screen (full screen, extracted from _SettingsTab) ───────────────

class KuriSettingsScreen extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final String currentUserId;

  const KuriSettingsScreen({super.key, required this.kuri, required this.currentUserId});

  @override
  ConsumerState<KuriSettingsScreen> createState() => _KuriSettingsScreenState();
}

class _KuriSettingsScreenState extends ConsumerState<KuriSettingsScreen> {
  late TextEditingController _upiCtrl;
  late TextEditingController _addEmailCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _maxDiscountCtrl;
  late TextEditingController _prizePaidCtrl;
  String? _qrBase64;
  String? _qrFileName;
  bool _saving = false;
  bool _addingParticipant = false;
  AppL10n? _l10n;

  @override
  void initState() {
    super.initState();
    _upiCtrl = TextEditingController(text: widget.kuri.upiId ?? '');
    _addEmailCtrl = TextEditingController();
    _commissionCtrl = TextEditingController(
        text: widget.kuri.moopanCommissionPercent.toStringAsFixed(widget.kuri.moopanCommissionPercent % 1 == 0 ? 0 : 1));
    _maxDiscountCtrl = TextEditingController(
        text: widget.kuri.maxDiscountPercent.toStringAsFixed(widget.kuri.maxDiscountPercent % 1 == 0 ? 0 : 1));
    _prizePaidCtrl = TextEditingController(text: widget.kuri.prizePaidWithinDays.toString());
    _qrBase64 = widget.kuri.upiQrBase64;
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _addEmailCtrl.dispose();
    _commissionCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _prizePaidCtrl.dispose();
    super.dispose();
  }

  Future<void> _addParticipant() async {
    final email = _addEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    setState(() => _addingParticipant = true);
    try {
      final appData = ref.read(appDataProvider).valueOrNull;
      if (appData == null) return;
      final user = appData.users.firstWhere(
        (u) => u.email.trim().toLowerCase() == email,
        orElse: () => AppUser(id: '', name: '', email: ''),
      );
      if (user.id.isEmpty) {
        if (mounted) showError(context, '${_l10n!.noUserFound} $email');
        return;
      }
      final kuri = appData.kuris.firstWhere((k) => k.id == widget.kuri.id, orElse: () => widget.kuri);
      if (kuri.participantUserIds.contains(user.id)) return;
      await dataService.updateKuriParticipants(
        widget.kuri.id,
        widget.currentUserId,
        [...kuri.participantUserIds, user.id],
      );
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) {
        _addEmailCtrl.clear();
        showSuccess(context, _l10n!.participantAdded);
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _addingParticipant = false);
    }
  }

  Future<void> _removeParticipant(String userId) async {
    final appData = ref.read(appDataProvider).valueOrNull;
    if (appData == null) return;
    final kuri = appData.kuris.firstWhere((k) => k.id == widget.kuri.id, orElse: () => widget.kuri);
    if (kuri.createdBy == userId) {
      showError(context, _l10n!.cannotRemoveCreator);
      return;
    }
    try {
      await dataService.updateKuriParticipants(
        widget.kuri.id,
        widget.currentUserId,
        kuri.participantUserIds.where((id) => id != userId).toList(),
      );
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) showSuccess(context, _l10n!.participantRemoved);
    } catch (e) {
      if (mounted) showError(context, '$e');
    }
  }

  Future<void> _pickQrImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final encoded = DataService.encodeImageToBase64(file.bytes!, file.name);
          setState(() {
            _qrBase64 = encoded;
            _qrFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) showError(context, '${_l10n!.failedToPickImage} $e');
    }
  }

  Future<void> _save() async {
    final upiId = _upiCtrl.text.trim();
    if (upiId.isEmpty) {
      showError(context, _l10n!.upiIdRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await Future.wait([
        dataService.updateKuriPaymentInfo(
          widget.kuri.id,
          widget.currentUserId,
          upiId,
          _qrBase64,
        ),
        dataService.updateKuriSettings(
          widget.kuri.id,
          widget.currentUserId,
          moopanCommissionPercent:
              double.tryParse(_commissionCtrl.text.trim()) ?? 5.0,
          maxDiscountPercent:
              double.tryParse(_maxDiscountCtrl.text.trim()) ?? 30.0,
          prizePaidWithinDays:
              int.tryParse(_prizePaidCtrl.text.trim()) ?? 7,
        ),
      ]);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) showSuccess(context, _l10n!.settingsSaved);
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    _l10n = l10n;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(l10n.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(l10n.paymentSettings),
            TextField(
              controller: _upiCtrl,
              style: TextStyle(color: c.text),
              decoration: InputDecoration(
                labelText: '${l10n.upiId} *',
                hintText: 'name@upi',
              ),
            ),
            const SizedBox(height: 12),
            if (_qrBase64 != null && _qrBase64!.isNotEmpty) ...[
              Text(l10n.currentQr, style: TextStyle(color: c.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildQrImage(_qrBase64!),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.border),
              ),
              onPressed: _pickQrImage,
              icon: const Icon(Icons.qr_code),
              label: Text(_qrFileName ??
                  (_qrBase64 != null
                      ? '${l10n.change} ${l10n.paymentQr} ${l10n.optional}'
                      : '${l10n.upload} ${l10n.paymentQr} ${l10n.optional}')),
            ),
            if (_qrBase64 != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _qrBase64 = null;
                  _qrFileName = null;
                }),
                icon: Icon(Icons.delete_outline, color: c.danger),
                label: Text(l10n.removeQr, style: TextStyle(color: c.danger)),
              ),
            ],
            const SizedBox(height: 20),
            // Auction settings
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commissionCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: c.text),
                    decoration: InputDecoration(
                      labelText: l10n.moopanCommissionLabel,
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.kuri.kuriType == 'lelam')
                  Expanded(
                    child: TextField(
                      controller: _maxDiscountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: c.text),
                      decoration: InputDecoration(
                        labelText: l10n.maxDiscountLabel,
                        suffixText: '%',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prizePaidCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: c.text),
              decoration: InputDecoration(
                labelText: l10n.prizePaidWithinLabel,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: c.primaryFg, strokeWidth: 2),
                    )
                  : Text(l10n.saveSettings),
            ),
            const SizedBox(height: 28),
            SectionTitle(l10n.manageParticipants),
            _buildManageParticipants(c, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildManageParticipants(AppColors c, AppL10n l10n) {
    final appData = ref.watch(appDataProvider).valueOrNull;
    if (appData == null) return const SizedBox();
    final kuri = appData.kuris.firstWhere((k) => k.id == widget.kuri.id, orElse: () => widget.kuri);
    final participants = kuri.participantUserIds.map((id) {
      return appData.users.firstWhere(
        (u) => u.id == id,
        orElse: () => AppUser(id: id, name: id, email: ''),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...participants.map((p) {
          final isCreator = p.id == kuri.createdBy;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                AvatarWidget(name: p.name, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: TextStyle(color: c.text, fontWeight: FontWeight.w600, fontSize: 14)),
                      if (p.email.isNotEmpty)
                        Text(p.email, style: TextStyle(color: c.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (isCreator)
                  StatusBadge(label: l10n.creator, color: c.primary)
                else
                  TextButton(
                    onPressed: () => _removeParticipant(p.id),
                    style: TextButton.styleFrom(foregroundColor: c.danger, padding: EdgeInsets.zero),
                    child: Text(l10n.remove, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: TextStyle(color: c.text),
                decoration: InputDecoration(
                  labelText: l10n.enterEmailToAdd,
                  prefixIcon: Icon(Icons.person_add_outlined, color: c.textMuted),
                  isDense: true,
                ),
                onSubmitted: (_) => _addParticipant(),
              ),
            ),
            const SizedBox(width: 8),
            _addingParticipant
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary))
                : IconButton(
                    icon: Icon(Icons.add_circle_outline, color: c.primary),
                    onPressed: _addParticipant,
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildQrImage(String base64Data) {
    try {
      Uint8List bytes;
      if (base64Data.contains(',')) {
        bytes = base64Decode(base64Data.split(',').last);
      } else {
        bytes = base64Decode(base64Data);
      }
      return Image.memory(bytes, height: 150, fit: BoxFit.contain);
    } catch (_) {
      return Icon(Icons.broken_image, color: context.colors.textDim);
    }
  }
}

// ─── Member Payment View ──────────────────────────────────────────────────────

class _MemberPaymentView extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final AppData data;
  final String currentUserId;

  const _MemberPaymentView({
    required this.kuri,
    required this.data,
    required this.currentUserId,
  });

  @override
  ConsumerState<_MemberPaymentView> createState() => _MemberPaymentViewState();
}

class _MemberPaymentViewState extends ConsumerState<_MemberPaymentView> {
  @override
  Widget build(BuildContext context) {
    final appDataAsync = ref.watch(appDataProvider);
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final data = appDataAsync.valueOrNull;
    if (data == null) {
      return Center(child: appDataAsync.hasError
          ? Text('${appDataAsync.error}')
          : CircularProgressIndicator(color: c.primary));
    }
    {
        final kuri = data.kuris.firstWhere(
          (k) => k.id == widget.kuri.id,
          orElse: () => widget.kuri,
        );
        final myPayments = data.payments
            .where((p) => p.kuriId == kuri.id && p.userId == widget.currentUserId)
            .toList();
        final months = generateMonths(kuri.startDate, includeFuture: true);

        // Sequential unlock
        String? payableMonth;
        for (final month in months) {
          final payment = myPayments.firstWhere(
            (p) => p.month == month,
            orElse: () => KuriPayment(
              id: '',
              kuriId: '',
              userId: '',
              month: month,
              transactionId: '',
              amount: 0,
              status: '',
              submittedAt: '',
            ),
          );
          if (payment.id.isEmpty) {
            payableMonth = month;
            break;
          } else if (payment.status == 'rejected') {
            payableMonth = month;
            break;
          }
        }

        // Find open auction for this kuri (Lelam only)
        final openAuction = kuri.kuriType == 'lelam'
            ? data.auctions.where((a) => a.kuriId == kuri.id && a.status == 'open').firstOrNull
            : null;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Auction banner (Lelam Kuri, open auction)
            if (openAuction != null)
              AuctionMemberBanner(
                kuri: kuri,
                auction: openAuction,
                currentUserId: widget.currentUserId,
              ),
            // UPI Banner
            if (kuri.upiId != null && kuri.upiId!.isNotEmpty) _UpiBanner(kuri: kuri, l10n: l10n),
            const SizedBox(height: 8),
            ...months.reversed.map((month) {
              final payment = myPayments.firstWhere(
                (p) => p.month == month,
                orElse: () => KuriPayment(
                  id: '',
                  kuriId: kuri.id,
                  userId: widget.currentUserId,
                  month: month,
                  transactionId: '',
                  amount: 0,
                  status: '',
                  submittedAt: '',
                ),
              );
              final canPay = payableMonth == month;
              final isLocked = payment.id.isEmpty && !canPay;

              return _MonthRow(
                month: month,
                payment: payment,
                canPay: canPay,
                isLocked: isLocked,
                kuri: kuri,
                currentUserId: widget.currentUserId,
                data: data,
              );
            }),
          ],
        );
    }
  }
}

class _UpiBanner extends StatelessWidget {
  final KuriPlan kuri;
  final AppL10n l10n;

  const _UpiBanner({required this.kuri, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.primaryLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.payTo, style: TextStyle(color: c.textMuted, fontSize: 11)),
          Row(
            children: [
              Text(
                kuri.upiId!,
                style: TextStyle(
                    color: c.text, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: Icon(Icons.copy, size: 16, color: c.textMuted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: kuri.upiId!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.upiIdCopied), duration: const Duration(seconds: 1)),
                  );
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                        'upi://pay?pa=${kuri.upiId}&pn=Kuri&am=${kuri.contributionAmount}&cu=INR');
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        if (context.mounted) showError(context, l10n.noUpiApp);
                      }
                    } catch (e) {
                      if (context.mounted) showError(context, 'Could not open UPI app: $e');
                    }
                  },
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text(l10n.payWithUpi),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (kuri.upiQrBase64 != null && kuri.upiQrBase64!.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showQrDialog(context, kuri.upiQrBase64!),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.qr_code, color: c.primary),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showQrDialog(BuildContext context, String base64Data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.qrCode, style: TextStyle(color: ctx.colors.text)),
        content: _buildQrImage(base64Data),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage(String base64Data) {
    try {
      Uint8List bytes;
      if (base64Data.contains(',')) {
        bytes = base64Decode(base64Data.split(',').last);
      } else {
        bytes = base64Decode(base64Data);
      }
      return Image.memory(bytes, height: 200, fit: BoxFit.contain);
    } catch (_) {
      return const Icon(Icons.broken_image, size: 48);
    }
  }
}

class _MonthRow extends ConsumerStatefulWidget {
  final String month;
  final KuriPayment payment;
  final bool canPay;
  final bool isLocked;
  final KuriPlan kuri;
  final String currentUserId;
  final AppData data;

  const _MonthRow({
    required this.month,
    required this.payment,
    required this.canPay,
    required this.isLocked,
    required this.kuri,
    required this.currentUserId,
    required this.data,
  });

  @override
  ConsumerState<_MonthRow> createState() => _MonthRowState();
}

class _MonthRowState extends ConsumerState<_MonthRow> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    return Opacity(
      opacity: widget.isLocked ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMonthKey(widget.month),
                        style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
                      ),
                      if (widget.payment.id.isNotEmpty)
                        Text(
                          'Txn: ${widget.payment.transactionId}',
                          style: TextStyle(color: c.textMuted, fontSize: 11),
                        ),
                      if (widget.payment.notes != null &&
                          widget.payment.notes!.isNotEmpty)
                        Text(
                          widget.payment.notes!,
                          style: TextStyle(color: c.danger, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (widget.isLocked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: c.textDim, size: 14),
                      const SizedBox(width: 4),
                      Text(l10n.locked, style: TextStyle(color: c.textDim, fontSize: 12)),
                    ],
                  )
                else if (widget.payment.id.isEmpty ||
                    widget.payment.status == 'rejected')
                  ..._buildPayButton(context, l10n)
                else
                  _paymentStatusBadge(c, widget.payment.status, l10n),
              ],
            ),
            // Receipt thumbnail — visible to the submitter
            if (widget.payment.id.isNotEmpty &&
                widget.payment.receiptBase64 != null &&
                widget.payment.receiptBase64!.isNotEmpty &&
                (widget.payment.status == 'submitted' ||
                    widget.payment.status == 'approved')) ...[
              const SizedBox(height: 8),
              _receiptThumbnail(
                context,
                widget.payment.receiptBase64!,
                filename: 'receipt_${widget.payment.month}.jpg',
              ),
            ],
            // Winner chip for auction months
            Builder(builder: (_) {
              final closedAuction = widget.data.auctions.where((a) =>
                  a.kuriId == widget.kuri.id &&
                  a.month == widget.month &&
                  a.status == 'closed').firstOrNull;
              if (closedAuction == null) return const SizedBox.shrink();
              return MonthWinnerChip(auction: closedAuction, data: widget.data);
            }),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPayButton(BuildContext context, AppL10n l10n) {
    if (!widget.canPay) return [const SizedBox()];
    return [
      ElevatedButton(
        onPressed: () => _showPaySheet(context),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(l10n.pay),
      ),
    ];
  }

  void _showPaySheet(BuildContext context) {
    showAppBottomSheet(
      context,
      _PaymentSheet(
        kuri: widget.kuri,
        month: widget.month,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  Widget _paymentStatusBadge(AppColors c, String status, AppL10n l10n) {
    switch (status) {
      case 'approved':
        return StatusBadge(label: l10n.confirmed, color: c.green);
      case 'submitted':
        return StatusBadge(label: l10n.pendingReview, color: c.warn);
      case 'rejected':
        return StatusBadge(label: l10n.rejected, color: c.danger);
      default:
        return StatusBadge(label: l10n.notSubmitted, color: c.textDim);
    }
  }
}

// ─── Payment Sheet (for member to submit payment) ────────────────────────────

class _PaymentSheet extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final String month;
  final String currentUserId;

  const _PaymentSheet({
    required this.kuri,
    required this.month,
    required this.currentUserId,
  });

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _txnCtrl = TextEditingController();
  String? _receiptBase64;
  String? _receiptFileName;
  bool _loading = false;
  AppL10n? _l10n;

  @override
  void dispose() {
    _txnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final encoded = DataService.encodeImageToBase64(file.bytes!, file.name);
          setState(() {
            _receiptBase64 = encoded;
            _receiptFileName = file.name;
          });
        }
      }
    } catch (e) {
      if (mounted) showError(context, '${_l10n!.failedToPickFile} $e');
    }
  }

  Future<void> _submit() async {
    final txnId = _txnCtrl.text.trim();
    if (_receiptBase64 == null) {
      showError(context, _l10n!.receiptRequired);
      return;
    }

    setState(() => _loading = true);
    try {
      await dataService.submitPayment(
        kuriId: widget.kuri.id,
        userId: widget.currentUserId,
        month: widget.month,
        transactionId: txnId,
        amount: widget.kuri.contributionAmount,
        receiptBase64: _receiptBase64!,
        receiptFileName: _receiptFileName ?? 'receipt.jpg',
      );
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, _l10n!.paymentSubmitted);
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    _l10n = l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${l10n.submitPayment} — ${formatMonthKey(widget.month)}',
                style: TextStyle(
                    color: c.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: c.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Text(l10n.amount, style: TextStyle(color: c.textMuted, fontSize: 13)),
                const SizedBox(width: 8),
                Text(
                  '₹${widget.kuri.contributionAmount.toInt()}',
                  style: TextStyle(
                      color: c.primary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _txnCtrl,
            style: TextStyle(color: c.text),
            decoration: InputDecoration(
              labelText: l10n.transactionId,
              hintText: l10n.upiReference,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _receiptBase64 != null ? c.green : c.primary,
              side: BorderSide(color: _receiptBase64 != null ? c.green : c.border),
            ),
            onPressed: _pickReceipt,
            icon: Icon(_receiptBase64 != null ? Icons.check_circle : Icons.upload_file),
            label: Text(_receiptFileName ?? l10n.uploadReceipt),
          ),
          if (_receiptBase64 != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.image, color: c.green, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _receiptFileName ?? l10n.receiptUploaded,
                    style: TextStyle(color: c.green, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: c.textDim, size: 16),
                  onPressed: () => setState(() {
                    _receiptBase64 = null;
                    _receiptFileName = null;
                  }),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: c.primaryFg, strokeWidth: 2),
                  )
                : Text(l10n.submitPayment),
          ),
        ],
      ),
    );
  }
}

// ─── Draw Winner Sheet (Changatha Kuri) ───────────────────────────────────────

class _DrawWinnerSheet extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final AppData data;
  final String currentUserId;

  const _DrawWinnerSheet({
    required this.kuri,
    required this.data,
    required this.currentUserId,
  });

  @override
  ConsumerState<_DrawWinnerSheet> createState() => _DrawWinnerSheetState();
}

class _DrawWinnerSheetState extends ConsumerState<_DrawWinnerSheet> {
  String? _selectedMonth;
  String? _selectedWinnerId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final data = ref.watch(appDataProvider).valueOrNull ?? widget.data;

    final elapsedMonths = generateMonths(widget.kuri.startDate, includeFuture: false);
    final closedMonths = data.auctions
        .where((a) => a.kuriId == widget.kuri.id && a.status == 'closed')
        .map((a) => a.month)
        .toSet();
    final availableMonths = elapsedMonths.where((m) => !closedMonths.contains(m)).toList();

    final wonUserIds = data.auctions
        .where((a) => a.kuriId == widget.kuri.id && a.status == 'closed' && a.winnerId != null)
        .map((a) => a.winnerId!)
        .toSet();
    final eligibleParticipants = widget.kuri.participantUserIds
        .where((id) => !wonUserIds.contains(id))
        .map((id) => data.users.firstWhere(
              (u) => u.id == id,
              orElse: () => AppUser(id: id, name: id, email: ''),
            ))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.drawWinner,
                style: TextStyle(
                    color: c.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: c.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (availableMonths.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'All months already have winners.',
                style: TextStyle(color: c.textMuted),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              value: _selectedMonth,
              decoration: InputDecoration(labelText: 'Month'),
              dropdownColor: c.surface,
              style: TextStyle(color: c.text),
              items: availableMonths
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(formatMonthKey(m)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonth = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedWinnerId,
              decoration: InputDecoration(labelText: l10n.selectWinner),
              dropdownColor: c.surface,
              style: TextStyle(color: c.text),
              items: eligibleParticipants
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedWinnerId = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_loading ||
                      _selectedMonth == null ||
                      _selectedWinnerId == null)
                  ? null
                  : _declare,
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: c.primaryFg, strokeWidth: 2),
                    )
                  : Text(l10n.drawWinner),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _declare() async {
    if (_selectedMonth == null || _selectedWinnerId == null) return;
    final l10n = AppL10n(ref.read(localeProvider));
    setState(() => _loading = true);
    try {
      await dataService.declareChangathaWinner(
        widget.kuri.id,
        _selectedMonth!,
        widget.currentUserId,
        _selectedWinnerId!,
      );
      final fresh = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(fresh);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, '${l10n.winner} ${l10n.drawWinner}!');
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
