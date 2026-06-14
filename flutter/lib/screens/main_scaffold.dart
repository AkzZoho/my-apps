import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'committee/committee_tab.dart';
import 'kuri/kuri_tab.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    // Unread chat count
    int unreadCount = 0;
    appDataAsync.whenData((data) {
      final lastSeen = ref.watch(lastSeenProvider);
      final activeIdx = ref.watch(activeCommitteeIndexProvider);
      if (user != null) {
        final myGroups = data.groups
            .where((g) => g.members.any((m) => m.userId == user.id))
            .toList();
        if (myGroups.isNotEmpty && activeIdx < myGroups.length) {
          final activeGroup = myGroups[activeIdx];
          final ls = lastSeen[activeGroup.id];
          final msgs = data.chatMessages
              .where((m) => m.groupId == activeGroup.id)
              .toList();
          if (ls == null) {
            unreadCount = msgs.length;
          } else {
            unreadCount = msgs.where((m) {
              try {
                return DateTime.parse(m.createdAt).isAfter(ls);
              } catch (_) {
                return false;
              }
            }).length;
          }
        }
      }
    });

    final tabs = [
      const CommitteeTab(),
      const KuriTab(),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Committee' : 'Kuri'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 40),
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarWidget(name: user.name, size: 30),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down, color: textMuted, size: 18),
                    ],
                  ),
                ),
                onSelected: (val) async {
                  if (val == 'logout') {
                    await ref.read(currentUserProvider.notifier).logout();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user.name, style: const TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                        Text(user.email, style: const TextStyle(color: textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: dangerColor, size: 16),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: dangerColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Committee',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: unreadCount > 0 && _currentIndex != 0
                  ? Text('$unreadCount')
                  : null,
              isLabelVisible: false,
              child: const Icon(Icons.currency_rupee),
            ),
            label: 'Kuri',
          ),
        ],
      ),
    );
  }
}
