import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';

enum SsoProvider { apple, google }

/// Apple / Google SSO pill (v11 `SSOButtons`): 50 high, each brand's own mark
/// and system type, per the Apple and Google button guidelines.
class SsoButton extends StatelessWidget {
  const SsoButton({
    super.key,
    required this.provider,
    required this.label,
    this.onTap,
  });

  final SsoProvider provider;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isApple = provider == SsoProvider.apple;
    final applePlatform = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isApple ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: isApple ? null : Border.all(color: const Color(0xFF747775), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isApple)
                const CustomPaint(size: Size(17 * 0.814, 17), painter: _AppleLogoPainter())
              else
                const CustomPaint(size: Size.square(18), painter: _GoogleLogoPainter()),
              SizedBox(width: isApple ? 8 : 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Each brand's button uses its platform's own face: SF on
                  // Apple, Roboto for Google (system fallback elsewhere).
                  style: TextStyle(
                    fontFamily: isApple ? (applePlatform ? 'CupertinoSystemText' : null) : 'Roboto',
                    fontSize: 17,
                    fontWeight: isApple ? FontWeight.w600 : FontWeight.w500,
                    color: isApple ? Colors.white : const Color(0xFF1F1F1F),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Apple logo (viewBox 814 × 1000), white.
class _AppleLogoPainter extends CustomPainter {
  const _AppleLogoPainter();

  static final Path _logo = Path()
    ..moveTo(788.1, 340.9)
    ..cubicTo(782.3, 345.4, 679.9, 403.1, 679.9, 531.4)
    ..cubicTo(679.9, 679.8, 810.2, 732.3, 814.1, 733.6)
    ..cubicTo(813.5, 736.8, 793.4, 805.5, 745.4, 875.5)
    ..cubicTo(702.6, 937.1, 657.9, 998.6, 589.9, 998.6)
    ..cubicTo(521.9, 998.6, 504.4, 959.1, 425.9, 959.1)
    ..cubicTo(349.4, 959.1, 322.2, 999.9, 260, 999.9)
    ..cubicTo(197.8, 999.9, 154.4, 942.9, 104.5, 872.9)
    ..cubicTo(46.7, 790.7, 0, 663, 0, 541.8)
    ..cubicTo(0, 347.4, 126.4, 244.3, 250.8, 244.3)
    ..cubicTo(316.9, 244.3, 372, 287.7, 413.5, 287.7)
    ..cubicTo(453, 287.7, 514.6, 241.7, 589.8, 241.7)
    ..cubicTo(618.3, 241.7, 720.7, 244.3, 788.1, 340.9)
    ..close()
    ..moveTo(554.1, 159.4)
    ..cubicTo(585.2, 122.5, 607.2, 71.3, 607.2, 20.1)
    ..cubicTo(607.2, 13, 606.6, 5.8, 605.3, 0)
    ..cubicTo(554.7, 1.9, 494.5, 33.7, 458.2, 75.8)
    ..cubicTo(429.7, 108.2, 403.1, 159.4, 403.1, 211.3)
    ..cubicTo(403.1, 219.1, 404.4, 226.9, 405, 229.4)
    ..cubicTo(408.2, 230, 413.4, 230.7, 418.6, 230.7)
    ..cubicTo(464, 230.7, 521.1, 200.3, 554.1, 159.4)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.height / 1000)
      ..drawPath(_logo, Paint()..color = Colors.white)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google's four-colour "G" (viewBox 48 × 48).
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static final Path _red = Path()
    ..moveTo(24, 9.5)
    ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
    ..lineTo(40.06, 6.25)
    ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
    ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
    ..lineTo(10.54, 19.41)
    ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
    ..close();

  static final Path _blue = Path()
    ..moveTo(46.98, 24.55)
    ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
    ..lineTo(24, 20)
    ..lineTo(24, 29.02)
    ..lineTo(36.94, 29.02)
    ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
    ..lineTo(39.89, 42.2)
    ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
    ..close();

  static final Path _yellow = Path()
    ..moveTo(10.53, 28.59)
    ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
    ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
    ..lineTo(2.55, 13.22)
    ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
    ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
    ..lineTo(10.53, 28.59)
    ..close();

  static final Path _green = Path()
    ..moveTo(24, 48)
    ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
    ..lineTo(32.16, 36.19)
    ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
    ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
    ..lineTo(2.55, 34.77)
    ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 48)
      ..drawPath(_red, Paint()..color = const Color(0xFFEA4335))
      ..drawPath(_blue, Paint()..color = const Color(0xFF4285F4))
      ..drawPath(_yellow, Paint()..color = const Color(0xFFFBBC05))
      ..drawPath(_green, Paint()..color = const Color(0xFF34A853))
      ..restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
