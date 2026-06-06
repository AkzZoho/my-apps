import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // clean URLs without the # fragment
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
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
      await ref.read(localeProvider.notifier).load();
      await ref.read(appDataProvider.notifier).load();
      final data = ref.read(appDataProvider).valueOrNull;
      if (data != null) await ref.read(currentUserProvider.notifier).loadFromPrefs(data);
      // Signal go_router that auth state is now reliable
      ref.read(initDoneProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Kuri',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
