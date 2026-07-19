import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../onboarding/onboarding_gate.dart';

/// FRAMES `splash` — brand splash. Restores a persisted session on launch:
/// a signed-in user goes straight to the app (or into onboarding if it isn't
/// finished yet); otherwise on to Welcome.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      // supabase_flutter persists the session, so a returning user is already
      // signed in here — skip the sign-in wall and route into the app.
      final signedIn = !Env.useMocks &&
          Env.hasSupabase &&
          Supabase.instance.client.auth.currentSession != null;
      if (signedIn) {
        unawaited(routeAfterAuth(context, ref));
      } else {
        context.go(Routes.welcome);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', width: 150, height: 150, fit: BoxFit.contain),
                const SizedBox(height: 20),
                Text(
                  'Aqademiq',
                  style: AppText.sans(size: 34, weight: FontWeight.w800, letterSpacing: -1, color: colors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your focus sanctuary.',
                  style: AppText.sans(size: 12, letterSpacing: AppText.em(0.07, 12), color: colors.textDim),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 0 ? colors.accent : colors.textDim.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
