import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../icons/app_icon.dart';
import '../icons/aq_icon.dart';
import '../mascot/ada_mascot.dart';

/// Stable semantic tab indices (README §4 / prototype). NOTE the order is
/// non-sequential by design: the center Ada carries index 4.
abstract final class NavTab {
  static const int subjects = 0;
  static const int planner = 1;
  static const int timer = 2;
  static const int stats = 3;
  static const int ada = 4;
}

class _NavItem {
  const _NavItem(this.icon, this.index);

  /// The Aqademiq glyph (v11 BNav), drawn filled when the tab is active.
  /// Null = Ada's centre face.
  final String? icon;
  final int index;
}

/// Floating 5-tab bottom navigation (prototype `BNav`). Visual L→R:
/// Subjects · Planner · **Ada (center)** · Timer · Stats. Guest mode locks
/// Ada(4) + Stats(3) with a lock dot.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.guest = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool guest;

  /// Floating bar height (v11 `BNav`: 61, a 30.5 pill). Single source of
  /// truth — screens derive their bottom clearance from this via
  /// `AppScaffold.navClearanceOf`.
  static const double height = 61;

  /// Gap between the floating bar and the bottom safe-area edge (see AppShell).
  static const double bottomGap = 8;

  static const List<_NavItem> _items = [
    _NavItem('subjects', NavTab.subjects),
    _NavItem('planner', NavTab.planner),
    _NavItem(null, NavTab.ada),
    _NavItem('focus', NavTab.timer),
    _NavItem('insights', NavTab.stats),
  ];

  bool _locked(int i) => guest && (i == NavTab.ada || i == NavTab.stats);

  /// The key of the tab carrying semantic [index] (`NavTab`).
  static ValueKey<String> tabKey(int index) => ValueKey('nav-tab-$index');

  static const _labels = {
    NavTab.subjects: 'Subjects',
    NavTab.planner: 'Planner',
    NavTab.ada: 'Ada',
    NavTab.timer: 'Focus',
    NavTab.stats: 'Insights',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: colors.navShadow,
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: Semantics(
                button: true,
                selected: currentIndex == item.index,
                label: _labels[item.index],
                child: GestureDetector(
                // Tabs are found by key, not by icon: the glyphs are drawn by
                // the icon pack, so there is no IconData to look for.
                key: tabKey(item.index),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(item.index),
                child: SizedBox(
                  height: height - 7,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (item.icon == null)
                        Center(child: _AdaTab(active: currentIndex == item.index, locked: _locked(item.index)))
                      else
                        Positioned.fill(child: _StandardTab(icon: item.icon!, active: currentIndex == item.index)),
                      if (_locked(item.index))
                        const Positioned(top: 6, right: 6, child: _LockDot()),
                    ],
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

class _StandardTab extends StatelessWidget {
  const _StandardTab({required this.icon, required this.active});
  final String icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // v11 NAV_ON: a soft grey pill in light, the accent in dark.
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? (dark ? colors.accent : const Color(0xFFECECEC)) : Colors.transparent,
        borderRadius: BorderRadius.circular(27),
      ),
      child: AqIcon.named(icon, fill: active, color: active ? (dark ? Colors.white : colors.text) : colors.textMed),
    );
  }
}

class _AdaTab extends StatelessWidget {
  const _AdaTab({required this.active, required this.locked});
  final bool active;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.ink : colors.surface,
          shape: BoxShape.circle,
          border: active ? null : Border.all(color: colors.border, width: 1.5),
        ),
        child: const AdaNavFace(),
      ),
    );
  }
}

class _LockDot extends StatelessWidget {
  const _LockDot();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.warn,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 2),
      ),
      child: const AppIcon(Icons.lock, size: 8, color: Colors.white),
    );
  }
}
