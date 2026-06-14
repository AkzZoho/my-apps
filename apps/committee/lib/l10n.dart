import 'package:flutter/material.dart';

enum AppLocale { english, malayalam }

class AppL10n {
  final AppLocale locale;
  const AppL10n(this.locale);

  // ── App identity ──────────────────────────────────────────────────────────
  String get appName        => _s('Committee',                          'കമ്മിറ്റി');
  String get appSubtitle    => _s('Manage your savings committees',     'നിങ്ങളുടെ കമ്മിറ്റികൾ നിയന്ത്രിക്കൂ');

  // ── Auth ──────────────────────────────────────────────────────────────────
  String get logIn              => _s('Log In',                         'ലോഗിൻ');
  String get signUp             => _s('Sign Up',                        'സൈൻ അപ്പ്');
  String get login              => _s('Login',                          'ലോഗിൻ');
  String get createAccount      => _s('Create Account',                 'അക്കൗണ്ട് ഉണ്ടാക്കൂ');
  String get fullName           => _s('Full Name',                      'പൂർണ്ണ നാമം');
  String get emailAddress       => _s('Email Address',                  'ഇമെയിൽ വിലാസം');
  String get sendCode           => _s('Send Code',                      'കോഡ് അയക്കൂ');
  String get or                 => _s('or',                             'അല്ലെങ്കിൽ');
  String get back               => _s('Back',                           'തിരിച്ച്');
  String get checkYourEmail     => _s('Check your email',               'ഇമെയിൽ നോക്കൂ');
  String get weSentCodeTo       => _s('We sent a 6-digit code to',      'ഒരു 6-അക്ക കോഡ് ഇതിലേക്ക് അയച്ചു');
  String get didntReceive       => _s("Didn't receive it?",             'ലഭിച്ചില്ലേ?');
  String get resend             => _s('Resend',                         'വീണ്ടും അയക്കൂ');
  String get verify             => _s('Verify',                         'സ്ഥിരീകരിക്കൂ');
  String get continueWithGoogle => _s('Continue with Google',           'Google-ൽ തുടരൂ');
  String get enterEmailError    => _s('Please enter your email address.','ദയവായി ഇമെയിൽ വിലാസം നൽകൂ.');
  String get validEmailError    => _s('Please enter a valid email address.', 'സാധുതയുള്ള ഇമെയിൽ വിലാസം നൽകൂ.');
  String get enterNameError     => _s('Please enter your full name.',   'ദയവായി പൂർണ്ണ നാമം നൽകൂ.');
  String get noAccountError     => _s('No account found for this email. Please sign up.', 'ഈ ഇമെയിലിൽ അക്കൗണ്ട് കണ്ടെത്തിയില്ല. ദയവായി സൈൻ അപ്പ് ചെയ്യൂ.');
  String get somethingWentWrong => _s('Something went wrong. Please try again.', 'എന്തോ തെറ്റ് സംഭവിച്ചു. വീണ്ടും ശ്രമിക്കൂ.');
  String get newCodeSent        => _s('New code sent!',                 'പുതിയ കോഡ് അയച്ചു!');
  String get invalidCode        => _s('Invalid or expired code. Please try again.', 'അസാധുവായ അല്ലെങ്കിൽ കാലഹരണപ്പെട്ട കോഡ്. വീണ്ടും ശ്രമിക്കൂ.');
  String get nameRequiredToCreate => _s('Name is required to create an account.', 'അക്കൗണ്ട് ഉണ്ടാക്കാൻ പേര് ആവശ്യമാണ്.');
  String get enterOtpError      => _s('Please enter the 6-digit code.', 'ദയവായി 6-അക്ക കോഡ് നൽകൂ.');

  // ── Navigation / sections ─────────────────────────────────────────────────
  String get members          => _s('Members',          'അംഗങ്ങൾ');
  String get chat             => _s('Chat',             'ചാറ്റ്');
  String get invite           => _s('Invite',           'ക്ഷണിക്കൂ');
  String get notifications    => _s('Notifications',    'അറിയിപ്പുകൾ');
  String get settings         => _s('Settings',         'ക്രമീകരണങ്ങൾ');

  // ── Home screen ───────────────────────────────────────────────────────────
  String get myCommittees         => _s('My Committees',                      'എന്റെ കമ്മിറ്റികൾ');
  String get membersLabel         => _s('members',                            'അംഗങ്ങൾ');
  String get join                 => _s('Join',                               'ചേരൂ');
  String get create               => _s('Create',                             'ഉണ്ടാക്കൂ');
  String get noNotifications      => _s('No notifications',                   'അറിയിപ്പുകൾ ഇല്ല');
  String get allCaughtUp          => _s('You are all caught up!',             'എല്ലാം കൃത്യമാണ്!');
  String get pendingInvitations   => _s('PENDING INVITATIONS',                'കാത്തിരിക്കുന്ന ക്ഷണങ്ങൾ');
  String get codeLabel            => _s('Code:',                              'കോഡ്:');
  String get noCommitteesYet      => _s('No committees yet',                  'ഇതുവരെ കമ്മിറ്റികൾ ഇല്ല');
  String get createOrJoin         => _s('Create one or join with an invite code', 'ഒരെണ്ണം ഉണ്ടാക്കൂ അല്ലെങ്കിൽ ക്ഷണ കോഡ് ഉപയോഗിച്ച് ചേരൂ');
  String get createCommittee      => _s('Create Committee',                   'കമ്മിറ്റി ഉണ്ടാക്കൂ');
  String get joinCommittee        => _s('Join Committee',                     'കമ്മിറ്റിയിൽ ചേരൂ');
  String get joinViaInviteCode    => _s('Join via Invite Code',               'ക്ഷണ കോഡ് ഉപയോഗിച്ച് ചേരൂ');
  String get joined               => _s('Joined',                            'ചേർന്നു');
  String get committeeName        => _s('Committee Name',                     'കമ്മിറ്റി പേര്');
  String get description          => _s('Description (optional)',             'വിവരണം (ഐച്ഛികം)');
  String get inviteMemberEmail    => _s('Invite member email',                'അംഗ ഇമെയിൽ');
  String get sixCharCode          => _s('6-Character Invite Code',            '6 അക്ഷര ക്ഷണ കോഡ്');
  String get committeeNameRequired => _s('Committee name is required.',       'കമ്മിറ്റി പേര് ആവശ്യമാണ്.');
  String get enter6CharCode       => _s('Enter a 6-character invite code.',   '6 അക്ഷര ക്ഷണ കോഡ് നൽകൂ.');
  String get admin                => _s('Admin',                              'അഡ്മിൻ');
  String get memberRole           => _s('Member',                             'അംഗം');

  // ── Committee detail ──────────────────────────────────────────────────────
  String get error                => _s('Error',                              'പിഴവ്');
  String get committeeNotFound    => _s('Committee not found',                'കമ്മിറ്റി കണ്ടെത്തിയില്ല');
  String get editCommittee        => _s('Edit committee',                     'കമ്മിറ്റി തിരുത്തൂ');
  String get typeMessage          => _s('Type a message...',                  'സന്ദേശം ടൈപ്പ് ചെയ്യൂ...');
  String get noMessagesYet        => _s('No messages yet',                    'ഇതുവരെ സന്ദേശങ്ങൾ ഇല്ല');
  String get beFirstToSay         => _s('Be the first to say something!',     'ആദ്യം പറഞ്ഞ ആളാകൂ!');
  String get inviteMember         => _s('Invite Member',                      'അംഗത്തെ ക്ഷണിക്കൂ');
  String get pending              => _s('Pending',                            'കാത്തിരിക്കുന്നു');
  String get leaveCommittee       => _s('Leave Committee',                    'കമ്മിറ്റി വിടൂ');
  String get areYouSureLeave      => _s('Are you sure you want to leave',     'വിടണം എന്ন് ഉറപ്പാണോ');
  String get leave                => _s('Leave',                              'വിടൂ');
  String get youLeft              => _s('You left',                           'നിങ്ങൾ വിട്ടു');
  String get codeCopied           => _s('Code copied!',                       'കോഡ് പകർത്തി!');
  String get shareViaWhatsApp     => _s('Share via WhatsApp',                 'WhatsApp-ൽ പങ്കിടൂ');
  String get memberEmail          => _s('Member Email',                       'അംഗ ഇമെയിൽ');
  String get sendInvite           => _s('Send Invite',                        'ക്ഷണം അയക്കൂ');
  String get invitationCreated    => _s('Invitation created!',                'ക്ഷണം ഉണ്ടാക്കി!');
  String get saveChanges          => _s('Save Changes',                       'മാറ്റങ്ങൾ സൂക്ഷിക്കൂ');
  String get inviteMemberBtn      => _s('+ Invite Member',                    '+ അംഗത്തെ ക്ഷണിക്കൂ');
  String get membersSection       => _s('MEMBERS',                            'അംഗങ്ങൾ');
  String get removeMember         => _s('Remove Member',                      'അംഗത്തെ നീക്കൂ');
  String get memberRemoved        => _s('Member removed.',                    'അംഗം നീക്കി.');
  String get cancel               => _s('Cancel',                             'റദ്ദാക്കുക');
  String get toggleTheme          => _s('Toggle theme',                       'തീം മാറ്റൂ');

  // ── Language ──────────────────────────────────────────────────────────────
  String get language   => _s('Language',   'ഭാഷ');
  String get english    => 'English';
  String get malayalam  => _s('Malayalam',  'മലയാളം');

  // ── internal helper ───────────────────────────────────────────────────────
  String _s(String en, String ml) =>
      locale == AppLocale.malayalam ? ml : en;
}

extension L10nContext on BuildContext {
  // Usage: final l10n = AppL10n(ref.watch(localeProvider));
}
