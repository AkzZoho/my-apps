import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/providers.dart';

enum AppLocale { english, malayalam }

class AppL10n {
  final AppLocale locale;
  const AppL10n(this.locale);

  static const _en = {
    'appName': 'Kuri',
    'appSubtitle': 'Track your savings plans',
    'login': 'Login',
    'signup': 'Sign Up',
    'createAccount': 'Create Account',
    'home': 'Home',
    'receipts': 'Receipts',
    'settings': 'Settings',
    'participants': 'Participants',
    'planName': 'Plan Name',
    'monthlyAmount': 'Monthly Amount',
    'startDate': 'Start Date',
    'upiId': 'UPI ID',
    'paymentQr': 'Payment QR',
    'totalCollected': 'Total Collected',
    'yourPaid': 'Your Paid',
    'planTotal': 'Plan Total',
    'paymentSummary': 'Payment Summary',
    'createKuri': 'Create Kuri',
    'addParticipant': 'Add Participant',
    'submit': 'Submit',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'review': 'Review',
    'approve': 'Approve',
    'reject': 'Reject',
    'language': 'Language',
    'english': 'English',
    'malayalam': 'Malayalam',
  };

  static const _ml = {
    'appName': 'കുറി',
    'appSubtitle': 'നിങ്ങളുടെ സേവിംഗ്സ് പ്ലാനുകൾ ട്രാക്ക് ചെയ്യൂ',
    'login': 'ലോഗിൻ',
    'signup': 'സൈൻ അപ്പ്',
    'createAccount': 'അക്കൗണ്ട് ഉണ്ടാക്കൂ',
    'home': 'ഹോം',
    'receipts': 'രസീതുകൾ',
    'settings': 'ക്രമീകരണങ്ങൾ',
    'participants': 'അംഗങ്ങൾ',
    'planName': 'പ്ലാൻ പേര്',
    'monthlyAmount': 'മാസ തുക',
    'startDate': 'ആരംഭ തീയതി',
    'upiId': 'UPI ID',
    'paymentQr': 'പേമെന്റ് QR',
    'totalCollected': 'മൊത്തം ശേഖരിച്ചത്',
    'yourPaid': 'നിങ്ങൾ അടച്ചത്',
    'planTotal': 'പ്ലാൻ ആകെ',
    'paymentSummary': 'പേമെന്റ് സംഗ്രഹം',
    'createKuri': 'കുറി ഉണ്ടാക്കൂ',
    'addParticipant': 'അംഗത്തെ ചേർക്കൂ',
    'submit': 'സമർപ്പിക്കുക',
    'cancel': 'റദ്ദാക്കുക',
    'delete': 'ഇല്ലാതാക്കൂ',
    'review': 'അവലോകനം',
    'approve': 'അംഗീകരിക്കുക',
    'reject': 'നിരസിക്കുക',
    'language': 'ഭാഷ',
    'english': 'English',
    'malayalam': 'മലയാളം',
  };

  String get appName => _t('appName');
  String get appSubtitle => _t('appSubtitle');
  String get login => _t('login');
  String get signup => _t('signup');
  String get createAccount => _t('createAccount');
  String get home => _t('home');
  String get receipts => _t('receipts');
  String get settings => _t('settings');
  String get participants => _t('participants');
  String get planName => _t('planName');
  String get monthlyAmount => _t('monthlyAmount');
  String get startDate => _t('startDate');
  String get upiId => _t('upiId');
  String get paymentQr => _t('paymentQr');
  String get totalCollected => _t('totalCollected');
  String get yourPaid => _t('yourPaid');
  String get planTotal => _t('planTotal');
  String get paymentSummary => _t('paymentSummary');
  String get createKuri => _t('createKuri');
  String get addParticipant => _t('addParticipant');
  String get submit => _t('submit');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get review => _t('review');
  String get approve => _t('approve');
  String get reject => _t('reject');
  String get language => _t('language');
  String get english => _t('english');
  String get malayalam => _t('malayalam');

  String _t(String key) {
    final map = locale == AppLocale.malayalam ? _ml : _en;
    return map[key] ?? key;
  }
}

// ─── BuildContext extension ────────────────────────────────────────────────────

extension L10nContext on BuildContext {
  AppL10n l10n(WidgetRef ref) => AppL10n(ref.watch(localeProvider));
}
