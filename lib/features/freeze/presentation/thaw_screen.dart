import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../shared/mascot/ice_timer.dart';
import '../../../shared/widgets/ic.dart';
import '../domain/freeze_engine.dart';
import '../domain/freeze_models.dart';
import '../providers/freeze_controller.dart';
import 'freeze_apps.dart';
import 'sheets/frost_sheets.dart';
import 'widgets/fz_widgets.dart';

/// What a thaw is for: one app ([target] is its package / iOS token id), or
/// [ThawGrant.allApps]. [standDown] makes it Thaw everything (settings) —
/// "Takes the usual breath first."
@immutable
class ThawRequest {
  const ThawRequest({required this.target, this.label, this.standDown = false, this.standDownUntil});

  final String target;
  final String? label;
  final bool standDown;
  final DateTime? standDownUntil;
}

/// The breath (fz-thaw-pause, -more), then how long (fz-thaw-minutes).
///
/// Not a penalty screen and not a counter: the ice melts while you wait, and
/// the way out is always there. Pops with the grant it made, or null when the
/// student kept it frozen.
class ThawScreen extends ConsumerStatefulWidget {
  const ThawScreen({super.key, required this.request});

  final ThawRequest request;

  @override
  ConsumerState<ThawScreen> createState() => _ThawScreenState();
}

class _ThawScreenState extends ConsumerState<ThawScreen> {
  late final int _total;
  late int _left;
  Timer? _timer;
  bool _choosing = false;
  late int _minutes;
  bool _increasing = false;

  @override
  void initState() {
    super.initState();
    final c = ref.read(freezeControllerProvider.notifier);
    final data = ref.read(freezeControllerProvider);
    _total = c.breathSeconds;
    _left = _total;
    _minutes = data.thaw.minutes;
    _increasing = data.thaw.resistance == ThawResistance.increasing && _total > 10;
    // A Deep freeze holds: say so instead of breathing for nothing. Per app
    // (APP_FREEZE.md §2 rule 4): only a Deep freeze that covers THIS app
    // closes its thaw. iOS can't tell which app a token is, so any Deep
    // freeze counts there, as it does for Thaw all.
    final target = widget.request.target;
    final ios = ref.read(freezeAppsProvider).ios;
    final holding = FreezeEngine.active(data, DateTime.now())
        .where((a) => a.deep && a.end != null && (target == ThawGrant.allApps || ios || a.covers(target)))
        .toList();
    final deep = holding.isEmpty ? null : holding.reduce((a, b) => b.end!.isAfter(a.end!) ? b : a);
    if (deep != null && deep.end != null && !widget.request.standDown) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final root = fzRootContext(context);
        Navigator.of(context).pop();
        await showDeepHoldSheet(root, name: deep.name, until: deep.end!);
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _who => widget.request.label ?? (widget.request.target == ThawGrant.allApps ? 'your apps' : 'this app');

  void _done() {
    final c = ref.read(freezeControllerProvider.notifier);
    ref.read(hapticsProvider).sessionResumed();
    if (widget.request.standDown) {
      c.standDown(widget.request.standDownUntil);
      Navigator.of(context).pop();
      return;
    }
    final grant = c.thaw(target: widget.request.target, minutes: _minutes, label: widget.request.label);
    Navigator.of(context).pop(grant);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _left == 0;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: kFrostGround),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: _choosing ? _minutesBody() : _breathBody(ready),
          ),
        ),
      ),
    );
  }

  Widget _breathBody(bool ready) {
    final progress = _total == 0 ? 1.0 : 1 - _left / _total;
    final question = widget.request.standDown
        ? 'Still want everything thawed in $_left seconds?'
        : 'Still want $_who in $_left seconds?';
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IceTimer(progress: progress),
              const SizedBox(height: 22),
              Text('Take a breath.', style: AppText.sans(size: 28, weight: FontWeight.w800, color: kFrostInk)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 270),
                child: Text(
                  ready ? 'Ready when you are.' : question,
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 15, height: 1.5, color: kFrostSub),
                ),
              ),
              if (_increasing) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xB8FFFFFF), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Ic('shield', size: 16, color: kFzIce),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('Each thaw today waits a little longer',
                            style: AppText.sans(size: 13, weight: FontWeight.w700, color: kFrostInk)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Semantics(
          button: true,
          enabled: ready,
          label: ready ? 'Thaw' : 'Thaw in $_left seconds',
          child: GestureDetector(
            onTap: ready
                ? () {
                    if (widget.request.standDown) {
                      _done();
                    } else {
                      setState(() => _choosing = true);
                    }
                  }
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: SizedBox(
                height: 50,
                child: Stack(
                  children: [
                    const Positioned.fill(child: ColoredBox(color: Color(0x80FFFFFF))),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 900),
                        width: (MediaQuery.sizeOf(context).width - 44) * progress,
                        color: const Color(0xCCFFFFFF),
                      ),
                    ),
                    Center(
                      child: Text(
                        ready ? (widget.request.standDown ? 'Thaw everything' : 'Thaw') : 'Thaw in ${_left}s',
                        style: AppText.sans(size: 17, weight: ready ? FontWeight.w800 : FontWeight.w600, color: ready ? kFrostInk : kFrostSub),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FzLink('Keep it frozen', color: kFrostInk, weight: FontWeight.w700, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _minutesBody() {
    final apps = ref.watch(freezeAppsProvider);
    final target = widget.request.target;
    Widget step(String icon, VoidCallback onTap) => Semantics(
          button: true,
          label: icon == 'add' ? 'More' : 'Less',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: kFzHeadButton,
              height: kFzHeadButton,
              decoration: const BoxDecoration(color: Color(0xE0FFFFFF), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Ic(icon, size: 22, color: kFrostInk),
            ),
          ),
        );
    const lengths = ThawSettings.lengths;
    final i = lengths.indexOf(_minutes);
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (target != ThawGrant.allApps && !apps.ios) ...[
                    FzAppIcon(app: apps.ref(target), size: 40, glyph: apps.glyphOf(target)),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text('Thaw ${widget.request.label ?? (target == ThawGrant.allApps ? 'apps' : 'it')} for',
                        style: AppText.sans(size: 20, weight: FontWeight.w800, color: kFrostInk)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  step('remove', () => setState(() => _minutes = lengths[i <= 0 ? 0 : i - 1])),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 112,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$_minutes', style: AppText.sans(size: 64, weight: FontWeight.w800, height: 1, color: kFrostInk)),
                          const SizedBox(width: 6),
                          Text('min', style: AppText.sans(size: 17, weight: FontWeight.w700, color: kFrostSub)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  step('add', () => setState(() => _minutes = lengths[i < 0 || i >= lengths.length - 1 ? lengths.length - 1 : i + 1])),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in lengths)
                    FzChoice(label: '$m min', on: m == _minutes, frost: true, onTap: () => setState(() => _minutes = m)),
                ],
              ),
            ],
          ),
        ),
        FzBtn(label: 'Thaw for $_minutes min', dark: const Color(0xFF111111), onTap: _done),
        const SizedBox(height: 16),
        FzLink('Keep it frozen', color: kFrostInk, weight: FontWeight.w700, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}
