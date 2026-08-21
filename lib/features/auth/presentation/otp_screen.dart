import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../shared/widgets/circle_back_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';
import 'widgets/otp_field.dart';

/// FRAMES `auth-otp` — OTP verification → onboarding.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _resendSeconds = 24;

  String _code = '';
  Timer? _ticker;
  int _cooldown = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6) return;
    final ok = await ref.read(authControllerProvider.notifier).verify(_code);
    if (!mounted) return;
    if (ok) {
      // A recovery code proves the address, it does not finish anything: the
      // account still has no usable password until the next screen sets one.
      // Sending it to onboarding instead would leave that half-done.
      if (ref.read(authRepositoryProvider).isRecoveryPending) {
        context.go(Routes.resetPassword);
      } else {
        context.go(Routes.obAge);
      }
    } else {
      _showError(ref.read(authControllerProvider).error);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final ok = await ref.read(authControllerProvider.notifier).resend();
    if (!mounted) return;
    if (ok) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code is on its way.')),
      );
    } else {
      _showError(ref.read(authControllerProvider).error);
    }
  }

  void _showError(Object? error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(authErrorMessage(error)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final busy = ref.watch(authControllerProvider).isLoading;
    final email = ref.read(authRepositoryProvider).pendingEmail ?? 'your email';
    final canResend = _cooldown == 0 && !busy;

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
                child: CircleBackButton(onTap: () => context.pop()),
              ),
              const SizedBox(height: 20),
              Text(
                "Verify it's you",
                style: AppText.sans(
                  size: 28,
                  weight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: 'We sent a 6-digit code to\n',
                  style: AppText.sans(size: 12.5, height: 1.6, color: colors.textMed),
                  children: [
                    TextSpan(
                      text: email,
                      style: AppText.sans(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              OtpField(
                autofocus: true,
                onChanged: (v) => setState(() => _code = v),
                onCompleted: (v) {
                  setState(() => _code = v);
                  if (!busy) unawaited(_verify());
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: busy ? 'Verifying…' : 'Verify →',
                onPressed: (busy || _code.length != 6) ? null : _verify,
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: canResend ? _resend : null,
                  child: Text.rich(
                    TextSpan(
                      text: "Didn't get a code? ",
                      style: AppText.sans(size: 11.5, height: 1.7, color: colors.textMed),
                      children: [
                        TextSpan(
                          text: canResend ? 'Resend' : 'Resend in 0:${_cooldown.toString().padLeft(2, '0')}',
                          style: AppText.sans(
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: canResend ? colors.accent : colors.textMed,
                          ),
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
