import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../l10n.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final String appName;
  final String appSubtitle;
  const AuthScreen({super.key, required this.appName, required this.appSubtitle});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _emailFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }
    if (!_isLogin && _nameCtrl.text.trim().isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final data = await dataService.getData();
      if (_isLogin) {
        final user = data.users.firstWhere(
          (u) => u.email.trim().toLowerCase() == email,
          orElse: () => AppUser(id: '', name: '', email: ''),
        );
        if (user.id.isEmpty) {
          _showError('No account found. Please sign up first.');
          return;
        }
        ref.read(appDataProvider.notifier).updateState(data);
        await ref.read(currentUserProvider.notifier).setUser(user);
      } else {
        final user = await dataService.createUser(_nameCtrl.text.trim(), email);
        final freshData = await dataService.getData();
        ref.read(appDataProvider.notifier).updateState(freshData);
        await ref.read(currentUserProvider.notifier).setUser(user);
      }
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.colors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    final l10n = AppL10n(ref.watch(localeProvider));

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              // Theme toggle top-right
              Positioned(
                top: 8, right: 16,
                child: IconButton(
                  icon: Icon(
                    themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: c.textMuted,
                  ),
                  onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                  tooltip: 'Toggle theme',
                ),
              ),

              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App icon
                        Center(
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: c.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              color: c.primary,
                              size: 42,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // App name
                        Text(
                          l10n.appName,
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
                          l10n.appSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textMuted, fontSize: 15),
                        ),
                        const SizedBox(height: 40),

                        // Login / Sign Up toggle (segmented control style)
                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _SegmentBtn(
                                label: 'Login',
                                active: _isLogin,
                                primaryFg: c.primaryFg,
                                activeBg: c.primary,
                                inactiveFg: c.textMuted,
                                onTap: () {
                                  setState(() => _isLogin = true);
                                  Future.delayed(const Duration(milliseconds: 100),
                                      () => _emailFocus.requestFocus());
                                },
                              ),
                              _SegmentBtn(
                                label: 'Sign Up',
                                active: !_isLogin,
                                primaryFg: c.primaryFg,
                                activeBg: c.primary,
                                inactiveFg: c.textMuted,
                                onTap: () {
                                  setState(() => _isLogin = false);
                                  Future.delayed(const Duration(milliseconds: 100),
                                      () => _nameFocus.requestFocus());
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

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
                              // Name field (sign up only)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: _isLogin
                                    ? const SizedBox.shrink()
                                    : Column(
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
                                              labelText: 'Full Name',
                                              prefixIcon: Icon(Icons.person_outline_rounded, color: c.textMuted),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                        ],
                                      ),
                              ),

                              // Email field
                              TextField(
                                controller: _emailCtrl,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.email],
                                style: TextStyle(color: c.text),
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  prefixIcon: Icon(Icons.email_outlined, color: c.textMuted),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Submit button
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: c.primaryFg,
                                          ),
                                        )
                                      : Text(_isLogin ? 'Login' : 'Create Account'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Switch hint
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? "Don't have an account? " : 'Already have an account? ',
                              style: TextStyle(color: c.textMuted, fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? 'Sign Up' : 'Login',
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}

// ── Segmented toggle button ─────────────────────────────────────────────────

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color primaryFg, activeBg, inactiveFg;
  final VoidCallback onTap;

  const _SegmentBtn({
    required this.label,
    required this.active,
    required this.primaryFg,
    required this.activeBg,
    required this.inactiveFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? primaryFg : inactiveFg,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
