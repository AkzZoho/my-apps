import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../providers/providers.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

class KuriDetailScreen extends ConsumerStatefulWidget {
  final String kuriId;

  const KuriDetailScreen({super.key, required this.kuriId});

  @override
  ConsumerState<KuriDetailScreen> createState() => _KuriDetailScreenState();
}

class _KuriDetailScreenState extends ConsumerState<KuriDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _loading = false;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _deleteKuri(KuriPlan kuri) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete Kuri',
      message: 'Are you sure you want to delete "${kuri.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    try {
      await dataService.deleteKuri(kuri.id, user.id);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Kuri deleted.');
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator(color: primaryColor)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('$e', style: const TextStyle(color: dangerColor))),
      ),
      data: (data) {
        final kuri = data.kuris.firstWhere(
          (k) => k.id == widget.kuriId,
          orElse: () => KuriPlan(
            id: '',
            name: 'Not found',
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
            backgroundColor: bgColor,
            appBar: AppBar(title: const Text('Kuri')),
            body: const Center(
                child: Text('Kuri not found', style: TextStyle(color: textMuted))),
          );
        }

        final isCreator = user?.id == kuri.createdBy;
        final kuriPayments = data.payments.where((p) => p.kuriId == kuri.id).toList();
        final approvedPayments = kuriPayments.where((p) => p.status == 'approved').toList();
        final totalCollected = approvedPayments.fold<double>(0, (s, p) => s + p.amount);

        if (isCreator) {
          _tabController ??= TabController(length: 2, vsync: this);
        }

        return LoadingOverlay(
          loading: _loading,
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              title: Text(kuri.name),
              actions: [
                if (isCreator)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: dangerColor),
                    onPressed: () => _deleteKuri(kuri),
                    tooltip: 'Delete Kuri',
                  ),
              ],
            ),
            body: Column(
              children: [
                // Header card
                _KuriHeader(kuri: kuri, totalCollected: totalCollected),
                // Totals panel
                _TotalsPanel(
                  kuri: kuri,
                  payments: kuriPayments,
                  data: data,
                  isCreator: isCreator,
                  currentUserId: user?.id ?? '',
                ),
                // Tab bar for creator
                if (isCreator && _tabController != null) ...[
                  Container(
                    color: surfaceColor,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Receipts'),
                        Tab(text: 'Settings'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _ReceiptsTab(kuri: kuri, data: data, currentUserId: user?.id ?? ''),
                        _SettingsTab(kuri: kuri, currentUserId: user?.id ?? ''),
                      ],
                    ),
                  ),
                ] else if (!isCreator)
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
      },
    );
  }
}

// ─── Kuri Header ─────────────────────────────────────────────────────────────

class _KuriHeader extends StatelessWidget {
  final KuriPlan kuri;
  final double totalCollected;

  const _KuriHeader({required this.kuri, required this.totalCollected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: surfaceColor,
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
                      style: const TextStyle(
                          color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${kuri.participantUserIds.length} participants',
                      style: const TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Started ${formatDate(kuri.startDate)}',
                  style: const TextStyle(color: textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total Collected', style: TextStyle(color: textMuted, fontSize: 11)),
              Text(
                '₹${totalCollected.toInt()}',
                style: const TextStyle(color: greenColor, fontSize: 18, fontWeight: FontWeight.bold),
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

  const _TotalsPanel({
    required this.kuri,
    required this.payments,
    required this.data,
    required this.isCreator,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final approved = payments.where((p) => p.status == 'approved').toList();
    final planTotal = approved.fold<double>(0, (s, p) => s + p.amount);

    if (isCreator) {
      // Show per-participant breakdown
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Payment Summary',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...kuri.participantUserIds.map((uid) {
              final participant = data.users.firstWhere(
                (u) => u.id == uid,
                orElse: () => AppUser(id: uid, name: 'Unknown', email: ''),
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
                            style: const TextStyle(color: textColor, fontSize: 13))),
                    Text('₹${userPaid.toInt()}',
                        style: const TextStyle(color: textColor, fontSize: 13)),
                  ],
                ),
              );
            }),
            const Divider(color: borderColor, height: 16),
            Row(
              children: [
                const Expanded(
                    child: Text('Total Collected',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600))),
                Text('₹${planTotal.toInt()}',
                    style: const TextStyle(color: greenColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
    } else {
      // Member view: show only own total and plan total
      final myPaid = approved
          .where((p) => p.userId == currentUserId)
          .fold<double>(0, (s, p) => s + p.amount);
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text('Your Paid', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('₹${myPaid.toInt()}',
                      style: const TextStyle(
                          color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(width: 1, height: 40, color: borderColor),
            Expanded(
              child: Column(
                children: [
                  const Text('Plan Total', style: TextStyle(color: textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('₹${planTotal.toInt()}',
                      style: const TextStyle(
                          color: greenColor, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

// ─── Receipts Tab (creator) ───────────────────────────────────────────────────

class _ReceiptsTab extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final AppData data;
  final String currentUserId;

  const _ReceiptsTab({required this.kuri, required this.data, required this.currentUserId});

  @override
  ConsumerState<_ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends ConsumerState<_ReceiptsTab> {
  final Set<String> _expandedMonths = {};
  String? _reviewingPaymentId;
  final _rejectionNoteCtrl = TextEditingController();
  bool _reviewing = false;

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
      if (mounted) showSuccess(context, approved ? 'Payment approved!' : 'Payment rejected.');
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appDataAsync = ref.watch(appDataProvider);
    return appDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) {
        final months = generateMonths(widget.kuri.startDate, includeFuture: false);
        final payments = data.payments.where((p) => p.kuriId == widget.kuri.id).toList();

        if (months.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long,
            title: 'No months yet',
            subtitle: 'Payments will appear here once the plan starts',
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
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
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
                              style: const TextStyle(
                                  color: textColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '$confirmed/$totalParticipants confirmed',
                            style: const TextStyle(color: greenColor, fontSize: 12),
                          ),
                          if (pending > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: warnColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$pending pending',
                                style: const TextStyle(color: warnColor, fontSize: 11),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(color: borderColor, height: 1),
                    ...widget.kuri.participantUserIds.map((uid) {
                      final participant = data.users.firstWhere(
                        (u) => u.id == uid,
                        orElse: () => AppUser(id: uid, name: 'Unknown', email: ''),
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
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: borderColor)),
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
                                          style: const TextStyle(
                                              color: textColor, fontWeight: FontWeight.w500)),
                                      if (payment.id.isNotEmpty)
                                        Text(
                                          'Txn: ${payment.transactionId} · ₹${payment.amount.toInt()}',
                                          style: const TextStyle(color: textMuted, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                _paymentStatusBadge(payment.status),
                              ],
                            ),
                            // Receipt thumbnail (approved with receipt)
                            if (payment.id.isNotEmpty &&
                                payment.status == 'approved' &&
                                payment.receiptBase64 != null &&
                                payment.receiptBase64!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: _buildReceiptImage(payment.receiptBase64!),
                              ),
                            ],
                            // Review button
                            if (payment.id.isNotEmpty && payment.status == 'submitted' && !isReviewing)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: ElevatedButton(
                                  onPressed: () => setState(() {
                                    _reviewingPaymentId = payment.id;
                                    _rejectionNoteCtrl.clear();
                                  }),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  child: const Text('Review'),
                                ),
                              ),
                            // Inline review form
                            if (isReviewing) ...[
                              const SizedBox(height: 8),
                              if (payment.receiptBase64 != null && payment.receiptBase64!.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: _buildReceiptImage(payment.receiptBase64!, fullWidth: true),
                                ),
                                const SizedBox(height: 8),
                              ],
                              TextField(
                                controller: _rejectionNoteCtrl,
                                style: const TextStyle(color: textColor, fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Note (for rejection)',
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _reviewing ? null : () => _reviewPayment(payment.id, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: greenColor),
                                      child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _reviewing ? null : () => _reviewPayment(payment.id, false),
                                      style: ElevatedButton.styleFrom(backgroundColor: dangerColor),
                                      child: const Text('Reject', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => setState(() => _reviewingPaymentId = null),
                                    child: const Text('Cancel', style: TextStyle(color: textMuted)),
                                  ),
                                ],
                              ),
                              if (payment.notes != null && payment.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Note: ${payment.notes}',
                                    style: const TextStyle(color: textMuted, fontSize: 11),
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
      },
    );
  }

  Widget _paymentStatusBadge(String status) {
    switch (status) {
      case 'approved':
        return const StatusBadge(label: 'Confirmed', color: greenColor);
      case 'submitted':
        return const StatusBadge(label: 'Pending review', color: warnColor);
      case 'rejected':
        return const StatusBadge(label: 'Rejected', color: dangerColor);
      default:
        return const StatusBadge(label: 'Not submitted', color: textDim);
    }
  }

  Widget _buildReceiptImage(String base64Data, {bool fullWidth = false}) {
    try {
      Uint8List bytes;
      if (base64Data.contains(',')) {
        bytes = base64Decode(base64Data.split(',').last);
      } else {
        bytes = base64Decode(base64Data);
      }
      return Image.memory(
        bytes,
        width: fullWidth ? double.infinity : 80,
        height: fullWidth ? null : 60,
        fit: fullWidth ? BoxFit.contain : BoxFit.cover,
      );
    } catch (_) {
      return const Icon(Icons.broken_image, color: textDim);
    }
  }
}

// ─── Settings Tab (creator) ───────────────────────────────────────────────────

class _SettingsTab extends ConsumerStatefulWidget {
  final KuriPlan kuri;
  final String currentUserId;

  const _SettingsTab({required this.kuri, required this.currentUserId});

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late TextEditingController _upiCtrl;
  String? _qrBase64;
  String? _qrFileName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _upiCtrl = TextEditingController(text: widget.kuri.upiId ?? '');
    _qrBase64 = widget.kuri.upiQrBase64;
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
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
      if (mounted) showError(context, 'Failed to pick image: $e');
    }
  }

  Future<void> _save() async {
    final upiId = _upiCtrl.text.trim();
    if (upiId.isEmpty) {
      showError(context, 'UPI ID is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await dataService.updateKuriPaymentInfo(
        widget.kuri.id,
        widget.currentUserId,
        upiId,
        _qrBase64,
      );
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) showSuccess(context, 'Settings saved!');
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('PAYMENT SETTINGS'),
          TextField(
            controller: _upiCtrl,
            style: const TextStyle(color: textColor),
            decoration: const InputDecoration(
              labelText: 'UPI ID *',
              hintText: 'name@upi',
            ),
          ),
          const SizedBox(height: 12),
          // Current QR if any
          if (_qrBase64 != null && _qrBase64!.isNotEmpty) ...[
            const Text('Current QR Code:', style: TextStyle(color: textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildQrImage(_qrBase64!),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: borderColor),
            ),
            onPressed: _pickQrImage,
            icon: const Icon(Icons.qr_code),
            label: Text(_qrFileName ?? (_qrBase64 != null ? 'Change QR Code' : 'Upload QR Code')),
          ),
          if (_qrBase64 != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _qrBase64 = null;
                _qrFileName = null;
              }),
              icon: const Icon(Icons.delete_outline, color: dangerColor),
              label: const Text('Remove QR Code', style: TextStyle(color: dangerColor)),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: primaryFg, strokeWidth: 2),
                  )
                : const Text('Save Settings'),
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
      return Image.memory(bytes, height: 150, fit: BoxFit.contain);
    } catch (_) {
      return const Icon(Icons.broken_image, color: textDim);
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
    return appDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) {
        final kuri = data.kuris.firstWhere(
          (k) => k.id == widget.kuri.id,
          orElse: () => widget.kuri,
        );
        final myPayments = data.payments
            .where((p) => p.kuriId == kuri.id && p.userId == widget.currentUserId)
            .toList();
        final months = generateMonths(kuri.startDate, includeFuture: true);

        // Sequential unlock: can only pay current month after prev is submitted/approved
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

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // UPI Banner
            if (kuri.upiId != null && kuri.upiId!.isNotEmpty)
              _UpiBanner(kuri: kuri),
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
              );
            }),
          ],
        );
      },
    );
  }
}

class _UpiBanner extends StatelessWidget {
  final KuriPlan kuri;

  const _UpiBanner({required this.kuri});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pay To', style: TextStyle(color: textMuted, fontSize: 11)),
          Row(
            children: [
              Text(
                kuri.upiId!,
                style: const TextStyle(
                    color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              CopyButton(kuri.upiId!),
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
                        if (context.mounted) showError(context, 'No UPI app found.');
                      }
                    } catch (e) {
                      if (context.mounted) showError(context, 'Could not open UPI app: $e');
                    }
                  },
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Pay with UPI App'),
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
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: const Icon(Icons.qr_code, color: primaryColor),
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
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('QR Code', style: TextStyle(color: textColor)),
        content: _buildQrImage(base64Data),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
      return const Icon(Icons.broken_image, color: textDim, size: 48);
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

  const _MonthRow({
    required this.month,
    required this.payment,
    required this.canPay,
    required this.isLocked,
    required this.kuri,
    required this.currentUserId,
  });

  @override
  ConsumerState<_MonthRow> createState() => _MonthRowState();
}

class _MonthRowState extends ConsumerState<_MonthRow> {
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.isLocked ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMonthKey(widget.month),
                    style: const TextStyle(color: textColor, fontWeight: FontWeight.w500),
                  ),
                  if (widget.payment.id.isNotEmpty)
                    Text(
                      'Txn: ${widget.payment.transactionId}',
                      style: const TextStyle(color: textMuted, fontSize: 11),
                    ),
                  if (widget.payment.notes != null && widget.payment.notes!.isNotEmpty)
                    Text(
                      widget.payment.notes!,
                      style: const TextStyle(color: dangerColor, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (widget.isLocked)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, color: textDim, size: 14),
                  SizedBox(width: 4),
                  Text('Locked', style: TextStyle(color: textDim, fontSize: 12)),
                ],
              )
            else if (widget.payment.id.isEmpty || widget.payment.status == 'rejected')
              ..._buildPayButton(context)
            else
              _paymentStatusBadge(widget.payment.status),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPayButton(BuildContext context) {
    if (!widget.canPay) return [const SizedBox()];
    return [
      ElevatedButton(
        onPressed: () => _showPaySheet(context),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: const Text('Pay'),
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

  Widget _paymentStatusBadge(String status) {
    switch (status) {
      case 'approved':
        return const StatusBadge(label: 'Confirmed', color: greenColor);
      case 'submitted':
        return const StatusBadge(label: 'Pending review', color: warnColor);
      case 'rejected':
        return const StatusBadge(label: 'Rejected', color: dangerColor);
      default:
        return const StatusBadge(label: 'Not submitted', color: textDim);
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
      if (mounted) showError(context, 'Failed to pick file: $e');
    }
  }

  Future<void> _submit() async {
    final txnId = _txnCtrl.text.trim();
    if (txnId.isEmpty) { showError(context, 'Transaction ID is required.'); return; }
    if (_receiptBase64 == null) { showError(context, 'Receipt image is required.'); return; }

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
        showSuccess(context, 'Payment submitted for review!');
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Submit Payment — ${formatMonthKey(widget.month)}',
                style: const TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Text('Amount:', style: TextStyle(color: textMuted, fontSize: 13)),
                const SizedBox(width: 8),
                Text(
                  '₹${widget.kuri.contributionAmount.toInt()}',
                  style: const TextStyle(
                      color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _txnCtrl,
            style: const TextStyle(color: textColor),
            decoration: const InputDecoration(
              labelText: 'Transaction ID *',
              hintText: 'UPI transaction reference',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _receiptBase64 != null ? greenColor : primaryColor,
              side: BorderSide(color: _receiptBase64 != null ? greenColor : borderColor),
            ),
            onPressed: _pickReceipt,
            icon: Icon(_receiptBase64 != null ? Icons.check_circle : Icons.upload_file),
            label: Text(_receiptFileName ?? 'Upload Receipt *'),
          ),
          if (_receiptBase64 != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.image, color: greenColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _receiptFileName ?? 'Receipt uploaded',
                    style: const TextStyle(color: greenColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: textDim, size: 16),
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: primaryFg, strokeWidth: 2),
                  )
                : const Text('Submit Payment'),
          ),
        ],
      ),
    );
  }
}
