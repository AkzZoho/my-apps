import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../services/data_service.dart';
import '../l10n.dart';

// ─── Theme Mode ─────────────────────────────────────────────────────────────

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('theme_mode') ?? 'system';
    state = val == 'light' ? ThemeMode.light : val == 'dark' ? ThemeMode.dark : ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
    state = mode;
  }

  void toggle(Brightness platformBrightness) {
    final isDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && platformBrightness == Brightness.dark);
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

// ─── Current User ───────────────────────────────────────────────────────────

class CurrentUserNotifier extends StateNotifier<AppUser?> {
  CurrentUserNotifier() : super(null);

  Future<void> loadFromPrefs(AppData appData) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('pref_user_id');
    if (userId != null && userId.isNotEmpty) {
      final user = appData.users.firstWhere(
        (u) => u.id == userId,
        orElse: () => AppUser(id: '', name: '', email: ''),
      );
      if (user.id.isNotEmpty) {
        state = user;
        return;
      }
    }
    state = null;
  }

  Future<void> setUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_user_id', user.id);
    state = user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pref_user_id');
    state = null;
  }
}

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AppUser?>(
  (ref) => CurrentUserNotifier(),
);

// ─── App Data ────────────────────────────────────────────────────────────────

class AppDataNotifier extends StateNotifier<AsyncValue<AppData>> {
  AppDataNotifier() : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await dataService.getData();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      final data = await dataService.getData();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateState(AppData data) {
    state = AsyncValue.data(data);
  }

  AppData? get current => state.valueOrNull;
}

final appDataProvider = StateNotifierProvider<AppDataNotifier, AsyncValue<AppData>>(
  (ref) => AppDataNotifier(),
);

// ─── Last Seen Timestamps (for unread chat count) ──────────────────────────

class LastSeenNotifier extends StateNotifier<Map<String, DateTime>> {
  LastSeenNotifier() : super({});

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('lastSeen_'));
    final map = <String, DateTime>{};
    for (final key in keys) {
      final val = prefs.getString(key);
      if (val != null) {
        try {
          map[key.replaceFirst('lastSeen_', '')] = DateTime.parse(val);
        } catch (_) {}
      }
    }
    state = map;
  }

  Future<void> markSeen(String groupId) async {
    final now = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSeen_$groupId', now.toIso8601String());
    state = {...state, groupId: now};
  }

  DateTime? getLastSeen(String groupId) => state[groupId];
}

final lastSeenProvider = StateNotifierProvider<LastSeenNotifier, Map<String, DateTime>>(
  (ref) => LastSeenNotifier(),
);

// ─── Active Committee Index ─────────────────────────────────────────────────

final activeCommitteeIndexProvider = StateProvider<int>((ref) => 0);

// ─── Locale ─────────────────────────────────────────────────────────────────

class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.english);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString('app_locale') ?? 'en';
    state = val == 'ml' ? AppLocale.malayalam : AppLocale.english;
  }

  Future<void> setLocale(AppLocale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale == AppLocale.malayalam ? 'ml' : 'en');
    state = locale;
  }

  void toggle() {
    setLocale(state == AppLocale.malayalam ? AppLocale.english : AppLocale.malayalam);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, AppLocale>(
  (ref) => LocaleNotifier(),
);

// BuildContext extension for l10n
extension L10nX on WidgetRef {
  AppL10n get l10n => AppL10n(read(localeProvider));
}
