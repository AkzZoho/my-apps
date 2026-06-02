import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../widgets/common.dart';
import 'committee_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    final notifier = ref.read(appDataProvider.notifier);
    await notifier.load();
    final data = ref.read(appDataProvider).valueOrNull;
    if (data != null) {
      await ref.read(currentUserProvider.notifier).loadFromPrefs(data);
    }
    await ref.read(lastSeenProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);
    final lastSeen = ref.watch(lastSeenProvider);

    return appDataAsync.when(
      loading: () => const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: bgColor,
        body: Center(child: Text('Error: $e', style: const TextStyle(color: dangerColor))),
      ),
      data: (data) {
        if (user == null) return const Scaffold(backgroundColor: bgColor, body: SizedBox());

        final myGroups = data.groups
            .where((g) => g.members.any((m) => m.userId == user.id))
            .toList();

        // Total unread notifications
        final unreadNotifs = data.notifications
            .where((n) => n.userId == user.id && !n.read)
            .length;

        // Pending invitations for user
        final pendingInvitations = data.invitations
            .where((inv) =>
                inv.inviteeEmail == user.email &&
                inv.status == 'pending' &&
                !myGroups.any((g) => g.id == inv.groupId))
            .toList();

        final activeIdx = ref.watch(activeCommitteeIndexProvider);
        final safeIdx = myGroups.isEmpty ? 0 : (activeIdx < myGroups.length ? activeIdx : 0);

        final locale = ref.watch(localeProvider);
        final l10n = AppL10n(locale);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(l10n.appName),
            actions: [
              // Language toggle: EN / മ
              TextButton(
                onPressed: () => ref.read(localeProvider.notifier).toggle(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  locale == AppLocale.english ? 'EN' : 'മ',
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(ref.watch(themeModeProvider) == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                tooltip: 'Toggle theme',
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => _showNotificationsSheet(context, data, user),
                  ),
                  if (unreadNotifs > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: dangerColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadNotifs',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => ref.read(currentUserProvider.notifier).logout(),
                tooltip: 'Sign out',
              ),
            ],
          ),
          body: myGroups.isEmpty
              ? _NoCommitteesView(
                  user: user,
                  data: data,
                  pendingInvitations: pendingInvitations,
                )
              : _CommitteeBody(
                  myGroups: myGroups,
                  activeIdx: safeIdx,
                  data: data,
                  user: user,
                  lastSeen: lastSeen,
                  pendingInvitations: pendingInvitations,
                ),
          floatingActionButton: myGroups.isNotEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'join',
                      onPressed: () => _showJoinSheet(context, user),
                      backgroundColor: surfaceColor,
                      foregroundColor: primaryColor,
                      child: const Icon(Icons.link),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'create',
                      onPressed: () => _showCreateSheet(context, user),
                      child: const Icon(Icons.add),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  void _showCreateSheet(BuildContext context, AppUser user) {
    showAppBottomSheet(context, _CreateCommitteeSheet(user: user));
  }

  void _showJoinSheet(BuildContext context, AppUser user) {
    showAppBottomSheet(context, _JoinCommitteeSheet(user: user));
  }

  void _showNotificationsSheet(BuildContext context, AppData data, AppUser user) {
    final notifs = data.notifications
        .where((n) => n.userId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showAppBottomSheet(
      context,
      Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Notifications',
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close, color: textMuted),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: notifs.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none,
                      title: 'No notifications',
                      subtitle: 'You are all caught up!',
                    )
                  : ListView.builder(
                      itemCount: notifs.length,
                      itemBuilder: (ctx, i) {
                        final n = notifs[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: n.read ? bgColor : primaryLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: n.read ? borderColor : primaryColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  style: TextStyle(
                                      color: n.read ? textMuted : textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(n.message, style: const TextStyle(color: textMuted, fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── No Committees View ────────────────────────────────────────────────────────

class _NoCommitteesView extends ConsumerWidget {
  final AppUser user;
  final AppData data;
  final List<Invitation> pendingInvitations;

  const _NoCommitteesView({
    required this.user,
    required this.data,
    required this.pendingInvitations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingInvitations.isNotEmpty) ...[
            const SectionTitle('PENDING INVITATIONS'),
            ...pendingInvitations.map((inv) {
              final group = data.groups.firstWhere(
                (g) => g.id == inv.groupId,
                orElse: () =>
                    Group(id: '', name: 'Unknown', createdBy: '', members: [], createdAt: ''),
              );
              return AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline, color: primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name,
                              style: const TextStyle(
                                  color: textColor, fontWeight: FontWeight.w600)),
                          Text('Code: ${inv.inviteCode}',
                              style: const TextStyle(color: textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _joinWithCode(context, ref, inv.inviteCode, user),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          const EmptyState(
            icon: Icons.account_balance,
            title: 'No committees yet',
            subtitle: 'Create one or join with an invite code',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => showAppBottomSheet(context, _CreateCommitteeSheet(user: user)),
            icon: const Icon(Icons.add),
            label: const Text('Create Committee'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor),
            ),
            onPressed: () => showAppBottomSheet(context, _JoinCommitteeSheet(user: user)),
            icon: const Icon(Icons.link),
            label: const Text('Join via Invite Code'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinWithCode(
      BuildContext context, WidgetRef ref, String code, AppUser user) async {
    try {
      final result = await dataService.joinGroupByInviteCode(code, user.name, user.email);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (context.mounted) showSuccess(context, 'Joined ${result.group.name}!');
    } catch (e) {
      if (context.mounted) showError(context, '$e');
    }
  }
}

// ─── Committee Body (has committees) ─────────────────────────────────────────

class _CommitteeBody extends ConsumerWidget {
  final List<Group> myGroups;
  final int activeIdx;
  final AppData data;
  final AppUser user;
  final Map<String, DateTime> lastSeen;
  final List<Invitation> pendingInvitations;

  const _CommitteeBody({
    required this.myGroups,
    required this.activeIdx,
    required this.data,
    required this.user,
    required this.lastSeen,
    required this.pendingInvitations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGroup = myGroups[activeIdx];
    final isAdmin = activeGroup.createdBy == user.id;

    // Unread chat for active group
    final ls = lastSeen[activeGroup.id];
    final unread = data.chatMessages.where((m) {
      if (m.groupId != activeGroup.id) return false;
      if (ls == null) return true;
      try {
        return DateTime.parse(m.createdAt).isAfter(ls);
      } catch (_) {
        return false;
      }
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Group selector chips
          if (myGroups.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: myGroups.asMap().entries.map((entry) {
                  final i = entry.key;
                  final g = entry.value;
                  final isActive = i == activeIdx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(activeCommitteeIndexProvider.notifier).state = i,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? primaryColor : bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? primaryColor : borderColor,
                          ),
                        ),
                        child: Text(
                          g.name,
                          style: TextStyle(
                            color: isActive ? primaryFg : textMuted,
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Active committee card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
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
                            activeGroup.name,
                            style: const TextStyle(
                                color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (activeGroup.description != null &&
                              activeGroup.description!.isNotEmpty)
                            Text(
                              activeGroup.description!,
                              style: const TextStyle(color: textMuted, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: isAdmin ? 'Admin' : 'Member',
                      color: isAdmin ? primaryColor : textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${activeGroup.members.length} member${activeGroup.members.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Members & Chat navigation
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommitteeDetailScreen(groupId: activeGroup.id),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Members (${activeGroup.members.length})',
                      style: const TextStyle(color: textColor),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommitteeDetailScreen(groupId: activeGroup.id),
                ),
              ).then((_) {
                // Mark as seen when returning from chat
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Chat', style: TextStyle(color: textColor)),
                  ),
                  if (unread > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                            color: primaryFg, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Icon(Icons.chevron_right, color: textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pending invitations card at bottom
          if (pendingInvitations.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warnBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: warnColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mail_outline, color: warnColor, size: 18),
                      SizedBox(width: 8),
                      Text('Pending Invitations',
                          style: TextStyle(
                              color: warnColor, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...pendingInvitations.take(3).map((inv) {
                    final group = data.groups.firstWhere(
                      (g) => g.id == inv.groupId,
                      orElse: () => Group(
                          id: '', name: 'Unknown', createdBy: '', members: [], createdAt: ''),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.name,
                                    style: const TextStyle(
                                        color: textColor, fontWeight: FontWeight.w500, fontSize: 13)),
                                Text('Code: ${inv.inviteCode}',
                                    style: const TextStyle(color: textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _joinWithCode(context, ref, inv.inviteCode, user),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _joinWithCode(
      BuildContext context, WidgetRef ref, String code, AppUser user) async {
    try {
      final result = await dataService.joinGroupByInviteCode(code, user.name, user.email);
      final newData = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(newData);
      if (context.mounted) showSuccess(context, 'Joined ${result.group.name}!');
    } catch (e) {
      if (context.mounted) showError(context, '$e');
    }
  }
}

// ─── Create Committee Sheet ───────────────────────────────────────────────────

class _CreateCommitteeSheet extends ConsumerStatefulWidget {
  final AppUser user;

  const _CreateCommitteeSheet({required this.user});

  @override
  ConsumerState<_CreateCommitteeSheet> createState() => _CreateCommitteeSheetState();
}

class _CreateCommitteeSheetState extends ConsumerState<_CreateCommitteeSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final List<String> _emails = [];
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _addEmail() {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    if (!_emails.contains(email)) {
      setState(() => _emails.add(email));
    }
    _emailCtrl.clear();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showError(context, 'Committee name is required.');
      return;
    }
    setState(() => _loading = true);
    try {
      await dataService.createGroup(name, widget.user.id, _emails, _descCtrl.text.trim());
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Committee created!');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Create Committee',
                    style:
                        TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
              decoration: const InputDecoration(labelText: 'Committee Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: textColor),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      labelText: 'Invite member email',
                      hintText: 'user@example.com',
                    ),
                    onSubmitted: (_) => _addEmail(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addEmail,
                  icon: const Icon(Icons.add_circle, color: primaryColor),
                ),
              ],
            ),
            if (_emails.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _emails
                    .map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _emails.remove(e)),
                          deleteIconColor: textMuted,
                          backgroundColor: bgColor,
                          side: const BorderSide(color: borderColor),
                        ))
                    .toList(),
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
                  : const Text('Create Committee'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Join Committee Sheet ─────────────────────────────────────────────────────

class _JoinCommitteeSheet extends ConsumerStatefulWidget {
  final AppUser user;

  const _JoinCommitteeSheet({required this.user});

  @override
  ConsumerState<_JoinCommitteeSheet> createState() => _JoinCommitteeSheetState();
}

class _JoinCommitteeSheetState extends ConsumerState<_JoinCommitteeSheet> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      showError(context, 'Enter a 6-character invite code.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result =
          await dataService.joinGroupByInviteCode(code, widget.user.name, widget.user.email);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Joined ${result.group.name}!');
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
              const Text('Join Committee',
                  style:
                      TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, color: textMuted),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeCtrl,
            style: const TextStyle(color: textColor, letterSpacing: 2),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '6-Character Invite Code',
              hintText: 'ABC123',
            ),
            maxLength: 6,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: primaryFg, strokeWidth: 2),
                  )
                : const Text('Join Committee'),
          ),
        ],
      ),
    );
  }
}
