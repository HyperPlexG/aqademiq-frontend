import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env/env.dart';
import '../../core/router/app_router.dart';
import '../../core/router/pending_launch_route.dart';
import '../../data/repositories/profile_repository.dart';

/// Routes the user after a successful sign-in / session restore: into the
/// onboarding flow if the account hasn't finished it yet, otherwise straight
/// to the app. Guests and mock mode skip onboarding. On any error we fall
/// through to the app rather than trapping the user on the auth wall.
Future<void> routeAfterAuth(BuildContext context, WidgetRef ref) async {
  var target = Routes.plan;
  if (!Env.useMocks && Env.hasSupabase && !_isGuest()) {
    try {
      final skip = await ref.read(profileRepositoryProvider).shouldSkipOnboarding();
      if (!skip) target = Routes.obAge;
    } on Object {
      // Network/transient failure — send them into the app.
    }
  }
  // A widget or a Start 5 press that launched the app asked to land somewhere
  // specific. Honoured only when going into the app: an account that still
  // owes onboarding does that first.
  if (target == Routes.plan) {
    target = ref.read(pendingLaunchRouteProvider.notifier).take() ?? target;
  }
  if (context.mounted) context.go(target);
}

/// A guest, decided locally from the session rather than asked of the server.
///
/// The comment above always said guests skip onboarding, and the only check
/// was `/profile`'s `is_guest` — which the backend reads from a database column
/// that is false for a Supabase anonymous user, even though the same backend
/// reads the JWT's `is_anonymous` correctly for its own permission checks. So a
/// student who chose "Jump right in" was sent to "How old are you?" on every
/// cold launch after the first. The session in hand says what they are, works
/// offline, and costs no round trip.
bool _isGuest() =>
    Supabase.instance.client.auth.currentUser?.isAnonymous ?? false;
