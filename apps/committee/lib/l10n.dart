import 'package:flutter/material.dart';

// ─── Supported Locales ────────────────────────────────────────────────────────

enum AppLocale { english, malayalam }

// ─── Localisation Strings ─────────────────────────────────────────────────────

class AppL10n {
  final AppLocale locale;
  const AppL10n(this.locale);

  // App identity
  String get appName          => _s('Committee',                         'കമ്മിറ്റി');
  String get appSubtitle      => _s('Manage your savings committees',    'നിങ്ങളുടെ കമ്മിറ്റികൾ നിയന്ത്രിക്കൂ');

  // Navigation / sections
  String get members          => _s('Members',       'അംഗങ്ങൾ');
  String get chat             => _s('Chat',           'ചാറ്റ്');
  String get invite           => _s('Invite',         'ക്ഷണിക്കൂ');
  String get notifications    => _s('Notifications',  'അറിയിപ്പുകൾ');
  String get settings         => _s('Settings',       'ക്രമീകരണങ്ങൾ');

  // Actions
  String get createCommittee  => _s('Create Committee',  'കമ്മിറ്റി ഉണ്ടാക്കൂ');
  String get joinCommittee    => _s('Join Committee',     'കമ്മിറ്റിയിൽ ചേരൂ');
  String get login            => _s('Login',              'ലോഗിൻ');
  String get signup           => _s('Sign Up',            'സൈൻ അപ്പ്');
  String get createAccount    => _s('Create Account',     'അക്കൗണ്ട് ഉണ്ടാക്കൂ');

  // Language names
  String get language         => _s('Language',   'ഭാഷ');
  String get english          => 'English';
  String get malayalam        => _s('Malayalam',  'മലയാളം');

  // ── internal helper ────────────────────────────────────────────────────────
  String _s(String en, String ml) =>
      locale == AppLocale.malayalam ? ml : en;
}

// ─── Locale Notifier (Riverpod) ───────────────────────────────────────────────
// Defined in providers/providers.dart to avoid a circular import.
// This file only exposes AppLocale + AppL10n.

// ─── BuildContext extension ────────────────────────────────────────────────────

extension L10nContext on BuildContext {
  // Resolved at call-site via the localeProvider watch.
  // Usage:  final l10n = AppL10n(ref.watch(localeProvider));
}
