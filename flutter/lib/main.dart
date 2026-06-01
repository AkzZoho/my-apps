import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'providers/providers.dart';
import 'screens/auth_screen.dart';
import 'screens/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: CommitteeApp()));
}

class CommitteeApp extends ConsumerWidget {
  const CommitteeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Committee',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load app data from Firebase
    await ref.read(appDataProvider.notifier).load();
    // Load last seen timestamps
    await ref.read(lastSeenProvider.notifier).load();
    // Check if user is persisted
    final appData = ref.read(appDataProvider).valueOrNull;
    if (appData != null) {
      await ref.read(currentUserProvider.notifier).loadFromPrefs(appData);
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance, color: primaryColor, size: 56),
              SizedBox(height: 24),
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const AuthScreen();
    }
    return const MainScaffold();
  }
}
