import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../models.dart';
import '../providers/providers.dart';
import '../services/data_service.dart';
import '../widgets/common.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  // Login
  final _loginEmailCtrl = TextEditingController();

  // Signup
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _loginEmailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      showError(context, 'Please enter your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await dataService.getData();
      final user = data.users.firstWhere(
        (u) => u.email.trim().toLowerCase() == email,
        orElse: () => AppUser(id: '', name: '', email: ''),
      );
      if (user.id.isEmpty) {
        if (mounted) showError(context, 'No account found with this email. Please sign up.');
      } else {
        ref.read(appDataProvider.notifier).updateState(data);
        await ref.read(currentUserProvider.notifier).setUser(user);
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signup() async {
    final name = _signupNameCtrl.text.trim();
    final email = _signupEmailCtrl.text.trim().toLowerCase();
    if (name.isEmpty) {
      showError(context, 'Please enter your name.');
      return;
    }
    if (email.isEmpty) {
      showError(context, 'Please enter your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await dataService.createUser(name, email);
      final data = await dataService.getData();
      ref.read(appDataProvider.notifier).updateState(data);
      await ref.read(currentUserProvider.notifier).setUser(user);
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LoadingOverlay(
          loading: _loading,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Logo / Title
                    const Icon(Icons.currency_rupee, color: primaryColor, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Kuri',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track your savings plans',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            tabs: const [Tab(text: 'Login'), Tab(text: 'Sign Up')],
                            indicator: BoxDecoration(
                              color: primaryColor.withOpacity(0.15),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: SizedBox(
                              height: 200,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Login tab
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: _loginEmailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        style: const TextStyle(color: textColor),
                                        decoration: const InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: Icon(Icons.email_outlined, color: textMuted),
                                        ),
                                        onSubmitted: (_) => _login(),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _loading ? null : _login,
                                        child: const Text('Login'),
                                      ),
                                    ],
                                  ),
                                  // Signup tab
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: _signupNameCtrl,
                                        style: const TextStyle(color: textColor),
                                        decoration: const InputDecoration(
                                          labelText: 'Full Name',
                                          prefixIcon: Icon(Icons.person_outline, color: textMuted),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _signupEmailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        style: const TextStyle(color: textColor),
                                        decoration: const InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: Icon(Icons.email_outlined, color: textMuted),
                                        ),
                                        onSubmitted: (_) => _signup(),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _loading ? null : _signup,
                                        child: const Text('Create Account'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
