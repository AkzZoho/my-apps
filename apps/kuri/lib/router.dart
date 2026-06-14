import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models.dart';
import 'providers/providers.dart';
import 'screens/auth_screen.dart';
import 'screens/create_kuri_screen.dart';
import 'screens/kuri_detail_screen.dart';
import 'screens/kuri_list_screen.dart';
import 'screens/kuri_auction_screen.dart';
import 'theme.dart';

// Signals that the app has finished loading user + data from local storage.
// Prevents go_router from redirecting to /auth before prefs are read.
final initDoneProvider = StateProvider<bool>((ref) => false);

// Bridges Riverpod state changes to GoRouter's refreshListenable.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AppUser?>(currentUserProvider, (_, __) => notifyListeners());
    ref.listen<bool>(initDoneProvider, (_, __) => notifyListeners());
  }
}

final _routerNotifierProvider = Provider.autoDispose<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/kuri',
    refreshListenable: notifier,
    redirect: (context, state) {
      final initialized = ref.read(initDoneProvider);
      if (!initialized) return null; // still booting — don't redirect yet

      final user = ref.read(currentUserProvider);
      final onAuth = state.matchedLocation == '/auth';
      if (user == null && !onAuth) return '/auth';
      if (user != null && onAuth) return '/kuri';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (_, __) => const AuthScreen(
          appName: 'Kuri',
          appSubtitle: 'Track your Kuris',
        ),
      ),
      GoRoute(
        path: '/kuri',
        builder: (_, __) => const KuriListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const CreateKuriScreen(),
          ),
          GoRoute(
            path: ':kuriId',
            builder: (_, state) =>
                KuriDetailScreen(kuriId: state.pathParameters['kuriId']!),
            routes: [
              GoRoute(
                path: 'receipts',
                builder: (_, state) => _KuriSubRoute(
                  kuriId: state.pathParameters['kuriId']!,
                  child: (kuri, userId) =>
                      KuriReceiptsScreen(kuri: kuri, currentUserId: userId),
                ),
              ),
              GoRoute(
                path: 'settings',
                builder: (_, state) {
                  final id = state.pathParameters['kuriId']!;
                  return _KuriSubRoute(
                    kuriId: id,
                    child: (kuri, userId) => KuriSettingsScreen(
                      key: ValueKey(id),
                      kuri: kuri,
                      currentUserId: userId,
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'auction',
                builder: (_, state) => _KuriSubRoute(
                  kuriId: state.pathParameters['kuriId']!,
                  child: (kuri, userId) =>
                      KuriAuctionScreen(kuri: kuri, currentUserId: userId),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ─── Wrapper: looks up KuriPlan and passes it to the sub-screen ───────────────

class _KuriSubRoute extends ConsumerWidget {
  final String kuriId;
  final Widget Function(KuriPlan kuri, String currentUserId) child;

  const _KuriSubRoute({required this.kuriId, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final dataAsync = ref.watch(appDataProvider);
    final user = ref.watch(currentUserProvider);
    final data = dataAsync.valueOrNull;

    if (data == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    final kuri = data.kuris.firstWhere(
      (k) => k.id == kuriId,
      orElse: () => KuriPlan(
        id: '',
        name: '',
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
        backgroundColor: c.bg,
        body: Center(
          child: Text('Kuri not found',
              style: TextStyle(color: c.textMuted)),
        ),
      );
    }

    return child(kuri, user?.id ?? '');
  }
}
