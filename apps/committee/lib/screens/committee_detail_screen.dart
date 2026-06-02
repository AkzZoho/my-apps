import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../widgets/common.dart';

class CommitteeDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CommitteeDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<CommitteeDetailScreen> createState() => _CommitteeDetailScreenState();
}

class _CommitteeDetailScreenState extends ConsumerState<CommitteeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _tabIndex = _tabController.index);
      if (_tabController.index == 1) {
        // Chat tab opened — mark seen
        ref.read(lastSeenProvider.notifier).markSeen(widget.groupId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Committee')),
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('$e', style: TextStyle(color: c.danger))),
      ),
      data: (data) {
        final group = data.groups.firstWhere(
          (g) => g.id == widget.groupId,
          orElse: () => Group(id: '', name: 'Not Found', createdBy: '', members: [], createdAt: ''),
        );

        if (group.id.isEmpty) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(title: const Text('Committee')),
            body: Center(child: Text('Committee not found', style: TextStyle(color: c.textMuted))),
          );
        }

        final isAdmin = user?.id == group.createdBy;

        // Unread count for chat tab
        final lastSeen = ref.watch(lastSeenProvider);
        final ls = lastSeen[group.id];
        final unread = data.chatMessages.where((m) {
          if (m.groupId != group.id) return false;
          if (ls == null) return true;
          try {
            return DateTime.parse(m.createdAt).isAfter(ls);
          } catch (_) {
            return false;
          }
        }).length;

        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditSheet(context, group),
                  tooltip: 'Edit Committee',
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Members (${group.members.length})'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chat'),
                      if (unread > 0 && _tabIndex != 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: TextStyle(
                              color: c.primaryFg,
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
          body: TabBarView(
            controller: _tabController,
            children: [
              _MembersTab(group: group, data: data, currentUser: user, isAdmin: isAdmin),
              _ChatTab(group: group),
            ],
          ),
        );
      },
    );
  }

  void _showEditSheet(BuildContext context, Group group) {
    showAppBottomSheet(context, _EditCommitteeSheet(group: group));
  }
}

// ─── Members Tab ─────────────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final Group group;
  final AppData data;
  final AppUser? currentUser;
  final bool isAdmin;

  const _MembersTab({
    required this.group,
    required this.data,
    required this.currentUser,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
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
                label: const Text('+ Invite Member'),
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
            final canRemove = isAdmin && member.userId != currentUser?.id;
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
                            style: TextStyle(color: c.text, fontWeight: FontWeight.w500)),
                        Text(memberUser.email,
                            style: TextStyle(color: c.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: member.role == 'admin' ? 'Admin' : 'Member',
                    color: member.role == 'admin' ? c.primary : c.textMuted,
                  ),
                  if (canRemove) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      color: c.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: c.border),
                      ),
                      icon: Icon(Icons.more_vert, color: c.textMuted, size: 18),
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
                              await dataService.removeMember(
                                  group.id, currentUser!.id, member.userId);
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
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.person_remove, color: c.danger, size: 16),
                              const SizedBox(width: 8),
                              Text('Remove Member', style: TextStyle(color: c.danger)),
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
                      Icon(Icons.mail_outline, color: c.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.inviteeEmail,
                                style: TextStyle(color: c.text, fontSize: 13)),
                            Row(
                              children: [
                                Text(
                                  'Code: ${inv.inviteCode}',
                                  style: TextStyle(color: c.textMuted, fontSize: 12),
                                ),
                                CopyButton(inv.inviteCode),
                              ],
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: 'Pending', color: c.warn),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    if (currentUser == null) return;
    showAppBottomSheet(context, _InviteMemberSheet(group: group, user: currentUser!));
  }
}

// ─── Chat Tab ─────────────────────────────────────────────────────────────────

class _ChatTab extends ConsumerStatefulWidget {
  final Group group;

  const _ChatTab({required this.group});

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lastSeenProvider.notifier).markSeen(widget.group.id);
      _scrollToBottom();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final data = await dataService.getData();
        if (mounted) {
          ref.read(appDataProvider.notifier).updateState(data);
          _scrollToBottom();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await dataService.sendGroupMessage(widget.group.id, user.id, text);
      final data = await dataService.getData();
      if (mounted) {
        ref.read(appDataProvider.notifier).updateState(data);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) showError(context, 'Failed to send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: c.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: c.danger))),
      data: (data) {
        final messages = data.chatMessages
            .where((m) => m.groupId == widget.group.id)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No messages yet',
                      subtitle: 'Be the first to say something!',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        final isMe = user?.id == msg.senderUserId;
                        return _ChatBubble(message: msg, isMe: isMe);
                      },
                    ),
            ),
            _buildInputBar(c),
          ],
        );
      },
    );
  }

  Widget _buildInputBar(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: c.text),
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sending ? null : _send,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(color: c.primaryFg, strokeWidth: 2),
                    )
                  : Icon(Icons.send, color: c.primaryFg, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            AvatarWidget(name: message.senderName, size: 28),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? c.primaryLight : c.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(14),
                    ),
                    border: isMe ? null : Border.all(color: c.border),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : c.text,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(color: c.textDim, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            AvatarWidget(name: message.senderName, size: 28),
          ],
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Invite Member Sheet ──────────────────────────────────────────────────────

class _InviteMemberSheet extends ConsumerStatefulWidget {
  final Group group;
  final AppUser user;

  const _InviteMemberSheet({required this.group, required this.user});

  @override
  ConsumerState<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<_InviteMemberSheet> {
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
      ref.read(appDataProvider.notifier).updateState(data);
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
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Invite Member',
                  style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: Icon(Icons.close, color: c.textMuted),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: c.text),
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
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: c.primaryFg, strokeWidth: 2),
                  )
                : const Text('Send Invite'),
          ),
          if (_newInvitation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invitation created!',
                      style: TextStyle(color: c.green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Invite Code: ', style: TextStyle(color: c.textMuted, fontSize: 13)),
                      Text(
                        _newInvitation!.inviteCode,
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: c.textMuted),
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
                  Text(
                    'Share this code with the invitee.',
                    style: TextStyle(color: c.textDim, fontSize: 11),
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

// ─── Edit Committee Sheet ─────────────────────────────────────────────────────

class _EditCommitteeSheet extends ConsumerStatefulWidget {
  final Group group;

  const _EditCommitteeSheet({required this.group});

  @override
  ConsumerState<_EditCommitteeSheet> createState() => _EditCommitteeSheetState();
}

class _EditCommitteeSheetState extends ConsumerState<_EditCommitteeSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _descCtrl = TextEditingController(text: widget.group.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showError(context, 'Committee name is required.');
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await dataService.getData();
      final idx = data.groups.indexWhere((g) => g.id == widget.group.id);
      if (idx < 0) throw Exception('Committee not found.');
      final updated = data.groups[idx].copyWith(
        name: name,
        description: _descCtrl.text.trim(),
      );
      final updatedGroups = List<Group>.from(data.groups);
      updatedGroups[idx] = updated;
      await dataService.saveData(data.copyWith(groups: updatedGroups));
      final newData = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(newData);
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Committee updated!');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Edit Committee',
                  style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: Icon(Icons.close, color: c.textMuted),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: c.text),
            decoration: const InputDecoration(labelText: 'Committee Name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style: TextStyle(color: c.text),
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: c.primaryFg, strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
