import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../onboarding/onboarding_gate.dart';
import '../controllers/auth_controller.dart';

/// Final step of a password reset: choose the new password.
///
/// Reached only after a recovery OTP has been verified, so a session already
/// exists — this screen is just `updateUser(password:)` with a confirmation
/// field.
///
/// It matters beyond forgotten passwords. 40% of real accounts were created with
/// Apple or Google and have no email identity at all, which is why signing up
/// with their own address silently did nothing and signing in said "invalid
/// credentials". Setting a password here CREATES that identity, so this is the
/// one route by which those users ever get an email login.
///
/// Deliberately has no back button: going back would strand a live recovery
/// session on the sign-in screen with no password set.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _minLength = 8;

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Local check first, so an obvious mismatch never costs a round trip.
  String? _validate() {
    if (_password.text.length < _minLength) {
      return 'Use at least $_minLength characters.';
    }
    if (_password.text != _confirm.text) return "Those two don't match.";
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _error = null);

    final ok = await ref
        .read(authControllerProvider.notifier)
        .setPassword(_password.text);
    if (!mounted) return;

    if (!ok) {
      setState(() =>
          _error = authErrorMessage(ref.read(authControllerProvider).error));
      return;
    }
    // Straight into the app (or onboarding if it was never finished) — the
    // recovery already signed them in, so a trip back to the sign-in wall would
    // just ask for the password they set two seconds ago.
    await routeAfterAuth(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = ref.watch(authControllerProvider).isLoading;
    final email = ref.read(authRepositoryProvider).pendingEmail;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set a new password',
                style: AppText.sans(size: 27, weight: FontWeight.w800, color: colors.text),
              ),
              const SizedBox(height: 6),
              Text(
                email == null
                    ? 'Choose a password for your account.'
                    : 'Choose a password for $email.',
                style: AppText.sans(size: 12, height: 1.5, color: colors.textMed),
              ),
              const SizedBox(height: 22),
              const FieldLabel('New password'),
              AppTextField(
                controller: _password,
                obscureText: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 17,
                    color: colors.textMed,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 12),
              const FieldLabel('Confirm password'),
              AppTextField(controller: _confirm, obscureText: _obscure),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: AppText.sans(size: 11.5, height: 1.45, color: colors.danger),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: busy ? 'Saving…' : 'Save password',
                onPressed: busy ? null : () => unawaited(_save()),
              ),
              const SizedBox(height: 12),
              Text(
                "You'll be signed in straight away.",
                textAlign: TextAlign.center,
                style: AppText.sans(size: 11, color: colors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
