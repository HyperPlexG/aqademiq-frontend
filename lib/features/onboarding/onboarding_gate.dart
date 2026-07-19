import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env/env.dart';
import '../../core/router/app_router.dart';
import '../../data/repositories/profile_repository.dart';

/// Routes the user after a successful sign-in / session restore: into the
/// onboarding flow if the account hasn't finished it yet, otherwise straight
/// to the app. Guests and mock mode skip onboarding. On any error we fall
/// through to the app rather than trapping the user on the auth wall.
Future<void> routeAfterAuth(BuildContext context, WidgetRef ref) async {
  var target = Routes.plan;
  if (!Env.useMocks && Env.hasSupabase) {
    try {
      final skip = await ref.read(profileRepositoryProvider).shouldSkipOnboarding();
      if (!skip) target = Routes.obAge;
    } on Object {
      // Network/transient failure — send them into the app.
    }
  }
  if (context.mounted) context.go(target);
}
