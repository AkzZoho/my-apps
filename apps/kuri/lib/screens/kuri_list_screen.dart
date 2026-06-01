import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import 'kuri_detail_screen.dart';
import 'create_kuri_screen.dart';

class KuriListScreen extends ConsumerStatefulWidget {
  const KuriListScreen({super.key});

  @override
  ConsumerState<KuriListScreen> createState() => _KuriListScreenState();
}

class _KuriListScreenState extends ConsumerState<KuriListScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final notifier = ref.read(appDataProvider.notifier);
    await notifier.load();
    final data = ref.read(appDataProvider).valueOrNull;
    if (data != null) {
      await ref.read(currentUserProvider.notifier).loadFromPrefs(data);
    }
    await ref.read(lastSeenProvider.notifier).load();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

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

        final myKuris = data.kuris
            .where((k) => k.participantUserIds.contains(user.id) || k.createdBy == user.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Unread notifications count
        final unreadNotifs = data.notifications.where((n) => n.userId == user.id && !n.read).length;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('Kuri'),
            actions: [
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
          body: myKuris.isEmpty
              ? const EmptyState(
                  icon: Icons.currency_rupee,
                  title: 'No Kuris yet',
                  subtitle: 'Create your first savings plan',
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: myKuris.length,
                    itemBuilder: (ctx, i) {
                      final kuri = myKuris[i];
                      final approvedPayments = data.payments
                          .where((p) => p.kuriId == kuri.id && p.status == 'approved')
                          .toList();
                      final totalCollected =
                          approvedPayments.fold<double>(0, (sum, p) => sum + p.amount);
                      final isCreator = kuri.createdBy == user.id;
                      final missingUpi = isCreator && (kuri.upiId == null || kuri.upiId!.isEmpty);

                      return AppCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => KuriDetailScreen(kuriId: kuri.id),
                          ),
                        ).then((_) => ref.read(appDataProvider.notifier).refresh()),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    kuri.name,
                                    style: const TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isCreator)
                                  const StatusBadge(label: 'Creator', color: primaryColor),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${kuri.contributionAmount.toInt()}/mo · Started ${formatDate(kuri.startDate)}',
                              style: const TextStyle(color: textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${kuri.participantUserIds.length} participant${kuri.participantUserIds.length != 1 ? 's' : ''}',
                              style: const TextStyle(color: textDim, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total collected: ₹${totalCollected.toInt()}',
                                  style: const TextStyle(
                                      color: greenColor, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                if (missingUpi)
                                  const Text(
                                    '⚠ UPI not set',
                                    style: TextStyle(color: warnColor, fontSize: 12),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateKuriScreen()),
            ).then((_) => ref.read(appDataProvider.notifier).refresh()),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
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
                    style:
                        TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                            border: Border.all(
                                color:
                                    n.read ? borderColor : primaryColor.withOpacity(0.3)),
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
                              Text(n.message,
                                  style: const TextStyle(color: textMuted, fontSize: 12)),
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
