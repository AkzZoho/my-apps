import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../widgets/common.dart';

class CreateKuriScreen extends ConsumerStatefulWidget {
  const CreateKuriScreen({super.key});

  @override
  ConsumerState<CreateKuriScreen> createState() => _CreateKuriScreenState();
}

class _CreateKuriScreenState extends ConsumerState<CreateKuriScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _participantEmailCtrl = TextEditingController();

  DateTime _startDate = DateTime.now();
  final List<AppUser> _selectedParticipants = [];
  String? _qrBase64;
  String? _qrFileName;
  bool _loading = false;
  AppL10n? _l10n;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _upiCtrl.dispose();
    _participantEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final c = context.colors;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: c.primary,
            onPrimary: c.primaryFg,
            surface: c.surface,
          ),
          dialogBackgroundColor: c.surface,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickQrImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
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

  void _addParticipantByEmail(AppData data) {
    final email = _participantEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    final user = data.users.firstWhere(
      (u) => u.email == email,
      orElse: () => AppUser(id: '', name: '', email: ''),
    );
    if (user.id.isEmpty) {
      showError(context, '${_l10n!.noUserFound} $email');
      return;
    }
    if (!_selectedParticipants.any((p) => p.id == user.id)) {
      setState(() => _selectedParticipants.add(user));
    }
    _participantEmailCtrl.clear();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    final upiId = _upiCtrl.text.trim();

    if (name.isEmpty) {
      showError(context, _l10n!.nameIsRequired);
      return;
    }
    if (amountStr.isEmpty) {
      showError(context, _l10n!.amountRequired);
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      showError(context, _l10n!.validAmount);
      return;
    }

    if (upiId.isEmpty) {
      showError(context, _l10n!.upiIdRequired);
      return;
    }

    setState(() => _loading = true);
    try {
      final participantIds = _selectedParticipants.map((p) => p.id).toList();
      if (!participantIds.contains(user.id)) participantIds.add(user.id);

      await dataService.createKuri(
        name: name,
        amount: amount,
        currency: 'INR',
        startDate: _startDate.toIso8601String().split('T').first,
        participantIds: participantIds,
        upiId: upiId,
        qrBase64: _qrBase64,
        createdBy: user.id,
      );
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, _l10n!.kuriCreated);
      }
    } catch (e) {
      if (mounted) showError(context, '${_l10n!.error}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    _l10n = l10n;
    final appDataAsync = ref.watch(appDataProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text(l10n.createKuri)),
      body: appDataAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.primary)),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: c.danger))),
        data: (data) => LoadingOverlay(
          loading: _loading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(labelText: '${l10n.planName} *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(
                    labelText: '${l10n.monthlyAmount} (₹) *',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: c.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                // Start date picker
                GestureDetector(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: c.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${l10n.startDate} *',
                                style: TextStyle(color: c.textMuted, fontSize: 12)),
                            Text(
                              formatDate(_startDate.toIso8601String()),
                              style: TextStyle(color: c.text),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _upiCtrl,
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(
                    labelText: '${l10n.upiId} *',
                    hintText: 'name@upi',
                  ),
                ),
                const SizedBox(height: 12),
                // QR code upload
                Text('${l10n.paymentQr} ${l10n.optional}',
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _qrBase64 != null ? c.green : c.primary,
                          side: BorderSide(color: _qrBase64 != null ? c.green : c.border),
                        ),
                        onPressed: _pickQrImage,
                        icon: Icon(_qrBase64 != null ? Icons.check_circle : Icons.qr_code),
                        label: Text(_qrFileName ?? l10n.uploadQrCode),
                      ),
                    ),
                    if (_qrBase64 != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, color: c.danger),
                        onPressed: () => setState(() {
                          _qrBase64 = null;
                          _qrFileName = null;
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Participants
                SectionTitle('${l10n.participants.toUpperCase()} *'),
                if (currentUser != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.primaryLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        AvatarWidget(name: currentUser.name, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${currentUser.name} ${l10n.you}',
                            style: TextStyle(color: c.text, fontSize: 13),
                          ),
                        ),
                        StatusBadge(label: l10n.creator, color: c.primary),
                      ],
                    ),
                  ),
                ..._selectedParticipants.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(8),
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
                                Text(p.name,
                                    style: TextStyle(color: c.text, fontSize: 13)),
                                Text(p.email,
                                    style: TextStyle(color: c.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: c.textMuted, size: 16),
                            onPressed: () =>
                                setState(() => _selectedParticipants.remove(p)),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                    )),
                // Add participant by email
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _participantEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: c.text),
                        decoration: InputDecoration(
                          labelText: l10n.addParticipant,
                          hintText: 'user@example.com',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addParticipantByEmail(data),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _addParticipantByEmail(data),
                      icon: Icon(Icons.add_circle, color: c.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick-pick: only users from the creator's existing Kuris
                ...() {
                  final myKuriParticipantIds = data.kuris
                      .where((k) =>
                          k.createdBy == currentUser?.id ||
                          k.participantUserIds.contains(currentUser?.id))
                      .expand((k) => k.participantUserIds)
                      .toSet()
                    ..remove(currentUser?.id);

                  return data.users
                      .where((u) =>
                          myKuriParticipantIds.contains(u.id) &&
                          !_selectedParticipants.any((p) => p.id == u.id))
                      .take(5)
                      .map((u) => InkWell(
                            onTap: () =>
                                setState(() => _selectedParticipants.add(u)),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Row(
                                children: [
                                  AvatarWidget(name: u.name, size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${u.name} (${u.email})',
                                      style: TextStyle(
                                          color: c.textMuted, fontSize: 12),
                                    ),
                                  ),
                                  Icon(Icons.add, color: c.primary, size: 16),
                                ],
                              ),
                            ),
                          ));
                }(),
                const SizedBox(height: 16),
                // Required fields note
                Text(l10n.requiredFields,
                    style: TextStyle(color: c.textDim, fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: c.primaryFg, strokeWidth: 2),
                        )
                      : Text(l10n.createKuri),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
