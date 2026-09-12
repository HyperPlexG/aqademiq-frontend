import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/referral_link.dart';
import '../../data/repositories/referral_repository.dart';
import '../../features/settings/providers/profile_controller.dart';

/// Presents the referral / share sheet ([_ShareSheet]) over the dimmed real
/// screen. Reused by both the Subjects section (`subj-share`) and the section 06
/// referral flow. Returns when dismissed.
Future<void> showShareSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x4C140F1C),
    builder: (_) => const _ShareSheet(),
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
        boxShadow: colors.sheetShadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0DDD7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const _InviteHeroCard(),
              Text(
                'Help us grow!',
                textAlign: TextAlign.center,
                style: AppText.sans(
                  size: 19,
                  weight: FontWeight.w800,
                  height: 1.2,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share your code with friends and help us reach more '
                'students. It means the world to us.',
                textAlign: TextAlign.center,
                style: AppText.sans(size: 13, height: 1.5, color: colors.textMed),
              ),
              const SizedBox(height: 14),
              Text(
                'YOUR REFERRAL CODE',
                textAlign: TextAlign.center,
                style: AppText.sans(
                  size: 9,
                  weight: FontWeight.w800,
                  letterSpacing: AppText.em(0.12, 9),
                  color: colors.textDim,
                ),
              ),
              const SizedBox(height: 9),
              const _CodeBoxes(),
              const SizedBox(height: 15),
              const _ShareInviteButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteHeroCard extends ConsumerWidget {
  const _InviteHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final name = ref.watch(profileControllerProvider).name.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent,
            const Color(0xFFB39DF5),
            const Color(0xFFE9C8D8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 54,
            height: 54,
          ),
          const SizedBox(height: 2),
          Text(
            'Aqademiq',
            style: AppText.sans(
              size: 22,
              weight: FontWeight.w800,
              letterSpacing: -0.5,
              color: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name.isEmpty ? 'Invite a friend' : 'Invite by $name',
            style: AppText.sans(
              size: 11,
              weight: FontWeight.w700,
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBoxes extends ConsumerWidget {
  const _CodeBoxes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The user's real, unique code (falls back to a dashed placeholder while it
    // loads). Rendered dynamically so any code length fits.
    final code = ref.watch(referralCodeProvider).value ?? '';
    final chars = code.isEmpty ? List.filled(5, '·') : code.split('');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < chars.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          _CodeCell(char: chars[i]),
        ],
      ],
    );
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 38,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        char,
        style: AppText.mono(size: 22, weight: FontWeight.w800, color: colors.text),
      ),
    );
  }
}

class _ShareInviteButton extends ConsumerWidget {
  const _ShareInviteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () async {
        final code = ref.read(referralCodeProvider).value ?? '';
        // The code stays in the text as well as the link: the link only opens
        // the app once the domain-association files are hosted, and until then
        // the readable code is still the thing that works.
        final codePart = code.isEmpty ? '' : ' Use my referral code $code.';
        // iPad presents the share sheet as a POPOVER, and UIKit requires an
        // anchor rect for it. Without one the presentation fails on iPad while
        // working fine on iPhone (where it is a modal sheet) — and because the
        // failure happens in UIKit rather than Dart, the await below can never
        // return, leaving the sheet looking frozen. iPhone ignores the rect.
        final box = context.findRenderObject() as RenderBox?;
        final screen = MediaQuery.sizeOf(context);
        final origin = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromCenter(
                center: Offset(screen.width / 2, screen.height / 2),
                width: 1,
                height: 1,
              );
        await SharePlus.instance.share(
          ShareParams(
            text: 'Join me on Aqademiq — my focus sanctuary.$codePart '
                '${referralLink(code)}',
            subject: 'Join me on Aqademiq',
            sharePositionOrigin: origin,
          ),
        );
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: LinearGradient(
            colors: [colors.accent, const Color(0xFF9F8BEF)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ios_share, size: 18, color: Color(0xFFFFFFFF)),
            const SizedBox(width: 9),
            Text(
              'Share Invite',
              style: AppText.sans(
                size: 14,
                weight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
