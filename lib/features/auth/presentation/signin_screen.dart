import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../freeze/presentation/widgets/fz_widgets.dart';
import '../../onboarding/onboarding_gate.dart';
import '../controllers/auth_controller.dart';
import 'widgets/password_eye.dart';
import 'widgets/sso_buttons.dart';

/// FRAMES `auth` — Sign in (email + password, with SSO).
class SigninScreen extends ConsumerStatefulWidget {
  const SigninScreen({super.key});

  @override
  ConsumerState<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends ConsumerState<SigninScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!mounted) return;
    if (ok) {
      await routeAfterAuth(context, ref);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(authErrorMessage(ref.read(authControllerProvider).error)),
        ),
      );
    }
  }

  /// Email a reset code for whatever is in the email field.
  ///
  /// Uses that field rather than opening its own prompt: it is directly above
  /// this link and usually already filled. For an Apple- or Google-only account
  /// this is the only way to ever obtain an email login, since completing the
  /// reset creates the email identity it never had.
  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (email.isEmpty || !email.contains('@')) {
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Enter your email above first, then tap Forgot password.'),
      ));
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted) return;

    if (!ok) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(authErrorMessage(ref.read(authControllerProvider).error)),
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('If $email has an account, a reset code is on its way.'),
    ));
    await context.push(Routes.verify);
  }

  Future<void> _appleSignIn() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithApple();
    if (!mounted) return;
    if (ok) {
      await routeAfterAuth(context, ref);
    } else if (ref.read(authControllerProvider).hasError) {
      // Cancellations leave no error, so only real failures get a snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(authErrorMessage(ref.read(authControllerProvider).error)),
        ),
      );
    }
  }

  /// Apple sign-in is native to Apple platforms (see [ssoAppleAvailable]).
  bool get _appleAvailable => ssoAppleAvailable;

  Future<void> _googleSignIn() async {
    final ok = await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      await routeAfterAuth(context, ref);
    } else if (ref.read(authControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(authErrorMessage(ref.read(authControllerProvider).error)),
        ),
      );
    }
  }

  /// Hidden until the client ids are configured — App Review 7d5244b9 (see
  /// [ssoGoogleAvailable]).
  bool get _googleAvailable => ssoGoogleAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sign-up and OTP both have one; this screen did not, so anything
              // that wedged here left no way out at all.
              Align(
                alignment: Alignment.centerLeft,
                child: FzHeadButton(icon: 'back', fill: FzFill.well, onTap: () => context.pop()),
              ),
              const SizedBox(height: 16),
              Text('Welcome.', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2, color: colors.text)),
              const SizedBox(height: 4),
              Text(
                'Sign in to continue',
                style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
              ),
              const SizedBox(height: 22),
              if (_appleAvailable) ...[
                SsoButton(
                  provider: SsoProvider.apple,
                  label: 'Sign in with Apple',
                  onTap: busy ? null : _appleSignIn,
                ),
                SizedBox(height: _googleAvailable ? 10 : 18),
              ],
              if (_googleAvailable) ...[
                SsoButton(
                  provider: SsoProvider.google,
                  label: 'Sign in with Google',
                  onTap: busy ? null : _googleSignIn,
                ),
                const SizedBox(height: 18),
              ],
              const SsoOrDivider(),
              const SizedBox(height: 16),
              const FieldLabel('Email'),
              AppTextField(controller: _email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              const FieldLabel('Password'),
              AppTextField(
                controller: _password,
                obscureText: _obscure,
                suffix: PasswordEye(obscured: _obscure, onTap: () => setState(() => _obscure = !_obscure)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: busy ? null : () => unawaited(_forgotPassword()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Forgot password?',
                      style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(label: busy ? 'Signing in…' : 'Sign in →', onPressed: busy ? null : _signIn),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(context.push(Routes.signup)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text.rich(
                      TextSpan(
                        text: 'New here? ',
                        style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                        children: [
                          TextSpan(
                            text: 'Create an account',
                            style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text),
                          ),
                        ],
                      ),
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
