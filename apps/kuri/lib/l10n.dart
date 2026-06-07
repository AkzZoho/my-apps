import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/providers.dart';

enum AppLocale { english, malayalam }

class AppL10n {
  final AppLocale locale;
  const AppL10n(this.locale);

  static const _en = {
    // App identity
    'appName': 'Kuri',
    'appSubtitle': 'Track your Kuris',
    // Auth
    'logIn': 'Log In',
    'login': 'Login',
    'signUp': 'Sign Up',
    'createAccount': 'Create Account',
    'fullName': 'Full Name',
    'emailAddress': 'Email Address',
    'sendCode': 'Send Code',
    'or': 'or',
    'back': 'Back',
    'checkYourEmail': 'Check your email',
    'weSentCodeTo': 'We sent a 6-digit code to',
    'didntReceive': "Didn't receive it?",
    'resend': 'Resend',
    'verify': 'Verify',
    'continueWithGoogle': 'Continue with Google',
    'enterEmailError': 'Please enter your email address.',
    'validEmailError': 'Please enter a valid email address.',
    'enterNameError': 'Please enter your full name.',
    'noAccountError': 'No account found for this email. Please sign up.',
    'somethingWentWrong': 'Something went wrong. Please try again.',
    'newCodeSent': 'New code sent!',
    'invalidCode': 'Invalid or expired code. Please try again.',
    'nameRequiredToCreate': 'Name is required to create an account.',
    'enterOtpError': 'Please enter the 6-digit code.',
    // Navigation
    'home': 'Home',
    'receipts': 'Receipts',
    'settings': 'Settings',
    // List screen
    'signOut': 'Sign out',
    'switchLanguage': 'Switch language',
    'toggleTheme': 'Toggle theme',
    'account': 'Account',
    'deleteAccount': 'Delete Account',
    'deleteAccountWarning': 'This will permanently delete your account and all associated data. This cannot be undone.',
    'accountDeleted': 'Account deleted.',
    'noKurisYet': 'No Kuris yet',
    'createFirstPlan': 'Create your first Kuri',
    'notifications': 'Notifications',
    'noNotifications': 'No notifications',
    'allCaughtUp': 'You are all caught up!',
    'creator': 'Moopan',
    'participant': 'participant',
    'participants': 'participants',
    // Kuri detail
    'loading': 'Loading...',
    'error': 'Error',
    'kuriNotFound': 'Kuri not found',
    'deleteKuri': 'Delete Kuri',
    'areYouSureDelete': 'Are you sure you want to delete',
    'cannotUndo': 'This cannot be undone.',
    'delete': 'Delete',
    'kuriDeleted': 'Kuri deleted.',
    'started': 'Started',
    'unknown': 'Unknown',
    'confirmed': 'Confirmed',
    'pendingReview': 'Pending review',
    'rejected': 'Rejected',
    'notSubmitted': 'Not submitted',
    'noMonthsYet': 'No months yet',
    'paymentsWhenStarts': 'Payments will appear here once the plan starts',
    'confirmedLower': 'confirmed',
    'pendingLower': 'pending',
    'noUpiApp': 'No UPI app found.',
    'payWithUpi': 'Pay with UPI App',
    'close': 'Close',
    'qrCode': 'QR Code',
    'payTo': 'Pay To',
    'upiIdCopied': 'UPI ID copied!',
    'locked': 'Locked',
    'pay': 'Pay',
    'note': 'Note:',
    'noteForRejection': 'Note (for rejection)',
    'submitPayment': 'Submit Payment',
    'amount': 'Amount:',
    'transactionId': 'Transaction ID (optional)',
    'upiReference': 'UPI transaction reference',
    'uploadReceipt': 'Upload Receipt *',
    'receiptUploaded': 'Receipt uploaded',
    'receiptRequired': 'Receipt image is required.',
    'failedToPickFile': 'Failed to pick file:',
    'paymentSubmitted': 'Payment submitted for review!',
    'upiIdRequired': 'UPI ID is required.',
    'settingsSaved': 'Settings saved!',
    'paymentSettings': 'PAYMENT SETTINGS',
    'currentQr': 'Current QR Code:',
    'change': 'Change',
    'upload': 'Upload',
    'removeQr': 'Remove QR Code',
    'saveSettings': 'Save Settings',
    'optional': '(optional)',
    'kuriType': 'Kuri Type',
    'lelamKuri': 'Lelam Kuri (Auction)',
    'changathaKuri': 'Changatha Kuri (Lottery)',
    'moopanCommissionLabel': "Moopan's Commission (%)",
    'maxDiscountLabel': 'Max Discount (%)',
    'prizePaidWithinLabel': 'Prize Paid Within (days)',
    'auction': 'Auction',
    'openAuction': 'Open Auction',
    'auctionOpen': 'Auction Open',
    'auctionClosed': 'Auction Closed',
    'placeBid': 'Place Bid',
    'yourBid': 'Bid placed!',
    'discountAmount': 'Discount Amount (₹)',
    'closeAuction': 'Close & Declare Winner',
    'noBids': 'No bids yet',
    'winner': 'Winner',
    'prizeAmount': 'Prize Amount',
    'dividendPerMember': 'Dividend / member',
    'bidExceedsMax': 'Bid exceeds maximum allowed discount',
    'drawWinner': 'Draw Winner',
    'auctionAlreadyWon': 'Already won an auction',
    'selectWinner': 'Select Winner',
    'auctionHistory': 'AUCTION HISTORY',
    'noAuctionYet': 'No auction',
    'openAuctionFor': 'Open auction for',
    'commission': 'Commission',
    'pool': 'Pool',
    'manageParticipants': 'MANAGE PARTICIPANTS',
    'remove': 'Remove',
    'participantAdded': 'Participant added.',
    'participantRemoved': 'Participant removed.',
    'cannotRemoveCreator': 'Cannot remove the creator.',
    'enterEmailToAdd': 'Enter email to add',
    // Create Kuri
    'participants_cap': 'Participants',
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
    'review': 'Review',
    'approve': 'Approve',
    'reject': 'Reject',
    'uploadQrCode': 'Upload QR Code',
    'uploadProofForMember': 'Upload Proof for Member',
    'markAsPaid': 'Mark as Paid',
    'paymentRecorded': 'Payment recorded!',
    'receiptOptional': 'Receipt (optional)',
    'transactionIdOptional': 'Transaction ID (optional)',
    'noUserFound': 'No user found with email:',
    'nameIsRequired': 'Name is required.',
    'amountRequired': 'Amount is required.',
    'validAmount': 'Enter a valid amount.',
    'kuriCreated': 'Kuri created!',
    'you': '(you)',
    'requiredFields': '* Required fields',
    'failedToPickImage': 'Failed to pick image:',
    // Language
    'language': 'Language',
    'english': 'English',
    'malayalam': 'Malayalam',
  };

  static const _ml = {
    // App identity
    'appName': 'കുറി',
    'appSubtitle': 'നിങ്ങളുടെ കുറികൾ ട്രാക്ക് ചെയ്യൂ',
    // Auth
    'logIn': 'ലോഗിൻ',
    'login': 'ലോഗിൻ',
    'signUp': 'സൈൻ അപ്പ്',
    'createAccount': 'അക്കൗണ്ട് ഉണ്ടാക്കൂ',
    'fullName': 'പൂർണ്ണ നാമം',
    'emailAddress': 'ഇമെയിൽ വിലാസം',
    'sendCode': 'കോഡ് അയക്കൂ',
    'or': 'അല്ലെങ്കിൽ',
    'back': 'തിരിച്ച്',
    'checkYourEmail': 'ഇമെയിൽ നോക്കൂ',
    'weSentCodeTo': 'ഒരു 6-അക്ക കോഡ് ഇതിലേക്ക് അയച്ചു',
    'didntReceive': 'ലഭിച്ചില്ലേ?',
    'resend': 'വീണ്ടും അയക്കൂ',
    'verify': 'സ്ഥിരീകരിക്കൂ',
    'continueWithGoogle': 'Google-ൽ തുടരൂ',
    'enterEmailError': 'ദയവായി ഇമെയിൽ വിലാസം നൽകൂ.',
    'validEmailError': 'സാധുതയുള്ള ഇമെയിൽ വിലാസം നൽകൂ.',
    'enterNameError': 'ദയവായി പൂർണ്ണ നാമം നൽകൂ.',
    'noAccountError': 'ഈ ഇമെയിലിൽ അക്കൗണ്ട് കണ്ടെത്തിയില്ല. ദയവായി സൈൻ അപ്പ് ചെയ്യൂ.',
    'somethingWentWrong': 'എന്തോ തെറ്റ് സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കൂ.',
    'newCodeSent': 'പുതിയ കോഡ് അയച്ചു!',
    'invalidCode': 'അസാധുവായ അല്ലെങ്കിൽ കാലഹരണപ്പെട്ട കോഡ്. വീണ്ടും ശ്രമിക്കൂ.',
    'nameRequiredToCreate': 'അക്കൗണ്ട് ഉണ്ടാക്കാൻ പേര് ആവശ്യമാണ്.',
    'enterOtpError': 'ദയവായി 6-അക്ക കോഡ് നൽകൂ.',
    // Navigation
    'home': 'ഹോം',
    'receipts': 'രസീതുകൾ',
    'settings': 'ക്രമീകരണങ്ങൾ',
    // List screen
    'signOut': 'ഒഴിവ്',
    'switchLanguage': 'ഭാഷ മാറ്റൂ',
    'toggleTheme': 'തീം മാറ്റൂ',
    'account': 'അക്കൗണ്ട്',
    'deleteAccount': 'അക്കൗണ്ട് ഇല്ലാതാക്കൂ',
    'deleteAccountWarning': 'ഇത് നിങ്ങളുടെ അക്കൗണ്ടും എല്ലാ ഡേറ്റയും ശാശ്വതമായി ഇല്ലാതാക്കും. ഇത് പഴയ നിലയിൽ കൊണ്ടുവരാൻ കഴിയില്ല.',
    'accountDeleted': 'അക്കൗണ്ട് ഇല്ലാതാക്കി.',
    'noKurisYet': 'ഇതുവരെ കുറികൾ ഇല്ല',
    'createFirstPlan': 'നിങ്ങളുടെ ആദ്യ കുറി ഉണ്ടാക്കൂ',
    'notifications': 'അറിയിപ്പുകൾ',
    'noNotifications': 'അറിയിപ്പുകൾ ഇല്ല',
    'allCaughtUp': 'എല്ലാം കൃത്യമാണ്!',
    'creator': 'മൂപ്പൻ',
    'participant': 'അംഗം',
    'participants': 'അംഗങ്ങൾ',
    // Kuri detail
    'loading': 'ലോഡ് ചെയ്യുന്നു...',
    'error': 'പിഴവ്',
    'kuriNotFound': 'കുറി കണ്ടെത്തിയില്ല',
    'deleteKuri': 'കുറി ഇല്ലാതാക്കൂ',
    'areYouSureDelete': 'ഇല്ലാതാക്കണം എന്ന് ഉറപ്പാണോ',
    'cannotUndo': 'ഇത് പഴയ നിലയിൽ കൊണ്ടുവരാൻ കഴിയില്ല.',
    'delete': 'ഇല്ലാതാക്കൂ',
    'kuriDeleted': 'കുറി ഇല്ലാതാക്കി.',
    'started': 'ആരംഭിച്ചു',
    'unknown': 'അജ്ഞാതം',
    'confirmed': 'സ്ഥിരീകരിച്ചു',
    'pendingReview': 'അവലോകനം കാത്തിരിക്കുന്നു',
    'rejected': 'നിരസിച്ചു',
    'notSubmitted': 'സമർപ്പിച്ചില്ല',
    'noMonthsYet': 'ഇതുവരെ മാസങ്ങൾ ഇല്ല',
    'paymentsWhenStarts': 'പ്ലാൻ ആരംഭിക്കുമ്പോൾ പേമെന്റുകൾ ഇവിടെ കാണാം',
    'confirmedLower': 'സ്ഥിരീകരിച്ചു',
    'pendingLower': 'കാത്തിരിക്കുന്നു',
    'noUpiApp': 'UPI ആപ്പ് കണ്ടെത്തിയില്ല.',
    'payWithUpi': 'UPI ആപ്പ് ഉപയോഗിച്ച് അടക്കൂ',
    'close': 'അടക്കൂ',
    'qrCode': 'QR കോഡ്',
    'payTo': 'അടക്കേണ്ടത്',
    'upiIdCopied': 'UPI ID പകർത്തി!',
    'locked': 'ലോക്ക് ചെയ്തു',
    'pay': 'അടക്കൂ',
    'note': 'കുറിപ്പ്:',
    'noteForRejection': 'കുറിപ്പ് (നിരാകരണത്തിന്)',
    'submitPayment': 'പേമെന്റ് സമർപ്പിക്കൂ',
    'amount': 'തുക:',
    'transactionId': 'ഇടപാട് ID (ഐച്ഛികം)',
    'upiReference': 'UPI ഇടപാട് റഫറൻസ്',
    'uploadReceipt': 'രസീത് അപ്‌ലോഡ് ചെയ്യൂ *',
    'receiptUploaded': 'രസീത് അപ്‌ലോഡ് ചെയ്തു',
    'receiptRequired': 'രസീത് ചിത്രം ആവശ്യമാണ്.',
    'failedToPickFile': 'ഫയൽ തിരഞ്ഞെടുക്കൽ പരാജയപ്പെട്ടു:',
    'paymentSubmitted': 'പേമെന്റ് അവലോകനത്തിനായി സമർപ്പിച്ചു!',
    'upiIdRequired': 'UPI ID ആവശ്യമാണ്.',
    'settingsSaved': 'ക്രമീകരണങ്ങൾ സൂക്ഷിച്ചു!',
    'paymentSettings': 'പേമെന്റ് ക്രമീകരണങ്ങൾ',
    'currentQr': 'നിലവിലെ QR കോഡ്:',
    'change': 'മാറ്റൂ',
    'upload': 'അപ്‌ലോഡ് ചെയ്യൂ',
    'removeQr': 'QR കോഡ് നീക്കൂ',
    'saveSettings': 'ക്രമീകരണങ്ങൾ സൂക്ഷിക്കൂ',
    'optional': '(ഐച്ഛികം)',
    'kuriType': 'കുറി തരം',
    'lelamKuri': 'ലേലം കുറി (ലേലം)',
    'changathaKuri': 'ചങ്ങാതി കുറി (നറുക്കെടുപ്പ്)',
    'moopanCommissionLabel': 'മൂപ്പൻ കമ്മീഷൻ (%)',
    'maxDiscountLabel': 'പരമാവധി കിഴിവ് (%)',
    'prizePaidWithinLabel': 'സമ്മാനം അടക്കേണ്ട ദിവസം',
    'auction': 'ലേലം',
    'openAuction': 'ലേലം തുറക്കൂ',
    'auctionOpen': 'ലേലം തുറന്നിരിക്കുന്നു',
    'auctionClosed': 'ലേലം അടഞ്ഞു',
    'placeBid': 'ബിഡ് ഇടൂ',
    'yourBid': 'ബിഡ് ഇട്ടു!',
    'discountAmount': 'കിഴിവ് തുക (₹)',
    'closeAuction': 'ലേലം അടക്കൂ',
    'noBids': 'ബിഡ്ഡുകൾ ഇല്ല',
    'winner': 'വിജയി',
    'prizeAmount': 'സമ്മാന തുക',
    'dividendPerMember': 'ഓരോ അംഗത്തിനും',
    'bidExceedsMax': 'ബിഡ് അനുവദനീയ പരിധി കടന്നു',
    'drawWinner': 'വിജയിയെ നിർണ്ണയിക്കൂ',
    'auctionAlreadyWon': 'ഇതിനകം ജയിച്ചു',
    'selectWinner': 'വിജയിയെ തിരഞ്ഞെടുക്കൂ',
    'auctionHistory': 'ലേലം ചരിത്രം',
    'noAuctionYet': 'ലേലം ഇല്ല',
    'openAuctionFor': 'ലേലം തുറക്കൂ',
    'commission': 'കമ്മീഷൻ',
    'pool': 'ആകെ',
    'manageParticipants': 'അംഗങ്ങളെ നിയന്ത്രിക്കൂ',
    'remove': 'നീക്കൂ',
    'participantAdded': 'അംഗം ചേർക്കപ്പെട്ടു.',
    'participantRemoved': 'അംഗം നീക്കപ്പെട്ടു.',
    'cannotRemoveCreator': 'സ്ഥാപകനെ നീക്കാൻ കഴിയില്ല.',
    'enterEmailToAdd': 'ചേർക്കാൻ ഇമെയിൽ നൽകൂ',
    // Create Kuri
    'participants_cap': 'അംഗങ്ങൾ',
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
    'review': 'അവലോകനം',
    'approve': 'അംഗീകരിക്കുക',
    'reject': 'നിരസിക്കുക',
    'uploadQrCode': 'QR കോഡ് അപ്‌ലോഡ് ചെയ്യൂ',
    'uploadProofForMember': 'അംഗത്തിനായി തെളിവ് അപ്‌ലോഡ് ചെയ്യൂ',
    'markAsPaid': 'അടച്ചതായി രേഖപ്പെടുത്തൂ',
    'paymentRecorded': 'പേമെന്റ് രേഖപ്പെടുത്തി!',
    'receiptOptional': 'രസീത് (ഐച്ഛികം)',
    'transactionIdOptional': 'ഇടപാട് ID (ഐച്ഛികം)',
    'noUserFound': 'ഈ ഇമെയിലിൽ ഉപയോക്താവ് കണ്ടെത്തിയില്ല:',
    'nameIsRequired': 'പേര് ആവശ്യമാണ്.',
    'amountRequired': 'തുക ആവശ്യമാണ്.',
    'validAmount': 'സാധുതയുള്ള തുക നൽകൂ.',
    'kuriCreated': 'കുറി ഉണ്ടാക്കി!',
    'you': '(നിങ്ങൾ)',
    'requiredFields': '* ആവശ്യമുള്ള ഫീൽഡുകൾ',
    'failedToPickImage': 'ചിത്രം തിരഞ്ഞെടുക്കൽ പരാജയപ്പെട്ടു:',
    // Language
    'language': 'ഭാഷ',
    'english': 'English',
    'malayalam': 'മലയാളം',
  };

  // Auth
  String get appName            => _t('appName');
  String get appSubtitle        => _t('appSubtitle');
  String get logIn              => _t('logIn');
  String get login              => _t('login');
  String get signUp             => _t('signUp');
  String get createAccount      => _t('createAccount');
  String get fullName           => _t('fullName');
  String get emailAddress       => _t('emailAddress');
  String get sendCode           => _t('sendCode');
  String get or                 => _t('or');
  String get back               => _t('back');
  String get checkYourEmail     => _t('checkYourEmail');
  String get weSentCodeTo       => _t('weSentCodeTo');
  String get didntReceive       => _t('didntReceive');
  String get resend             => _t('resend');
  String get verify             => _t('verify');
  String get continueWithGoogle => _t('continueWithGoogle');
  String get enterEmailError    => _t('enterEmailError');
  String get validEmailError    => _t('validEmailError');
  String get enterNameError     => _t('enterNameError');
  String get noAccountError     => _t('noAccountError');
  String get somethingWentWrong => _t('somethingWentWrong');
  String get newCodeSent        => _t('newCodeSent');
  String get invalidCode        => _t('invalidCode');
  String get nameRequiredToCreate => _t('nameRequiredToCreate');
  String get enterOtpError      => _t('enterOtpError');
  // Navigation
  String get home               => _t('home');
  String get receipts           => _t('receipts');
  String get settings           => _t('settings');
  // List
  String get account            => _t('account');
  String get deleteAccount      => _t('deleteAccount');
  String get deleteAccountWarning => _t('deleteAccountWarning');
  String get accountDeleted     => _t('accountDeleted');
  String get signOut            => _t('signOut');
  String get switchLanguage     => _t('switchLanguage');
  String get toggleTheme        => _t('toggleTheme');
  String get noKurisYet         => _t('noKurisYet');
  String get createFirstPlan    => _t('createFirstPlan');
  String get notifications      => _t('notifications');
  String get noNotifications    => _t('noNotifications');
  String get allCaughtUp        => _t('allCaughtUp');
  String get creator            => _t('creator');
  String get participant        => _t('participant');
  String get participants       => _t('participants');
  // Detail
  String get loading            => _t('loading');
  String get error              => _t('error');
  String get kuriNotFound       => _t('kuriNotFound');
  String get deleteKuri         => _t('deleteKuri');
  String get areYouSureDelete   => _t('areYouSureDelete');
  String get cannotUndo         => _t('cannotUndo');
  String get delete             => _t('delete');
  String get kuriDeleted        => _t('kuriDeleted');
  String get started            => _t('started');
  String get unknown            => _t('unknown');
  String get confirmed          => _t('confirmed');
  String get pendingReview      => _t('pendingReview');
  String get rejected           => _t('rejected');
  String get notSubmitted       => _t('notSubmitted');
  String get noMonthsYet        => _t('noMonthsYet');
  String get paymentsWhenStarts => _t('paymentsWhenStarts');
  String get confirmedLower     => _t('confirmedLower');
  String get pendingLower       => _t('pendingLower');
  String get noUpiApp           => _t('noUpiApp');
  String get payWithUpi         => _t('payWithUpi');
  String get close              => _t('close');
  String get qrCode             => _t('qrCode');
  String get payTo              => _t('payTo');
  String get upiIdCopied        => _t('upiIdCopied');
  String get locked             => _t('locked');
  String get pay                => _t('pay');
  String get note               => _t('note');
  String get noteForRejection   => _t('noteForRejection');
  String get submitPayment      => _t('submitPayment');
  String get amount             => _t('amount');
  String get transactionId      => _t('transactionId');
  String get upiReference       => _t('upiReference');
  String get uploadReceipt      => _t('uploadReceipt');
  String get receiptUploaded    => _t('receiptUploaded');
  String get receiptRequired    => _t('receiptRequired');
  String get failedToPickFile   => _t('failedToPickFile');
  String get paymentSubmitted   => _t('paymentSubmitted');
  String get upiIdRequired      => _t('upiIdRequired');
  String get settingsSaved      => _t('settingsSaved');
  String get paymentSettings    => _t('paymentSettings');
  String get currentQr          => _t('currentQr');
  String get change             => _t('change');
  String get upload             => _t('upload');
  String get removeQr           => _t('removeQr');
  String get saveSettings       => _t('saveSettings');
  String get optional           => _t('optional');
  // Kuri type / auction
  String get kuriType              => _t('kuriType');
  String get lelamKuri             => _t('lelamKuri');
  String get changathaKuri         => _t('changathaKuri');
  String get moopanCommissionLabel => _t('moopanCommissionLabel');
  String get maxDiscountLabel      => _t('maxDiscountLabel');
  String get prizePaidWithinLabel  => _t('prizePaidWithinLabel');
  String get auction               => _t('auction');
  String get openAuction           => _t('openAuction');
  String get auctionOpen           => _t('auctionOpen');
  String get auctionClosed         => _t('auctionClosed');
  String get placeBid              => _t('placeBid');
  String get yourBid               => _t('yourBid');
  String get discountAmount        => _t('discountAmount');
  String get closeAuction          => _t('closeAuction');
  String get noBids                => _t('noBids');
  String get winner                => _t('winner');
  String get prizeAmount           => _t('prizeAmount');
  String get dividendPerMember     => _t('dividendPerMember');
  String get bidExceedsMax         => _t('bidExceedsMax');
  String get drawWinner            => _t('drawWinner');
  String get auctionAlreadyWon     => _t('auctionAlreadyWon');
  String get selectWinner          => _t('selectWinner');
  String get auctionHistory        => _t('auctionHistory');
  String get noAuctionYet          => _t('noAuctionYet');
  String get openAuctionFor        => _t('openAuctionFor');
  String get commission            => _t('commission');
  String get pool                  => _t('pool');
  // Create
  String get participantsCap    => _t('participants_cap');
  String get planName           => _t('planName');
  String get monthlyAmount      => _t('monthlyAmount');
  String get startDate          => _t('startDate');
  String get upiId              => _t('upiId');
  String get paymentQr          => _t('paymentQr');
  String get totalCollected     => _t('totalCollected');
  String get yourPaid           => _t('yourPaid');
  String get planTotal          => _t('planTotal');
  String get paymentSummary     => _t('paymentSummary');
  String get createKuri         => _t('createKuri');
  String get addParticipant     => _t('addParticipant');
  String get manageParticipants => _t('manageParticipants');
  String get remove             => _t('remove');
  String get participantAdded   => _t('participantAdded');
  String get participantRemoved => _t('participantRemoved');
  String get cannotRemoveCreator=> _t('cannotRemoveCreator');
  String get enterEmailToAdd    => _t('enterEmailToAdd');
  String get submit             => _t('submit');
  String get cancel             => _t('cancel');
  String get review             => _t('review');
  String get approve            => _t('approve');
  String get reject             => _t('reject');
  String get uploadQrCode           => _t('uploadQrCode');
  String get uploadProofForMember   => _t('uploadProofForMember');
  String get markAsPaid             => _t('markAsPaid');
  String get paymentRecorded        => _t('paymentRecorded');
  String get receiptOptional        => _t('receiptOptional');
  String get transactionIdOptional  => _t('transactionIdOptional');
  String get noUserFound            => _t('noUserFound');
  String get nameIsRequired     => _t('nameIsRequired');
  String get amountRequired     => _t('amountRequired');
  String get validAmount        => _t('validAmount');
  String get kuriCreated        => _t('kuriCreated');
  String get you                => _t('you');
  String get requiredFields     => _t('requiredFields');
  String get failedToPickImage  => _t('failedToPickImage');
  // Language
  String get language           => _t('language');
  String get english            => _t('english');
  String get malayalam          => _t('malayalam');

  String _t(String key) {
    final map = locale == AppLocale.malayalam ? _ml : _en;
    return map[key] ?? key;
  }
}

extension L10nContext on BuildContext {
  AppL10n l10n(WidgetRef ref) => AppL10n(ref.watch(localeProvider));
}
