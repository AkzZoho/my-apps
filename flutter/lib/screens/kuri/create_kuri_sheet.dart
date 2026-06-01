import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../providers/providers.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';

class CreateKuriSheet extends ConsumerStatefulWidget {
  const CreateKuriSheet({super.key});

  @override
  ConsumerState<CreateKuriSheet> createState() => _CreateKuriSheetState();
}

class _CreateKuriSheetState extends ConsumerState<CreateKuriSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _participantEmailCtrl = TextEditingController();

  DateTime _startDate = DateTime.now();
  List<AppUser> _selectedParticipants = [];
  String? _qrBase64;
  String? _qrFileName;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _upiCtrl.dispose();
    _participantEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: primaryColor,
            onPrimary: primaryFg,
            surface: surfaceColor,
          ),
          dialogBackgroundColor: surfaceColor,
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
      if (mounted) showError(context, 'Failed to pick image: $e');
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
      showError(context, 'No user found with email: $email');
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

    if (name.isEmpty) { showError(context, 'Name is required.'); return; }
    if (amountStr.isEmpty) { showError(context, 'Amount is required.'); return; }
    if (upiId.isEmpty) { showError(context, 'UPI ID is required.'); return; }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      showError(context, 'Enter a valid amount.');
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
        showSuccess(context, 'Kuri created!');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appDataAsync = ref.watch(appDataProvider);
    final currentUser = ref.watch(currentUserProvider);

    return appDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Create Kuri',
                      style: TextStyle(
                          color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close, color: textMuted),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: textColor),
                decoration: const InputDecoration(labelText: 'Kuri Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: textColor),
                decoration: const InputDecoration(
                  labelText: 'Monthly Amount (₹) *',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(color: textMuted),
                ),
              ),
              const SizedBox(height: 12),
              // Start date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: textMuted, size: 18),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Date', style: TextStyle(color: textMuted, fontSize: 12)),
                          Text(
                            formatDate(_startDate.toIso8601String()),
                            style: const TextStyle(color: textColor),
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
                style: const TextStyle(color: textColor),
                decoration: const InputDecoration(
                  labelText: 'UPI ID *',
                  hintText: 'name@upi',
                ),
              ),
              const SizedBox(height: 12),
              // QR code upload
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _qrBase64 != null ? greenColor : primaryColor,
                        side: BorderSide(color: _qrBase64 != null ? greenColor : borderColor),
                      ),
                      onPressed: _pickQrImage,
                      icon: Icon(_qrBase64 != null ? Icons.check_circle : Icons.qr_code),
                      label: Text(_qrFileName ?? 'Upload QR Code (optional)'),
                    ),
                  ),
                  if (_qrBase64 != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: dangerColor),
                      onPressed: () => setState(() { _qrBase64 = null; _qrFileName = null; }),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Participants
              const SectionTitle('PARTICIPANTS'),
              // Creator is always included
              if (currentUser != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(name: currentUser.name, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${currentUser.name} (you)',
                          style: const TextStyle(color: textColor, fontSize: 13),
                        ),
                      ),
                      const StatusBadge(label: 'Creator', color: primaryColor),
                    ],
                  ),
                ),
              // Selected participants
              ..._selectedParticipants.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        AvatarWidget(name: p.name, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(color: textColor, fontSize: 13)),
                              Text(p.email, style: const TextStyle(color: textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: textMuted, size: 16),
                          onPressed: () => setState(() => _selectedParticipants.remove(p)),
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
                      style: const TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        labelText: 'Add participant by email',
                        hintText: 'user@example.com',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addParticipantByEmail(data),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _addParticipantByEmail(data),
                    icon: const Icon(Icons.add_circle, color: primaryColor),
                  ),
                ],
              ),
              // Users list to pick from
              const SizedBox(height: 8),
              ...data.users
                  .where((u) =>
                      u.id != currentUser?.id &&
                      !_selectedParticipants.any((p) => p.id == u.id))
                  .take(5)
                  .map((u) => InkWell(
                        onTap: () => setState(() => _selectedParticipants.add(u)),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              AvatarWidget(name: u.name, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${u.name} (${u.email})',
                                  style: const TextStyle(color: textMuted, fontSize: 12),
                                ),
                              ),
                              const Icon(Icons.add, color: primaryColor, size: 16),
                            ],
                          ),
                        ),
                      )),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: primaryFg, strokeWidth: 2),
                      )
                    : const Text('Create Kuri'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
