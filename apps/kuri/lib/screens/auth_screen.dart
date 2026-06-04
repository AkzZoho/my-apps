import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

enum _Step { email, otp }

class AuthScreen extends ConsumerStatefulWidget {
  final String appName;
  final String appSubtitle;
  const AuthScreen({super.key, required this.appName, required this.appSubtitle});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _Step _step = _Step.email;
  bool _isSignUp = false;
  bool _loading = false;
  String _otpEmail = '';
  AppL10n? _l10n;

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _otpFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _otpCtrl.dispose();
    _emailFocus.dispose();
    _nameFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.googleSignIn();
      await _finishAuth(email: result.email, name: result.name);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showError(_l10n!.enterEmailError);
      return;
    }
    if (!email.contains('@')) {
      _showError(_l10n!.validEmailError);
      return;
    }
    if (_isSignUp && _nameCtrl.text.trim().isEmpty) {
      _showError(_l10n!.enterNameError);
      return;
    }

    if (!_isSignUp) {
      setState(() => _loading = true);
      try {
        final data = await dataService.getData();
        final exists = data.users.any(
          (u) => u.email.trim().toLowerCase() == email,
        );
        if (!exists) {
          _showError(_l10n!.noAccountError);
          return;
        }
      } catch (e) {
        _showError(_l10n!.somethingWentWrong);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    setState(() => _loading = true);
    try {
      await AuthService.sendOtp(email, widget.appName);
      if (mounted) {
        setState(() {
          _otpEmail = email;
          _step = _Step.otp;
          _otpCtrl.clear();
        });
        Future.delayed(const Duration(milliseconds: 150),
            () => _otpFocus.requestFocus());
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 6) {
      _showError(_l10n!.enterOtpError);
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await AuthService.verifyOtp(_otpEmail, code);
      if (!ok) {
        if (mounted) _showError(_l10n!.invalidCode);
        return;
      }
      final name = _isSignUp ? _nameCtrl.text.trim() : '';
      await _finishAuth(email: _otpEmail, name: name);
    } catch (e) {
      if (mounted) _showError(_l10n!.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _loading = true);
    try {
      await AuthService.sendOtp(_otpEmail, widget.appName);
      if (mounted) {
        _otpCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n!.newCodeSent)),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finishAuth({required String email, String name = ''}) async {
    final data = await dataService.getData();
    final existing = data.users.firstWhere(
      (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase(),
      orElse: () => AppUser(id: '', name: '', email: ''),
    );
    AppUser user;
    if (existing.id.isNotEmpty) {
      user = existing;
    } else {
      if (name.trim().isEmpty) {
        throw Exception(_l10n!.nameRequiredToCreate);
      }
      user = await dataService.createUser(name.trim(), email);
    }
    final freshData = await dataService.getData();
    ref.read(appDataProvider.notifier).updateState(freshData);
    await ref.read(currentUserProvider.notifier).setUser(user);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.colors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    _l10n = AppL10n(ref.watch(localeProvider));
    final l10n = _l10n!;

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8, right: 16,
                child: IconButton(
                  icon: Icon(
                    () {
                      final isDark = themeMode == ThemeMode.dark ||
                          (themeMode == ThemeMode.system &&
                              MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                      return isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
                    }(),
                    color: c.textMuted,
                  ),
                  onPressed: () => ref.read(themeModeProvider.notifier).toggle(MediaQuery.platformBrightnessOf(context)),
                  tooltip: l10n.toggleTheme,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: _step == _Step.email
                          ? _buildEmailStep(c, l10n)
                          : _buildOtpStep(c, l10n),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(AppColors c, AppL10n l10n) {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset('assets/kuri_icon.png', width: 80, height: 80),
        ),
        const SizedBox(height: 20),
        Text(
          widget.appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.appSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textMuted, fontSize: 15),
        ),
        const SizedBox(height: 32),

        // Google Sign-In button
        _GoogleSignInButton(
          loading: _loading,
          onPressed: _loading ? null : _handleGoogleSignIn,
          l10n: l10n,
        ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: c.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.or,
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
            ),
            Expanded(child: Divider(color: c.border)),
          ],
        ),
        const SizedBox(height: 20),

        // Login / Sign Up toggle
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _segBtn(l10n.logIn, !_isSignUp, c, () {
                setState(() => _isSignUp = false);
                Future.delayed(const Duration(milliseconds: 100),
                    () => _emailFocus.requestFocus());
              }),
              _segBtn(l10n.signUp, _isSignUp, c, () {
                setState(() => _isSignUp = true);
                Future.delayed(const Duration(milliseconds: 100),
                    () => _nameFocus.requestFocus());
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Form card
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _isSignUp
                    ? Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            style: TextStyle(color: c.text),
                            onSubmitted: (_) => _emailFocus.requestFocus(),
                            decoration: InputDecoration(
                              labelText: l10n.fullName,
                              prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                  color: c.textMuted),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              TextField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: c.text),
                onSubmitted: (_) => _sendCode(),
                decoration: InputDecoration(
                  labelText: l10n.emailAddress,
                  prefixIcon:
                      Icon(Icons.email_outlined, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.primaryFg),
                        )
                      : Text(l10n.sendCode),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(AppColors c, AppL10n l10n) {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _step = _Step.email;
                      _otpCtrl.clear();
                    }),
            icon: Icon(Icons.arrow_back_rounded, size: 18, color: c.textMuted),
            label: Text(l10n.back, style: TextStyle(color: c.textMuted)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: c.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read_outlined,
                color: c.primary, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.checkYourEmail,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.text, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.weSentCodeTo}\n$_otpEmail',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _otpCtrl,
                focusNode: _otpFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                onChanged: (v) {
                  if (v.length == 6) _verifyOtp();
                },
                onSubmitted: (_) => _verifyOtp(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: TextStyle(
                    color: c.border,
                    fontSize: 28,
                    letterSpacing: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.primaryFg),
                        )
                      : Text(l10n.verify),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${l10n.didntReceive} ',
                style: TextStyle(color: c.textMuted, fontSize: 14)),
            GestureDetector(
              onTap: _loading ? null : _resendCode,
              child: Text(
                l10n.resend,
                style: TextStyle(
                  color: _loading ? c.textMuted : c.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segBtn(String label, bool active, AppColors c, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? c.primaryFg : c.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  final AppL10n l10n;

  const _GoogleSignInButton({required this.loading, this.onPressed, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: c.border),
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.continueWithGoogle,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
