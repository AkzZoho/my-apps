import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/auth_screen.dart';
import 'screens/kuri_list_screen.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: KuriApp()));
}

class KuriApp extends ConsumerStatefulWidget {
  const KuriApp({super.key});
  @override
  ConsumerState<KuriApp> createState() => _KuriAppState();
}

class _KuriAppState extends ConsumerState<KuriApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(themeModeProvider.notifier).load();
      await ref.read(appDataProvider.notifier).load();
      final data = ref.read(appDataProvider).valueOrNull;
      if (data != null) await ref.read(currentUserProvider.notifier).loadFromPrefs(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);
    return MaterialApp(
      title: 'Kuri',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: user == null
          ? const AuthScreen(appName: 'Kuri', appSubtitle: 'Track your savings plans')
          : const KuriListScreen(),
    );
  }
}
