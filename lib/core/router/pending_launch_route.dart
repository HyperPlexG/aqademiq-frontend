import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A destination asked for before the app was ready to go anywhere.
///
/// A widget tap or a Start 5 press cold-launches the app, and its destination
/// is known within a frame or two of Dart attaching — well before the splash
/// has decided where a returning student belongs. Navigating at that moment
/// does not stick: the splash fires 1.6s later, calls `routeAfterAuth`, and
/// `go`es to the planner over the top of it. So a Start 5 from the home screen
/// started a session the student could not see.
///
/// Parked here instead, and honoured by `routeAfterAuth` when it routes into
/// the app — never instead of onboarding a real account that still needs it.
final pendingLaunchRouteProvider =
    NotifierProvider<PendingLaunchRoute, String?>(PendingLaunchRoute.new);

class PendingLaunchRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String route) => state = route;

  /// Hand the destination over exactly once.
  String? take() {
    final route = state;
    state = null;
    return route;
  }
}
