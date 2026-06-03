import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/ios_install_banner.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
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
    final c = context.colors;
    final locale = ref.watch(localeProvider);
    final l10n = AppL10n(locale);
    final user = ref.watch(currentUserProvider);
    final appDataAsync = ref.watch(appDataProvider);

    if (!_initialized) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    return appDataAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        body: Center(child: Text('${l10n.error}: $e', style: TextStyle(color: c.danger))),
      ),
      data: (data) {
        if (user == null) return Scaffold(backgroundColor: c.bg, body: const SizedBox());

        final myKuris = data.kuris
            .where((k) => k.participantUserIds.contains(user.id) || k.createdBy == user.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Unread notifications count
        final unreadNotifs = data.notifications.where((n) => n.userId == user.id && !n.read).length;

        return Scaffold(
          backgroundColor: c.bg,
          appBar: AppBar(
            title: Text(l10n.appName),
            actions: [
              // Language toggle
              IconButton(
                icon: Text(
                  locale == AppLocale.malayalam ? 'EN' : 'മ',
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.bold),
                ),
                onPressed: () => ref.read(localeProvider.notifier).toggle(),
                tooltip: l10n.switchLanguage,
              ),
              IconButton(
                icon: Icon(() {
                  final mode = ref.watch(themeModeProvider);
                  final isDark = mode == ThemeMode.dark ||
                      (mode == ThemeMode.system &&
                          MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                  return isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
                }()),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(MediaQuery.platformBrightnessOf(context)),
                tooltip: l10n.toggleTheme,
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
                        decoration: BoxDecoration(
                          color: c.danger,
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
                tooltip: l10n.signOut,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: myKuris.isEmpty
                    ? EmptyState(
                  icon: Icons.currency_rupee,
                  title: l10n.noKurisYet,
                  subtitle: l10n.createFirstPlan,
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
                                    style: TextStyle(
                                      color: c.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isCreator)
                                  StatusBadge(label: l10n.creator, color: c.primary),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${kuri.contributionAmount.toInt()}/mo · Started ${formatDate(kuri.startDate)}',
                              style: TextStyle(color: c.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${kuri.participantUserIds.length} ${kuri.participantUserIds.length != 1 ? l10n.participants : l10n.participant}',
                              style: TextStyle(color: c.textDim, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${l10n.totalCollected}: ₹${totalCollected.toInt()}',
                                  style: TextStyle(
                                      color: c.green, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                if (missingUpi)
                                  Text(
                                    '⚠ UPI not set',
                                    style: TextStyle(color: c.warn, fontSize: 12),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const IosInstallBanner(),
            ],
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
    final l10n = AppL10n(ref.read(localeProvider));

    showAppBottomSheet(
      context,
      Builder(builder: (ctx) {
        final cc = ctx.colors;
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.notifications,
                      style: TextStyle(color: cc.text, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      icon: Icon(Icons.close, color: cc.textMuted),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: notifs.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none,
                        title: l10n.noNotifications,
                        subtitle: l10n.allCaughtUp,
                      )
                    : ListView.builder(
                        itemCount: notifs.length,
                        itemBuilder: (listCtx, i) {
                          final n = notifs[i];
                          final lc = listCtx.colors;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: n.read ? lc.bg : lc.primaryLight.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: n.read ? lc.border : lc.primary.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title,
                                    style: TextStyle(
                                        color: n.read ? lc.textMuted : lc.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(n.message,
                                    style: TextStyle(color: lc.textMuted, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
