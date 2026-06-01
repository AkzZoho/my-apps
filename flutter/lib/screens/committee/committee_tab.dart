import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../providers/providers.dart';
import '../../services/data_service.dart';
import '../../widgets/common.dart';
import 'chat_view.dart';

class CommitteeTab extends ConsumerStatefulWidget {
  const CommitteeTab({super.key});

  @override
  ConsumerState<CommitteeTab> createState() => _CommitteeTabState();
}

class _CommitteeTabState extends ConsumerState<CommitteeTab>
    with SingleTickerProviderStateMixin {
  TabController? _subTabController;
  int _subTabIndex = 0;

  @override
  void dispose() {
    _subTabController?.dispose();
    super.dispose();
  }

  void _initSubTab(int groupCount) {
    if (_subTabController == null || _subTabController!.length != 2) {
      _subTabController?.dispose();
      _subTabController = TabController(length: 2, vsync: this);
      _subTabController!.addListener(() {
        if (_subTabController!.indexIsChanging) return;
        setState(() => _subTabIndex = _subTabController!.index);
        if (_subTabController!.index == 1) {
          // Chat tab opened — mark seen
          final appData = ref.read(appDataProvider).valueOrNull;
          final user = ref.read(currentUserProvider);
          if (appData != null && user != null) {
            final activeIdx = ref.read(activeCommitteeIndexProvider);
            final myGroups = appData.groups
                .where((g) => g.members.any((m) => m.userId == user.id))
                .toList();
            if (activeIdx < myGroups.length) {
              ref.read(lastSeenProvider.notifier).markSeen(myGroups[activeIdx].id);
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: dangerColor))),
      data: (data) {
        if (user == null) return const SizedBox();
        final myGroups = data.groups
            .where((g) => g.members.any((m) => m.userId == user.id))
            .toList();

        if (myGroups.isEmpty) {
          return _NoCommitteesView(user: user, data: data);
        }

        _initSubTab(myGroups.length);

        final activeIdx = ref.watch(activeCommitteeIndexProvider);
        final safeIdx = activeIdx < myGroups.length ? activeIdx : 0;
        final activeGroup = myGroups[safeIdx];

        // Unread count for chat tab
        final lastSeen = ref.watch(lastSeenProvider);
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

        return Column(
          children: [
            // Group selector chips
            if (myGroups.length > 1) _GroupSelector(groups: myGroups, activeIdx: safeIdx),
            // Sub-tabs
            Container(
              color: surfaceColor,
              child: TabBar(
                controller: _subTabController,
                tabs: [
                  const Tab(text: 'Members'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Chat'),
                        if (unread > 0 && _subTabIndex != 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: primaryFg,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _subTabController,
                children: [
                  _MembersView(group: activeGroup, data: data, user: user),
                  ChatView(group: activeGroup),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── No Committees view ───────────────────────────────────────────────────────

class _NoCommitteesView extends ConsumerWidget {
  final AppUser user;
  final AppData data;

  const _NoCommitteesView({required this.user, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingInvitations = data.invitations
        .where((inv) => inv.inviteeEmail == user.email && inv.status == 'pending')
        .toList();

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
                orElse: () => Group(id: '', name: 'Unknown', createdBy: '', members: [], createdAt: ''),
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
                          Text(group.name, style: const TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                          Text('Code: ${inv.inviteCode}', style: const TextStyle(color: textMuted, fontSize: 12)),
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
            onPressed: () => _showCreateSheet(context, ref, user),
            icon: const Icon(Icons.add),
            label: const Text('Create Committee'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor),
            ),
            onPressed: () => _showJoinSheet(context, ref, user),
            icon: const Icon(Icons.link),
            label: const Text('Join via Invite Code'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinWithCode(BuildContext context, WidgetRef ref, String code, AppUser user) async {
    try {
      final result = await dataService.joinGroupByInviteCode(code, user.name, user.email);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (context.mounted) showSuccess(context, 'Joined ${result.group.name}!');
    } catch (e) {
      if (context.mounted) showError(context, '$e');
    }
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref, AppUser user) {
    showAppBottomSheet(context, _CreateCommitteeSheet(user: user, ref: ref));
  }

  void _showJoinSheet(BuildContext context, WidgetRef ref, AppUser user) {
    showAppBottomSheet(context, _JoinCommitteeSheet(user: user, ref: ref));
  }
}

// ─── Group selector ──────────────────────────────────────────────────────────

class _GroupSelector extends ConsumerWidget {
  final List<Group> groups;
  final int activeIdx;

  const _GroupSelector({required this.groups, required this.activeIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: groups.asMap().entries.map((entry) {
                  final i = entry.key;
                  final g = entry.value;
                  final isActive = i == activeIdx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => ref.read(activeCommitteeIndexProvider.notifier).state = i,
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
          ),
          // Create new button
          IconButton(
            icon: const Icon(Icons.add, color: primaryColor),
            onPressed: () {
              final user = ref.read(currentUserProvider);
              if (user != null) {
                showAppBottomSheet(context, _CreateCommitteeSheet(user: user, ref: ref));
              }
            },
            tooltip: 'Create Committee',
          ),
        ],
      ),
    );
  }
}

// ─── Members view ─────────────────────────────────────────────────────────────

class _MembersView extends ConsumerWidget {
  final Group group;
  final AppData data;
  final AppUser user;

  const _MembersView({required this.group, required this.data, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = group.createdBy == user.id;
    final pendingInvitations = data.invitations
        .where((inv) => inv.groupId == group.id && inv.status == 'pending')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAdmin)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showInviteSheet(context, ref),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Invite'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 12),
          const SectionTitle('MEMBERS'),
          ...group.members.map((member) {
            final memberUser = data.users.firstWhere(
              (u) => u.id == member.userId,
              orElse: () => AppUser(id: member.userId, name: 'Unknown', email: ''),
            );
            final isCurrentUserAdmin = isAdmin && member.userId != user.id;
            return AppCard(
              child: Row(
                children: [
                  AvatarWidget(name: memberUser.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(memberUser.name,
                            style: const TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                        Text(memberUser.email,
                            style: const TextStyle(color: textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: member.role == 'admin' ? 'Admin' : 'Member',
                    color: member.role == 'admin' ? primaryColor : textMuted,
                  ),
                  if (isCurrentUserAdmin) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      color: surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: borderColor),
                      ),
                      icon: const Icon(Icons.more_vert, color: textMuted, size: 18),
                      onSelected: (val) async {
                        if (val == 'remove') {
                          final confirmed = await confirmDialog(
                            context,
                            title: 'Remove Member',
                            message: 'Remove ${memberUser.name} from ${group.name}?',
                            confirmLabel: 'Remove',
                          );
                          if (confirmed && context.mounted) {
                            try {
                              await dataService.removeMember(group.id, user.id, member.userId);
                              final newData = await dataService.getData();
                              ref.read(appDataProvider.notifier).updateState(newData);
                              if (context.mounted) showSuccess(context, 'Member removed.');
                            } catch (e) {
                              if (context.mounted) showError(context, '$e');
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, color: dangerColor, size: 16),
                              SizedBox(width: 8),
                              Text('Remove', style: TextStyle(color: dangerColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
          if (pendingInvitations.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionTitle('PENDING INVITATIONS'),
            ...pendingInvitations.map((inv) => AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline, color: textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.inviteeEmail,
                                style: const TextStyle(color: textColor, fontSize: 13)),
                            Row(
                              children: [
                                Text(
                                  'Code: ${inv.inviteCode}',
                                  style: const TextStyle(color: textMuted, fontSize: 12),
                                ),
                                CopyButton(inv.inviteCode),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(label: 'Pending', color: warnColor),
                    ],
                  ),
                )),
          ],
          // Join committee button for non-admin
          if (!isAdmin) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor),
              ),
              onPressed: () {
                showAppBottomSheet(context, _JoinCommitteeSheet(user: user, ref: ref));
              },
              icon: const Icon(Icons.link),
              label: const Text('Join Another Committee'),
            ),
          ],
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showAppBottomSheet(context, _InviteMemberSheet(group: group, user: user, ref: ref));
  }
}

// ─── Create Committee Sheet ───────────────────────────────────────────────────

class _CreateCommitteeSheet extends StatefulWidget {
  final AppUser user;
  final WidgetRef ref;

  const _CreateCommitteeSheet({required this.user, required this.ref});

  @override
  State<_CreateCommitteeSheet> createState() => _CreateCommitteeSheetState();
}

class _CreateCommitteeSheetState extends State<_CreateCommitteeSheet> {
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
      widget.ref.read(appDataProvider.notifier).updateState(data);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Create Committee',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
    );
  }
}

// ─── Join Committee Sheet ─────────────────────────────────────────────────────

class _JoinCommitteeSheet extends StatefulWidget {
  final AppUser user;
  final WidgetRef ref;

  const _JoinCommitteeSheet({required this.user, required this.ref});

  @override
  State<_JoinCommitteeSheet> createState() => _JoinCommitteeSheetState();
}

class _JoinCommitteeSheetState extends State<_JoinCommitteeSheet> {
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
      final result = await dataService.joinGroupByInviteCode(code, widget.user.name, widget.user.email);
      final data = await dataService.getData();
      widget.ref.read(appDataProvider.notifier).updateState(data);
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
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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

// ─── Invite Member Sheet ──────────────────────────────────────────────────────

class _InviteMemberSheet extends StatefulWidget {
  final Group group;
  final AppUser user;
  final WidgetRef ref;

  const _InviteMemberSheet({required this.group, required this.user, required this.ref});

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  Invitation? _newInvitation;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      showError(context, 'Email is required.');
      return;
    }
    setState(() => _loading = true);
    try {
      final inv = await dataService.addMemberByEmail(widget.group.id, widget.user.id, email);
      final data = await dataService.getData();
      widget.ref.read(appDataProvider.notifier).updateState(data);
      setState(() => _newInvitation = inv);
      _emailCtrl.clear();
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
              const Text('Invite Member',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close, color: textMuted),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: textColor),
            decoration: const InputDecoration(
              labelText: 'Member Email',
              hintText: 'user@example.com',
            ),
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
                : const Text('Send Invite'),
          ),
          if (_newInvitation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: greenColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: greenColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invitation created!',
                      style: TextStyle(color: greenColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Invite Code: ',
                          style: const TextStyle(color: textMuted, fontSize: 13)),
                      Text(
                        _newInvitation!.inviteCode,
                        style: const TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: textMuted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _newInvitation!.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Code copied!'),
                                duration: Duration(seconds: 1)),
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                  const Text(
                    'Share this code with the invitee.',
                    style: TextStyle(color: textDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
