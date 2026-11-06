import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../freeze/presentation/widgets/fz_widgets.dart';
import '../controllers/auth_controller.dart';
import 'widgets/password_eye.dart';

/// FRAMES `auth-signup` — Create an account.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    // Local check first, so a typo in the confirm field never costs a round
    // trip (or, worse, an account with a password nobody meant to set).
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Those two passwords don't match."),
        ),
      );
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).signUp(
          name: _email.text.split('@').first,
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    if (ok) {
      unawaited(context.push(Routes.verify));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(authErrorMessage(ref.read(authControllerProvider).error)),
        ),
      );
    }
  }

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
              Align(
                alignment: Alignment.centerLeft,
                child: FzHeadButton(icon: 'back', fill: FzFill.well, onTap: () => context.pop()),
              ),
              const SizedBox(height: 16),
              Text('Create account', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2, color: colors.text)),
              const SizedBox(height: 4),
              Text(
                // A guest's account is upgraded in place, so this is a promise
                // the sign-up can keep.
                ref.watch(isGuestProvider)
                    ? "Everything you've made as a guest comes with you"
                    : 'Save your streak, grades & plan',
                style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.4, color: colors.textMed),
              ),
              const SizedBox(height: 22),
              const FieldLabel('Email'),
              AppTextField(controller: _email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              const FieldLabel('Password'),
              AppTextField(
                controller: _password,
                obscureText: _obscure1,
                suffix: PasswordEye(obscured: _obscure1, onTap: () => setState(() => _obscure1 = !_obscure1)),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Confirm password'),
              AppTextField(
                controller: _confirm,
                obscureText: _obscure2,
                suffix: PasswordEye(obscured: _obscure2, onTap: () => setState(() => _obscure2 = !_obscure2)),
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: busy ? 'Creating…' : 'Create account →', onPressed: busy ? null : _create),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.go(Routes.signin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                        children: [
                          TextSpan(
                            text: 'Sign in',
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
