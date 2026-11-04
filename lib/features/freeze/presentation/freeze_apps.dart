import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/freeze_engine.dart';
import '../domain/freeze_models.dart';
import '../providers/freeze_controller.dart';
import 'widgets/fz_widgets.dart';

/// Turns app sets into tiles the screens can draw.
///
/// Android: package names, labelled from the installed-apps list (the floor
/// by role: Phone, Messages, Maps, Wallet). iOS: nothing to label — Apple
/// gives us tokens — so screens fall back to counts.
class FreezeApps {
  const FreezeApps({required this.ios, required this.labels, required this.floor});

  final bool ios;
  final Map<String, String> labels;

  /// package → role (`phone`, `messages`, `maps`, `wallet`).
  final Map<String, String> floor;

  String nameOf(String package) {
    final role = floor[package];
    if (role != null) return FzKnownApps.floorNames[role] ?? role;
    final label = labels[package];
    if (label != null && label.isNotEmpty) return label;
    for (final a in FzKnownApps.suggested) {
      if (a.packages.contains(package)) return a.name;
    }
    final last = package.split('.').last;
    return last.isEmpty ? package : '${last[0].toUpperCase()}${last.substring(1)}';
  }

  /// The floor's glyph, for a floor app with no icon yet.
  String? glyphOf(String package) => switch (floor[package]) {
        'phone' => 'call',
        'messages' => 'chat_bubble',
        'maps' => 'map',
        'wallet' => 'account_balance_wallet',
        _ => null,
      };

  FzAppRef ref(String package) => FzAppRef(package, nameOf(package));

  List<FzAppRef> of(AppSet set) => [for (final p in set.packages) ref(p)];

  /// "Freeze 6 apps", "6 apps", "Everything but 3".
  static String countLabel(AppSet set) {
    final n = set.count;
    if (set.keepOnly) return n == 0 ? 'Everything' : 'Everything but $n';
    return n == 1 ? '1 app' : '$n apps';
  }

  /// What is frozen right now, for the hub's Frozen row (Android). Thawed
  /// apps come with their grant so the tile can show the ring.
  List<({FzAppRef app, ThawGrant? grant})> frozenNow(FreezeData d, DateTime t) {
    final seen = <String>{};
    final out = <({FzAppRef app, ThawGrant? grant})>[];
    for (final a in FreezeEngine.active(d, t)) {
      if (a.apps.keepOnly) continue;
      for (final p in a.apps.packages) {
        if (!seen.add(p) || d.groups.alwaysOpen.contains(p)) continue;
        final frozen = FreezeEngine.isFrozen(d, p, t);
        out.add((app: ref(p), grant: frozen ? null : FreezeEngine.grantFor(d, p, t)));
      }
    }
    return out;
  }
}

final freezeAppsProvider = Provider<FreezeApps>((ref) {
  final ios = ref.watch(freezePlatformProvider) == TargetPlatform.iOS;
  final installed = ref.watch(installedAppsProvider).value ?? const [];
  final floor = ref.watch(floorAppsProvider).value ?? const {};
  return FreezeApps(
    ios: ios,
    labels: {for (final a in installed) a.package: a.label},
    floor: {for (final e in floor.entries) e.value: e.key},
  );
});
