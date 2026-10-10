import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import 'auth_controller.dart';
import 'server_settings.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_email.text, _password.text);
      // Router redirects to home once auth state changes.
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _fillDemo(String email, String password) {
    _email.text = email;
    _password.text = password;
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dark = theme.brightness == Brightness.dark;
    final brand = dark ? const Color(0xFF15372C) : const Color(0xFF1F5C4A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: brand,
        body: LayoutBuilder(
          builder: (context, viewport) {
            final tall = viewport.maxHeight >= 720;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        tall ? 40 : 20,
                        28,
                        tall ? 36 : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tall) ...[
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                          Text(
                            'StockFlow',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          if (tall) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Receive, issue and count stock\nfrom the warehouse floor.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome back',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const Key('login_email'),
                                  controller: _email,
                                  enabled: !_submitting,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!_emailRe.hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  key: const Key('login_password'),
                                  controller: _password,
                                  enabled: !_submitting,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Please enter your password'
                                      : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  _ErrorBanner(message: _error!),
                                ],
                                const SizedBox(height: 24),
                                FilledButton(
                                  key: const Key('login_submit'),
                                  onPressed: _submitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                  ),
                                  child: _submitting
                                      ? const SizedBox.square(
                                          dimension: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text('Sign in'),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Demo accounts',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // Seeded demo accounts, one per role.
                                    for (final (label, icon, email, pw)
                                        in const [
                                          (
                                            'Admin',
                                            Icons.admin_panel_settings_outlined,
                                            'admin@stockflow.dev',
                                            'Admin1234!',
                                          ),
                                          (
                                            'Staff',
                                            Icons.person_outline,
                                            'staff@stockflow.dev',
                                            'Staff1234!',
                                          ),
                                          (
                                            'Technician',
                                            Icons.engineering_outlined,
                                            'tech@stockflow.dev',
                                            'Tech1234!',
                                          ),
                                          (
                                            'Supervisor',
                                            Icons.verified_user_outlined,
                                            'supervisor@stockflow.dev',
                                            'Super1234!',
                                          ),
                                        ])
                                      ActionChip(
                                        key: Key('demo_${label.toLowerCase()}'),
                                        avatar: Icon(icon, size: 18),
                                        label: Text(label),
                                        onPressed: _submitting
                                            ? null
                                            : () => _fillDemo(email, pw),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: ServerSettingsButton(
                                    enabled: !_submitting,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ColoredBox(color: theme.colorScheme.surface),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: const Key('login_error'),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
