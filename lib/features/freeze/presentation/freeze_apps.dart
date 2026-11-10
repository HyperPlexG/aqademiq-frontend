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
/// gives us tokens — so screens show each pick through [fzTokensOf] (the
/// system draws the icon) and fall back to counts where it can't.
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

/// iOS: the token ids in a saved selection ([AppSet.iosSelection]), for
/// [FzTokenView]. Null where they can't be drawn — not iOS, iOS below 16, no
/// native side — and the screens keep their count tile. Device-local like the
/// rest of App freeze: the ids are hashes kept on the phone, never sent.
///
/// Kept for the session; whoever re-runs Apple's picker invalidates it.
// ignore: specify_nonobvious_property_types
final fzSelectionTokensProvider = FutureProvider.family<List<String>?, String>((ref, selectionId) {
  if (ref.watch(freezePlatformProvider) != TargetPlatform.iOS) return null;
  return ref.watch(appFreezeChannelProvider).selectionTokens(selectionId);
});

/// iOS: [set]'s picks as tiles — apps, categories and sites, each drawn by
/// the system. Null when there is nothing to draw (Android, no selection, no
/// token views on this phone, the ids not in yet): show the count instead.
List<FzAppRef>? fzTokensOf(WidgetRef ref, AppSet set) {
  final selection = set.iosSelection;
  if (selection == null || !ref.watch(freezeAppsProvider).ios) return null;
  final ids = ref.watch(fzSelectionTokensProvider(selection)).value;
  if (ids == null || ids.isEmpty) return null;
  return [for (final id in ids) FzAppRef.token(id)];
}

/// iOS: a running freeze's picks as Frozen-row tiles, each with the grant
/// that thawed it (null: frozen) — the iOS twin of [FreezeApps.frozenNow].
///
/// A grant names a token id, the same id the shield's Thaw sends, so a tile
/// thaws exactly its pick (a category tile thaws the category). Matching
/// Always open and Never open is by id, which is best-effort: the same app
/// picked into two selections is expected to give the same token, but iOS
/// does not promise it. The shield itself follows the native rules
/// regardless. Null where the tiles can't be drawn, and for a Keep only set
/// (it freezes everything but its picks).
List<({FzAppRef app, ThawGrant? grant})>? fzFrozenTokens(
  WidgetRef ref,
  FreezeData d,
  AppSet set, {
  required bool deep,
  required DateTime now,
}) {
  if (set.keepOnly) return null;
  final tokens = fzTokensOf(ref, set);
  if (tokens == null) return null;
  final always = {...?fzTokensOf(ref, d.groups.alwaysOpen)};
  final never = {...?fzTokensOf(ref, d.groups.neverOpen)};
  return [
    for (final t in tokens)
      if (!always.contains(t))
        (app: t, grant: deep || never.contains(t) ? null : FreezeEngine.grantFor(d, t.id, now)),
  ];
}
