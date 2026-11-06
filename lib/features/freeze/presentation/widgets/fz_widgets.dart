import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/mascot/ada_mascot.dart';
import '../../../../shared/widgets/app_toggle.dart';
import '../../../../shared/widgets/ic.dart';
import '../../providers/freeze_controller.dart';

/// The building blocks of every App freeze screen (v11 §04-A): the squircle
/// app tile, the sheet that floats 8 clear of the edges, the rows and buttons.
/// Sizes are the design's (17/15/13 text, 44 header buttons, 50 buttons).

/// Ice is pinned to this violet whatever the accent (AQ_ICE).
const kFzIce = Color(0xFF6B5CF0);
const kFzDanger = Color(0xFFE85476);
const kFrostInk = Color(0xFF1A1320);

/// Solid, not alpha — keeps 6:1 on the frost ground.
const kFrostSub = Color(0xFF584F70);
const kFrostGround = LinearGradient(
  begin: Alignment(-0.17, -1),
  end: Alignment(0.17, 1),
  colors: [Color(0xFFF8F6FF), Color(0xFFEBE5FC), Color(0xFFDDD4F8)],
  stops: [0, 0.52, 1],
);
const double kFzHeadButton = 44;

// ---- the app tile -----------------------------------------------------------

/// Apple's icon outline (FZ_SQ_PATH): continuous corners, the curve starting
/// ~34% in and landing at ~22% radius. One shape for photos, tiles and frost.
Path fzSquircle(Size size) {
  final sx = size.width / 100;
  final sy = size.height / 100;
  Offset p(double x, double y) => Offset(x * sx, y * sy);
  final path = Path()..moveTo(p(50, 0).dx, p(50, 0).dy);
  void l(double x, double y) => path.lineTo(p(x, y).dx, p(x, y).dy);
  void c(double x1, double y1, double x2, double y2, double x, double y) =>
      path.cubicTo(p(x1, y1).dx, p(x1, y1).dy, p(x2, y2).dx, p(x2, y2).dy, p(x, y).dx, p(x, y).dy);
  l(66, 0);
  c(93.4, 0, 100, 6.6, 100, 34);
  l(100, 66);
  c(100, 93.4, 93.4, 100, 66, 100);
  l(34, 100);
  c(6.6, 100, 0, 93.4, 0, 66);
  l(0, 34);
  c(0, 6.6, 6.6, 0, 34, 0);
  return path..close();
}

class FzSquircleClipper extends CustomClipper<Path> {
  const FzSquircleClipper();

  @override
  Path getClip(Size size) => fzSquircle(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// An app as the UI knows it. [id] is an Android package, or on iOS a
/// placeholder — iOS never names the apps a student picks.
@immutable
class FzAppRef {
  const FzAppRef(this.id, this.name);

  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is FzAppRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The apps the design suggests (Android only — iOS can't see what is
/// installed), with the tint a tile uses before its real icon loads.
abstract final class FzKnownApps {
  static const suggested = <({String name, List<String> packages, String letter, double h, double s})>[
    (name: 'Instagram', packages: ['com.instagram.android'], letter: 'I', h: 330, s: 62),
    (name: 'TikTok', packages: ['com.zhiliaoapp.musically', 'com.ss.android.ugc.trill'], letter: 'T', h: 220, s: 6),
    (name: 'YouTube', packages: ['com.google.android.youtube'], letter: 'Y', h: 4, s: 68),
    (name: 'Snapchat', packages: ['com.snapchat.android'], letter: 'S', h: 50, s: 80),
    (name: 'Reddit', packages: ['com.reddit.frontpage'], letter: 'R', h: 20, s: 78),
    (name: 'X', packages: ['com.twitter.android'], letter: 'X', h: 0, s: 0),
    (name: 'Netflix', packages: ['com.netflix.mediaclient'], letter: 'N', h: 354, s: 58),
    (name: 'Discord', packages: ['com.discord'], letter: 'D', h: 235, s: 70),
  ];

  /// Ticked by default in Pick what freezes (ob-apps-android).
  static const preTicked = {'Instagram', 'TikTok', 'YouTube', 'Snapchat', 'Reddit', 'X'};

  /// Floor names by role, for the Always open page.
  static const floorNames = {'phone': 'Phone', 'messages': 'Messages', 'maps': 'Maps', 'wallet': 'Wallet'};

  static ({String letter, double h, double s}) tintOf(String name) {
    for (final a in suggested) {
      if (a.name == name) return (letter: a.letter, h: a.h, s: a.s);
    }
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return (letter: letter, h: (name.hashCode % 360).toDouble(), s: 30);
  }
}

/// An Android app's real icon, fetched once and kept for the session.
// ignore: specify_nonobvious_property_types
final fzAppIconProvider = FutureProvider.family<Uint8List?, String>(
  (ref, package) => ref.watch(appFreezeChannelProvider).appIcon(package),
);

/// The squircle app icon (FzIcon): the real icon on Android, a tinted letter
/// tile otherwise. [frozen] lays frost over it with the ice glyph.
class FzAppIcon extends ConsumerWidget {
  const FzAppIcon({super.key, required this.app, this.size = 30, this.frozen = false, this.glyph});

  final FzAppRef app;
  final double size;
  final bool frozen;

  /// A design glyph instead of a letter (the floor tiles: call, chat_bubble…).
  final String? glyph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = FzKnownApps.tintOf(app.name);
    final bg = dark
        ? HSLColor.fromAHSL(1, t.h, (t.s * 0.4) / 100, 0.21).toColor()
        : HSLColor.fromAHSL(1, t.h, t.s / 100, 0.93).toColor();
    final ink = dark
        ? HSLColor.fromAHSL(1, t.h, (t.s < 8 ? 8 : t.s) / 100, 0.80).toColor()
        : HSLColor.fromAHSL(1, t.h, (t.s * 0.8 < 6 ? 6 : t.s * 0.8) / 100, 0.36).toColor();
    final bytes = app.id.contains('.') ? ref.watch(fzAppIconProvider(app.id)).value : null;
    final face = bytes != null
        ? Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
        : Container(
            color: bg,
            alignment: Alignment.center,
            child: glyph != null
                ? Ic(glyph!, size: (size * 0.5).roundToDouble(), color: ink)
                : Text(
                    t.letter,
                    style: AppText.sans(size: (size * 0.46).roundToDouble(), weight: FontWeight.w800, height: 1, color: ink),
                  ),
          );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(clipper: const FzSquircleClipper(), child: face),
          if (frozen) ...[
            ClipPath(
              clipper: const FzSquircleClipper(),
              child: ColoredBox(
                color: dark ? const Color(0x9E1A1630) : const Color(0xA3FFFFFF),
                child: Center(child: Ic('freeze', size: (size * 0.46).roundToDouble(), color: kFzIce)),
              ),
            ),
            CustomPaint(painter: _SquircleStroke(color: kFzIce.withValues(alpha: 0.55), width: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _SquircleStroke extends CustomPainter {
  const _SquircleStroke({required this.color, required this.width, this.progress});

  final Color color;
  final double width;

  /// Draw only this fraction of the outline, from the top centre clockwise.
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = fzSquircle(size);
    final p = progress;
    if (p == null) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * p.clamp(0, 1)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SquircleStroke old) =>
      old.color != color || old.width != width || old.progress != progress;
}

enum FzTileState { plain, frozen, thawed }

/// A tile with its state (FzApp): frozen (frost + "Thaw"), thawed (a ring
/// running down to the refreeze + minutes left), or plain (its name).
class FzAppTile extends StatelessWidget {
  const FzAppTile({
    super.key,
    required this.app,
    this.state = FzTileState.plain,
    this.minutesLeft,
    this.progress = 0.6,
    this.size = 60,
    this.onTap,
  });

  final FzAppRef app;
  final FzTileState state;
  final int? minutesLeft;

  /// Thawed: the share of the thaw still left, 1 → 0.
  final double progress;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final o = size + 10;
    final cap = switch (state) {
      FzTileState.frozen => 'Thaw',
      FzTileState.thawed => '${minutesLeft ?? 0}m',
      FzTileState.plain => app.name,
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: o,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (state == FzTileState.thawed) ...[
                  Positioned.fill(child: CustomPaint(painter: _SquircleStroke(color: colors.hilite, width: 3))),
                  Positioned.fill(
                    child: CustomPaint(painter: _SquircleStroke(color: colors.accent, width: 3, progress: progress)),
                  ),
                ],
                FzAppIcon(app: app, size: size, frozen: state == FzTileState.frozen),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: o + 12,
            child: Text(
              cap,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(
                size: 15,
                color: state == FzTileState.frozen ? colors.accent : colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlapping app icons (FzStack) with an optional "+3".
class FzStack extends StatelessWidget {
  const FzStack({super.key, required this.apps, this.more = 0, this.size = 28, this.edge});

  final List<FzAppRef> apps;
  final int more;
  final double size;
  final Color? edge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rim = edge ?? colors.surface;
    final children = <Widget>[];
    for (var i = 0; i < apps.length; i++) {
      children.add(Transform.translate(
        offset: Offset(-8.0 * i, 0),
        child: ClipPath(
          clipper: const FzSquircleClipper(),
          child: Container(
            width: size + 4,
            height: size + 4,
            color: rim,
            alignment: Alignment.center,
            child: FzAppIcon(app: apps[i], size: size),
          ),
        ),
      ));
    }
    if (more > 0) {
      children.add(Transform.translate(
        offset: Offset(-8.0 * apps.length + 1, 0),
        child: Container(
          height: size + 4,
          constraints: BoxConstraints(minWidth: size + 4),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.hilite,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: rim, width: 2),
          ),
          child: Text('+$more', style: AppText.sans(size: 13, weight: FontWeight.w800, color: colors.textMed)),
        ),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// An app set's stand-in on iOS, where the apps have no names: one frosted
/// tile with the count.
class FzCountTile extends StatelessWidget {
  const FzCountTile({super.key, required this.count, this.size = 60, this.frozen = true});

  final int count;
  final double size;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size + 10,
          child: Center(
            child: ClipPath(
              clipper: const FzSquircleClipper(),
              child: Container(
                width: size,
                height: size,
                color: colors.accentSoft,
                alignment: Alignment.center,
                child: Ic(frozen ? 'freeze' : 'thaw', size: size * 0.46, color: kFzIce),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          count <= 0 ? 'Everything else' : (count == 1 ? '1 app' : '$count apps'),
          style: AppText.sans(size: 15, color: frozen ? colors.accent : colors.text),
        ),
      ],
    );
  }
}

// ---- headers and buttons ----------------------------------------------------

enum FzFill { page, well, ink }

/// A 44 circular header button (BarCircle / BackBtn).
class FzHeadButton extends StatelessWidget {
  const FzHeadButton({super.key, required this.icon, this.onTap, this.fill = FzFill.page, this.color});

  final String icon;
  final VoidCallback? onTap;
  final FzFill fill;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg, shadow) = switch (fill) {
      FzFill.page => (colors.surface, colors.text, colors.cardShadow),
      FzFill.well => (colors.bg, colors.text, const <BoxShadow>[]),
      FzFill.ink => (colors.ink, Colors.white, const <BoxShadow>[]),
    };
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: kFzHeadButton,
          height: kFzHeadButton,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: shadow),
          alignment: Alignment.center,
          child: Ic(icon, size: icon == 'back' ? 24 : 22, color: color ?? fg),
        ),
      ),
    );
  }
}

/// A 44-high pill header button (BarPill): "Save", "Edit".
class FzHeadPill extends StatelessWidget {
  const FzHeadPill({super.key, required this.label, this.onTap, this.fill = FzFill.ink, this.enabled = true});

  final String label;
  final VoidCallback? onTap;
  final FzFill fill;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, fg) = switch (fill) {
      FzFill.page => (colors.surface, colors.text),
      FzFill.well => (colors.bg, colors.text),
      FzFill.ink => (colors.ink, Colors.white),
    };
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: kFzHeadButton,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kFzHeadButton / 2)),
          // Sized to its label even under an Align (the running-frost header).
          child: Center(widthFactor: 1, child: Text(label, style: AppText.sans(size: 17, weight: FontWeight.w700, color: fg))),
        ),
      ),
    );
  }
}

/// The ✕ that closes a sheet (BarDismiss).
class FzDismiss extends StatelessWidget {
  const FzDismiss({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: SizedBox.square(
          dimension: kFzHeadButton,
          child: Center(child: Ic('close', size: 20, color: context.colors.textMed)),
        ),
      ),
    );
  }
}

/// Back + optional add, then the 34 title (FzPageHead).
class FzPageHead extends StatelessWidget {
  const FzPageHead({super.key, required this.title, this.sub, this.onAdd, this.onBack});

  final String title;
  final String? sub;
  final VoidCallback? onAdd;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FzHeadButton(icon: 'back', onTap: onBack ?? () => Navigator.of(context).maybePop()),
            const Spacer(),
            if (onAdd != null) FzHeadButton(icon: 'add', onTap: onAdd),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: AppText.sans(size: 34, weight: FontWeight.w800, letterSpacing: -0.6, height: 1.12, color: colors.text),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub!, style: AppText.sans(size: 15, height: 1.35, weight: FontWeight.w500, color: colors.textMed)),
          ),
      ],
    );
  }
}

/// A section title with an optional action ("Thaw all") or chevron (FzSec).
class FzSec extends StatelessWidget {
  const FzSec({super.key, required this.title, this.action, this.onAction, this.chevron = false, this.onTap, this.top = 28});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final bool chevron;
  final VoidCallback? onTap;
  final double top;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.sans(size: 20, weight: FontWeight.w700, letterSpacing: -0.2, color: colors.text)),
                if (chevron) Ic('chevron_right', color: colors.textDim),
              ],
            ),
          ),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: AppText.sans(size: 17, color: colors.accent)),
            ),
        ],
      ),
    );
  }
}

/// An icon, a bold line and a quiet line (FzClaim).
class FzClaim extends StatelessWidget {
  const FzClaim({super.key, required this.icon, required this.title, required this.body, this.tone});

  final String icon;
  final String title;
  final String body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 32, child: Center(child: Ic(icon, size: 28, color: tone ?? colors.accent))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sans(size: 15, weight: FontWeight.w700, height: 1.33, color: colors.text)),
              const SizedBox(height: 1),
              Text(body, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.33, color: colors.textMed)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 50-high pill button App freeze uses (FzBtn → PBtn).
class FzBtn extends StatelessWidget {
  const FzBtn({super.key, required this.label, this.onTap, this.ghost = false, this.icon, this.enabled = true, this.dark});

  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  final String? icon;
  final bool enabled;

  /// Force the ink fill on a frost ground, where the theme's ink may be the
  /// accent (dark mode).
  final Color? dark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = !enabled ? colors.hilite : (ghost ? colors.surface : (dark ?? colors.ink));
    final fg = !enabled ? colors.textDim : (ghost ? colors.text : Colors.white);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 50,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
            border: ghost ? Border.all(color: colors.border, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Ic(icon!, size: 19, color: ghost ? colors.accent : fg), const SizedBox(width: 7)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(size: 15, weight: FontWeight.w800, letterSpacing: 0.15, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet centred link under a button ("Not now", "Keep it running").
class FzLink extends StatelessWidget {
  const FzLink(this.label, {super.key, this.onTap, this.color, this.size = 15, this.weight = FontWeight.w600});

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.sans(size: size, weight: weight, color: color ?? context.colors.textMed),
        ),
      ),
    );
  }
}

// ---- wells, rows and pickers ------------------------------------------------

/// The grey rounded container rows sit in (background BG, radius 26).
class FzWell extends StatelessWidget {
  const FzWell({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16), this.color, this.radius = 26});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color ?? context.colors.bg, borderRadius: BorderRadius.circular(radius)),
        child: child,
      );
}

/// A label with something on the right, in a well (FzField).
class FzField extends StatelessWidget {
  const FzField({super.key, required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.only(left: 16, right: 12),
        decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text))),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// "9:00 AM" in a white pill on a well row (From / Until).
class FzTimeRow extends StatelessWidget {
  const FzTimeRow({super.key, required this.label, required this.value, this.onTap, this.first = false});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: colors.border))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text))),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(17)),
              child: Text(value, style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The M T W T F S S circles (On these days).
class FzDayPicker extends StatelessWidget {
  const FzDayPicker({super.key, required this.days, required this.onChanged, required this.label});

  /// ISO weekdays, 1 = Monday.
  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;
  final String label;

  static const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FzWell(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('On these days', style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text))),
              Text(label, style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Semantics(
                  label: names[i],
                  selected: days.contains(i + 1),
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      final next = {...days};
                      if (!next.remove(i + 1)) next.add(i + 1);
                      onChanged(next);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: days.contains(i + 1) ? colors.accent : colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        letters[i],
                        style: AppText.sans(
                          size: 15,
                          weight: FontWeight.w800,
                          color: days.contains(i + 1) ? Colors.white : colors.textMed,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A chip that is either ink (on) or a well (FzChoice).
class FzChoice extends StatelessWidget {
  const FzChoice({super.key, required this.label, required this.on, this.onTap, this.frost = false});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  /// On the frost ground: off chips are translucent white, text frost ink.
  final bool frost;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = on ? (frost ? const Color(0xFF111111) : colors.ink) : (frost ? const Color(0xE0FFFFFF) : colors.bg);
    final fg = on ? Colors.white : (frost ? kFrostInk : colors.text);
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          constraints: BoxConstraints(minWidth: frost ? 58 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
          // Center(widthFactor: 1), not `alignment:` — an aligned Container
          // grows to the full width a Wrap offers, one chip per line.
          child: Center(
            widthFactor: 1,
            child: Text(label, style: AppText.sans(size: 15, weight: frost ? FontWeight.w800 : FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}

/// A title, a sub-line and a toggle in a well (FzToggleRow).
class FzToggleRow extends StatelessWidget {
  const FzToggleRow({super.key, required this.title, required this.sub, required this.value, this.onChanged});

  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(26)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text)),
                const SizedBox(height: 1),
                Text(sub, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.3, color: colors.textMed)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Opacity(opacity: onChanged == null ? 0.4 : 1, child: AppToggle(value: value, onChanged: onChanged)),
        ],
      ),
    );
  }
}

/// The two-way segmented control (FzSeg): Freeze these / Keep only these.
class FzSeg extends StatelessWidget {
  const FzSeg({super.key, required this.options, required this.index, required this.onChanged});

  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? colors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: i == index ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 1))] : null,
                    ),
                    child: Text(
                      options[i],
                      style: AppText.sans(size: 15, color: i == index ? colors.text : colors.textMed),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An option card with a check when chosen (FzPick — the Haptics language).
class FzPick extends StatelessWidget {
  const FzPick({super.key, required this.icon, required this.label, required this.sub, required this.selected, this.onTap});

  final String icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.hilite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? colors.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Ic(icon, size: 21, color: selected ? colors.accent : colors.text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.sans(size: 17, weight: FontWeight.w800, color: selected ? colors.accent : colors.text)),
                    const SizedBox(height: 1),
                    Text(sub, style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.4, color: colors.textMed)),
                  ],
                ),
              ),
              if (selected) Ic('check_circle:fill', size: 21, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// A coloured dot and a word (FzStatus): "Allowed", "Restricted", "Off".
class FzStatus extends StatelessWidget {
  const FzStatus({super.key, required this.tone, required this.label});

  final Color tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.sans(size: 17, weight: FontWeight.w500, color: tone == kFzDanger ? kFzDanger : context.colors.textMed),
        ),
      ],
    );
  }
}

/// A frost's signature: trigger → freeze (FzTrigger).
class FzTrigger extends StatelessWidget {
  const FzTrigger({super.key, this.session = false, this.live = false, this.size = 26});

  final bool session;
  final bool live;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = live ? colors.accent : colors.textDim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ic(session ? 'timer' : 'calendar_month', size: size, color: tone),
        const SizedBox(width: 6),
        Ic('forward', size: (size * 0.8).roundToDouble(), color: colors.textDim),
        const SizedBox(width: 6),
        Ic('freeze', size: size, color: live ? kFzIce : colors.textDim),
      ],
    );
  }
}

/// Ada in her ice block, the App freeze emblem (FzIceBlock).
class FzIceBlock extends StatelessWidget {
  const FzIceBlock({super.key, this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipPath(
      clipper: const FzSquircleClipper(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.34, -1),
            end: const Alignment(0.34, 1),
            colors: [dark ? const Color(0x1AFFFFFF) : Colors.white, colors.accentSoft],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AdaMascot(size: (size * 0.62).roundToDouble(), cheeks: true, bubbles: 0),
            const Positioned(top: 9, right: 10, child: Ic('freeze', size: 17, color: kFzIce)),
          ],
        ),
      ),
    );
  }
}

// ---- the floating sheet -----------------------------------------------------

/// The root navigator's context: still mounted after a sheet closes, so a
/// sheet can hand off to the next one ("Edit" on a running frost).
BuildContext fzRootContext(BuildContext context) => Navigator.of(context, rootNavigator: true).context;

/// A sheet over the dimmed screen that floats 8 clear of the sides and bottom,
/// corners concentric with the display (FzOver: 55 − 8 = 47). Lifts above the
/// keyboard.
Future<T?> showFzSheet<T>(BuildContext context, {required WidgetBuilder builder, double dim = 0.4}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Color.fromRGBO(20, 15, 28, dim),
    builder: (sheetContext) => FzSheet(child: builder(sheetContext)),
  );
}

class FzSheet extends StatelessWidget {
  const FzSheet({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 28)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + (keyboard > 0 ? keyboard : safe * 0.4)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(47),
          boxShadow: const [BoxShadow(color: Color(0x3D000000), blurRadius: 44, offset: Offset(0, 12))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0x38FFFFFF) : const Color(0xFFDCD9E2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ✕ or ‹, a centred 17 title, and something on the right (FzSheetHead).
class FzSheetHead extends StatelessWidget {
  const FzSheetHead({super.key, required this.title, this.back = false, this.right, this.editable = false, this.onTitle, this.bottom = 14, this.onBack});

  final String title;
  final bool back;
  final Widget? right;
  final bool editable;
  final VoidCallback? onTitle;
  final VoidCallback? onBack;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        children: [
          if (back)
            FzHeadButton(icon: 'chevron_left', fill: FzFill.well, onTap: onBack ?? () => Navigator.of(context).maybePop())
          else
            Transform.translate(offset: const Offset(-12, 0), child: const FzDismiss()),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onTitle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
                    ),
                  ),
                  if (editable) ...[const SizedBox(width: 5), Ic('edit', size: 16, color: colors.textDim)],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          right ?? SizedBox(width: back ? kFzHeadButton : kFzHeadButton - 24),
        ],
      ),
    );
  }
}

/// A 20 bold title with the ✕ beside it (FzSheetTitle).
class FzSheetTitle extends StatelessWidget {
  const FzSheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(text, style: AppText.sans(size: 20, weight: FontWeight.w800, height: 1.25, color: context.colors.text)),
            ),
          ),
          const SizedBox(width: 12),
          Transform.translate(offset: const Offset(12, 0), child: const FzDismiss()),
        ],
      ),
    );
  }
}

/// Body copy under a sheet title.
class FzSheetBody extends StatelessWidget {
  const FzSheetBody(this.text, {super.key, this.bottom = 20});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Text(text, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: context.colors.textMed)),
      );
}

/// A row in an app list (FzRow): icon, name (+ sub), and a remove ✕ — or the
/// "Add apps or sites" row.
class FzListRow extends StatelessWidget {
  const FzListRow({super.key, this.app, this.sub, this.last = false, this.onRemove, this.onAdd, this.addLabel = 'Add apps or sites', this.glyph, this.trailing});

  final FzAppRef? app;
  final String? sub;
  final bool last;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final String addLabel;
  final String? glyph;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final add = app == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: add ? onAdd : null,
      child: Row(
        children: [
          if (add)
            ClipPath(
              clipper: const FzSquircleClipper(),
              child: Container(
                width: 30,
                height: 30,
                color: colors.accentSoft,
                alignment: Alignment.center,
                child: Ic('add', size: 20, color: colors.accent),
              ),
            )
          else
            FzAppIcon(app: app!, glyph: glyph),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: sub != null ? 60 : 52),
              decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: colors.border))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          add ? addLabel : app!.name,
                          style: AppText.sans(
                            size: 17,
                            weight: add ? FontWeight.w700 : FontWeight.w500,
                            color: add ? colors.accent : colors.text,
                          ),
                        ),
                        if (sub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(sub!, style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                  if (!add && onRemove != null) Transform.translate(offset: const Offset(12, 0), child: FzDismiss(onTap: onRemove)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A frost card in the hub's carousel (FzFrostCard).
class FzFrostCard extends StatelessWidget {
  const FzFrostCard({
    super.key,
    required this.name,
    required this.status,
    required this.session,
    required this.live,
    required this.apps,
    this.count = 0,
    this.onTap,
  });

  final String name;
  final String status;
  final bool session;
  final bool live;
  final List<FzAppRef> apps;

  /// iOS: how many things the set holds, shown instead of icons.
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        height: 180,
        padding: const EdgeInsets.fromLTRB(18, 20, 16, 16),
        decoration: BoxDecoration(
          gradient: live
              ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors.accentSoft, colors.surface], stops: const [0, 0.62])
              : null,
          color: live ? null : colors.surface,
          borderRadius: BorderRadius.circular(34),
          boxShadow: colors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FzTrigger(session: session, live: live),
            const Spacer(),
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: live ? colors.accentSoft : Colors.transparent,
                border: live ? null : Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(status, style: AppText.sans(size: 13, color: live ? colors.accent : colors.text)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 20, weight: FontWeight.w700, letterSpacing: -0.2, color: colors.text),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text('Freezes', style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed)),
                const SizedBox(width: 6),
                if (apps.isNotEmpty)
                  Flexible(child: FzStack(apps: apps.take(2).toList(), size: 22))
                else
                  Text(
                    count == 0 ? 'nothing yet' : '$count',
                    style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A Student frost to start from (FzTemplate).
class FzTemplateCard extends StatelessWidget {
  const FzTemplateCard({super.key, required this.icon, required this.name, required this.meta, this.well = false, this.width, this.onTap});

  final String icon;
  final String name;
  final String meta;
  final bool well;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 15),
        decoration: BoxDecoration(
          color: well ? colors.bg : colors.surface,
          boxShadow: well ? null : colors.cardShadow,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Ic(icon, size: 21, color: colors.accent),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: well ? colors.surface : colors.bg, shape: BoxShape.circle),
                  child: Ic('add', size: 18, color: colors.text),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(name, style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
            const SizedBox(height: 2),
            Text(meta, style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
          ],
        ),
      ),
    );
  }
}

/// A grant row's countdown: rebuilds every second while visible.
class FzSecondTicker extends StatefulWidget {
  const FzSecondTicker({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<FzSecondTicker> createState() => _FzSecondTickerState();
}

class _FzSecondTickerState extends State<FzSecondTicker> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
