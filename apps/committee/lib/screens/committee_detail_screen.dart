import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../widgets/common.dart';

// ─── WhatsApp share helper ────────────────────────────────────────────────────

Future<void> _shareViaWhatsApp(BuildContext context, String groupName, String code) async {
  final msg = 'Join my committee "$groupName" using invite code: $code';
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showError(context, 'Could not open WhatsApp');
  }
}

// ─── Committee Detail Screen (Members) ────────────────────────────────────────

class CommitteeDetailScreen extends ConsumerWidget {
  final String groupId;

  const CommitteeDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.members)),
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.error)),
        body: Center(child: Text('$e', style: TextStyle(color: c.danger))),
      ),
      data: (data) {
        final group = data.groups.firstWhere(
          (g) => g.id == groupId,
          orElse: () =>
              Group(id: '', name: 'Not Found', createdBy: '', members: [], createdAt: ''),
        );
        if (group.id.isEmpty) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(title: Text(l10n.members)),
            body:
                Center(child: Text(l10n.committeeNotFound, style: TextStyle(color: c.textMuted))),
          );
        }
        final isAdmin = user?.id == group.createdBy;
        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.editCommittee,
                  onPressed: () =>
                      showAppBottomSheet(context, _EditCommitteeSheet(group: group)),
                ),
            ],
          ),
          body: _MembersBody(group: group, data: data, currentUser: user, isAdmin: isAdmin),
        );
      },
    );
  }
}

// ─── Committee Chat Screen ─────────────────────────────────────────────────────

class CommitteeChatScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CommitteeChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<CommitteeChatScreen> createState() => _CommitteeChatScreenState();
}

class _CommitteeChatScreenState extends ConsumerState<CommitteeChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lastSeenProvider.notifier).markSeen(widget.groupId);
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

  Future<void> _send(String groupId) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    _controller.clear();
    try {
      await dataService.sendGroupMessage(groupId, user.id, text);
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
    final l10n = AppL10n(ref.watch(localeProvider));
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.chat)),
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.chat)),
        body: Center(child: Text('$e', style: TextStyle(color: c.danger))),
      ),
      data: (data) {
        final group = data.groups.firstWhere(
          (g) => g.id == widget.groupId,
          orElse: () =>
              Group(id: '', name: 'Not Found', createdBy: '', members: [], createdAt: ''),
        );
        if (group.id.isEmpty) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(title: Text(l10n.chat)),
            body:
                Center(child: Text(l10n.committeeNotFound, style: TextStyle(color: c.textMuted))),
          );
        }

        final messages = data.chatMessages
            .where((m) => m.groupId == widget.groupId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(title: Text(group.name)),
          body: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: l10n.noMessagesYet,
                        subtitle: l10n.beFirstToSay,
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
              _buildInputBar(c, l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar(AppColors c, AppL10n l10n) {
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
              decoration: InputDecoration(
                hintText: l10n.typeMessage,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _send(widget.groupId),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _sending ? null : () => _send(widget.groupId),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
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

// ─── Committee Settings Screen ─────────────────────────────────────────────────

class CommitteeSettingsScreen extends ConsumerWidget {
  final String groupId;

  const CommitteeSettingsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    return appDataAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.settings)),
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: Text(l10n.settings)),
        body: Center(child: Text('$e', style: TextStyle(color: c.danger))),
      ),
      data: (data) {
        final group = data.groups.firstWhere(
          (g) => g.id == groupId,
          orElse: () =>
              Group(id: '', name: 'Not Found', createdBy: '', members: [], createdAt: ''),
        );
        if (group.id.isEmpty) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(title: Text(l10n.settings)),
            body: Center(
                child: Text(l10n.committeeNotFound, style: TextStyle(color: c.textMuted))),
          );
        }

        final isAdmin = user?.id == group.createdBy;
        final pendingInvitations = data.invitations
            .where((inv) => inv.groupId == group.id && inv.status == 'pending')
            .toList();

        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(title: Text(group.name)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Committee info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                          style: TextStyle(
                              color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
                      if (group.description != null && group.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(group.description!,
                            style: TextStyle(color: c.textMuted, fontSize: 13)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 14, color: c.textDim),
                          const SizedBox(width: 4),
                          Text('${group.members.length} ${l10n.membersLabel}',
                              style: TextStyle(color: c.textDim, fontSize: 12)),
                          const SizedBox(width: 16),
                          Icon(Icons.calendar_today, size: 14, color: c.textDim),
                          const SizedBox(width: 4),
                          Text('Created ${formatDate(group.createdAt)}',
                              style: TextStyle(color: c.textDim, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (isAdmin) ...[
                  const SectionTitle('ADMIN'),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.edit_outlined,
                    label: l10n.editCommittee,
                    onTap: () => showAppBottomSheet(context, _EditCommitteeSheet(group: group)),
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.person_add_outlined,
                    label: l10n.inviteMember,
                    onTap: user != null
                        ? () => showAppBottomSheet(
                            context, _InviteMemberSheet(group: group, user: user))
                        : null,
                  ),
                  if (pendingInvitations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionTitle(l10n.pendingInvitations),
                    const SizedBox(height: 8),
                    ...pendingInvitations.map((inv) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
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
                                          Text('${l10n.codeLabel} ${inv.inviteCode}',
                                              style:
                                                  TextStyle(color: c.textMuted, fontSize: 12)),
                                          CopyButton(inv.inviteCode),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(label: l10n.pending, color: c.warn),
                              ],
                            ),
                          ),
                        )),
                  ],
                ],

                if (!isAdmin && user != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.danger,
                      side: BorderSide(color: c.danger.withOpacity(0.5)),
                    ),
                    icon: const Icon(Icons.exit_to_app, size: 18),
                    label: Text(l10n.leaveCommittee),
                    onPressed: () => _leaveCommittee(context, ref, group, user, l10n),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveCommittee(
      BuildContext context, WidgetRef ref, Group group, AppUser user, AppL10n l10n) async {
    final confirmed = await confirmDialog(
      context,
      title: l10n.leaveCommittee,
      message: '${l10n.areYouSureLeave} "${group.name}"?',
      confirmLabel: l10n.leave,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await dataService.removeMember(group.id, user.id, user.id);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      if (context.mounted) {
        Navigator.pop(context);
        showSuccess(context, '${l10n.youLeft} ${group.name}');
      }
    } catch (e) {
      if (context.mounted) showError(context, '$e');
    }
  }
}

// ─── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.label, this.onTap});

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
            Icon(icon, color: c.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: c.text))),
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Members Body ─────────────────────────────────────────────────────────────

class _MembersBody extends ConsumerWidget {
  final Group group;
  final AppData data;
  final AppUser? currentUser;
  final bool isAdmin;

  const _MembersBody({
    required this.group,
    required this.data,
    required this.currentUser,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = AppL10n(ref.watch(localeProvider));
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
                label: Text(l10n.inviteMemberBtn),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SectionTitle(l10n.membersSection),
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
                    label: member.role == 'admin' ? l10n.admin : l10n.memberRole,
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
                            title: l10n.removeMember,
                            message: 'Remove ${memberUser.name} from ${group.name}?',
                            confirmLabel: l10n.removeMember,
                          );
                          if (confirmed && context.mounted) {
                            try {
                              await dataService.removeMember(
                                  group.id, currentUser!.id, member.userId);
                              final newData = await dataService.getData();
                              ref.read(appDataProvider.notifier).updateState(newData);
                              if (context.mounted) showSuccess(context, l10n.memberRemoved);
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
                              Text(l10n.removeMember, style: TextStyle(color: c.danger)),
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
            SectionTitle(l10n.pendingInvitations),
            ...pendingInvitations.map((inv) => AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mail_outline, color: c.textMuted, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(inv.inviteeEmail,
                                style: TextStyle(color: c.text, fontSize: 13)),
                          ),
                          StatusBadge(label: l10n.pending, color: c.warn),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: c.primaryLight.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: c.primary.withOpacity(0.3)),
                            ),
                            child: Text(
                              inv.inviteCode,
                              style: TextStyle(
                                color: c.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          CopyButton(inv.inviteCode),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () =>
                                _shareViaWhatsApp(context, group.name, inv.inviteCode),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF25D366).withOpacity(0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.share, size: 14,
                                      color: Color(0xFF25D366)),
                                  SizedBox(width: 4),
                                  Text('WhatsApp',
                                      style: TextStyle(
                                          color: Color(0xFF25D366),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

// ─── Chat Bubble ──────────────────────────────────────────────────────────────

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
                  constraints:
                      BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? c.primaryLight : c.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft:
                          isMe ? const Radius.circular(14) : const Radius.circular(4),
                      bottomRight:
                          isMe ? const Radius.circular(4) : const Radius.circular(14),
                    ),
                    border: isMe ? null : Border.all(color: c.border),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(color: isMe ? Colors.white : c.text, fontSize: 14),
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
  AppL10n? _l10n;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      showError(context, _l10n!.enterEmailError);
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
              Text(l10n.inviteMember,
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
            decoration: InputDecoration(
              labelText: l10n.memberEmail,
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
                : Text(l10n.sendInvite),
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
                  Text(l10n.invitationCreated,
                      style: TextStyle(color: c.green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.primaryLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          _newInvitation!.inviteCode,
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: c.textMuted),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _newInvitation!.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.codeCopied),
                                duration: const Duration(seconds: 1)),
                          );
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                      ),
                      icon: const Icon(Icons.share, size: 16),
                      label: Text(l10n.shareViaWhatsApp),
                      onPressed: () => _shareViaWhatsApp(
                          context, widget.group.name, _newInvitation!.inviteCode),
                    ),
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
  AppL10n? _l10n;

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
      showError(context, _l10n!.committeeNameRequired);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await dataService.getData();
      final idx = data.groups.indexWhere((g) => g.id == widget.group.id);
      if (idx < 0) throw Exception(_l10n!.committeeNotFound);
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
              Text(l10n.editCommittee,
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
            decoration: InputDecoration(labelText: '${l10n.committeeName} *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style: TextStyle(color: c.text),
            decoration: InputDecoration(labelText: l10n.description),
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
                : Text(l10n.saveChanges),
          ),
        ],
      ),
    );
  }
}
