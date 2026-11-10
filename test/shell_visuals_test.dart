// The app-wide shell: where the floating nav sits, that it steps aside for the
// keyboard, the scroll-edge fades, the v11 light page, and that a page change
// always puts the keyboard away.

import 'dart:async';

import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/features/shell/presentation/app_shell.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/widgets/app_scaffold.dart';
import 'package:aqademiq/shared/widgets/bottom_nav.dart';
import 'package:aqademiq/shared/widgets/dismiss_keyboard.dart';
import 'package:aqademiq/shared/widgets/scroll_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// The design phone: iPhone 17, 402×874, at 3x.
const _dpr = 3.0;
const _phone = Size(402, 874);

void _phoneWith(WidgetTester tester, {double bottomInset = 34}) {
  tester.view
    ..devicePixelRatio = _dpr
    ..physicalSize = _phone * _dpr
    ..padding = FakeViewPadding(top: 62 * _dpr, bottom: bottomInset * _dpr)
    ..viewPadding = FakeViewPadding(top: 62 * _dpr, bottom: bottomInset * _dpr);
  addTearDown(tester.view.reset);
}

/// Reads what the page beneath the shell is told to clear.
double? _clearance;

/// The last row tapped on a tab page.
int? _tapped;

/// A tab page as the app builds one: an [AppScaffold], a header strip, a
/// list that runs on under the nav, and a text field.
class _TabPage extends StatelessWidget {
  const _TabPage(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    _clearance = AppScaffold.navClearanceOf(context);
    return AppScaffold(
      bottomClearance: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 56, child: Center(child: Text(label))),
          const TextField(key: ValueKey('field')),
          Expanded(
            child: ListView(
              key: const ValueKey('list'),
              padding: EdgeInsets.only(bottom: AppScaffold.navClearanceOf(context)),
              children: [
                for (var i = 0; i < 40; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tapped = i,
                    child: SizedBox(height: 60, child: Text('row $i')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

GoRouter _shellRouter() {
  StatefulShellBranch branch(String path, String label) => StatefulShellBranch(
        routes: [GoRoute(path: path, builder: (_, _) => _TabPage(label))],
      );
  return GoRouter(
    initialLocation: '/plan',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          branch('/subjects', 'SUBJECTS'),
          branch('/plan', 'PLAN'),
          branch('/timer', 'TIMER'),
          branch('/stats', 'STATS'),
          branch('/ada', 'ADA'),
        ],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, GoRouter router, {Brightness brightness = Brightness.light}) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(const NoopHapticsService()),
        isGuestProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(brightness: brightness, accent: AppAccent.violet),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The shell's fade behind the bar (bottom fades only; the page's own top
/// fade is a different one).
Finder get _navFade => find.byWidgetPredicate((w) => w is EdgeFade && !w.fromTop);

Finder get _topFade => find.byWidgetPredicate((w) => w is EdgeFade && w.fromTop);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('bottom nav', () {
    testWidgets('floats 22 above the bottom edge over a home indicator (v11 BNav)', (tester) async {
      _phoneWith(tester);
      await _pump(tester, _shellRouter());

      final nav = tester.getRect(find.byType(BottomNav));
      expect(nav.height, 61);
      expect(nav.bottom, _phone.height - 22);
      expect(nav.left, 22);
      expect(nav.right, _phone.width - 22);
      // The page clears the bar's top edge with 20 to breathe.
      expect(_clearance, 22 + 61 + 20);
      final box = tester.widget<Container>(
        find.descendant(of: find.byType(BottomNav), matching: find.byType(Container)).first,
      );
      expect(
        (box.decoration! as BoxDecoration).boxShadow,
        const [BoxShadow(color: Color(0x21000000), blurRadius: 28, offset: Offset(0, 4))],
      );
    });

    testWidgets('keeps 22 over an Android gesture handle', (tester) async {
      _phoneWith(tester, bottomInset: 24);
      await _pump(tester, _shellRouter());
      expect(tester.getRect(find.byType(BottomNav)).bottom, _phone.height - 22);
    });

    testWidgets('sits clear above Android 3-button navigation', (tester) async {
      _phoneWith(tester, bottomInset: 48);
      await _pump(tester, _shellRouter());
      expect(tester.getRect(find.byType(BottomNav)).bottom, _phone.height - 48 - 8);
      expect(_clearance, 48 + 8 + 61 + 20);
    });

    testWidgets('steps aside while the keyboard is up, and comes back', (tester) async {
      _phoneWith(tester);
      await _pump(tester, _shellRouter());
      expect(find.byType(BottomNav), findsOneWidget);

      await tester.showKeyboard(find.byKey(const ValueKey('field')).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * _dpr);
      await tester.pump();

      expect(find.byType(BottomNav), findsNothing);
      expect(_navFade, findsNothing);
      // Nothing reserves room for the hidden bar: the field rests just above
      // the keyboard.
      expect(_clearance, AppScaffold.keyboardGap);

      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.byType(BottomNav), findsOneWidget);
      expect(_clearance, 22 + 61 + 20);
    });
  });

  group('scroll fades', () {
    testWidgets('the nav fade runs behind the bar on every tab but Ada', (tester) async {
      _phoneWith(tester);
      final router = _shellRouter();
      await _pump(tester, router);

      expect(_navFade, findsOneWidget);
      final fade = _navFade;
      final rect = tester.getRect(fade);
      // Solid to the bar's midline (22 + 30.5), eased out 64 above it.
      expect(rect.bottom, _phone.height);
      expect(rect.height, 22 + 30.5 + 64);
      expect(tester.widget<EdgeFade>(fade).solid, 22 + 30.5);

      router.go('/ada');
      await tester.pumpAndSettle();
      expect(find.text('ADA'), findsOneWidget);
      expect(_navFade, findsNothing, reason: 'Ada runs her own fades');
    });

    testWidgets('a top fade appears once the list scrolls under the header, and never takes a tap',
        (tester) async {
      _phoneWith(tester);
      await _pump(tester, _shellRouter());

      expect(_topFade, findsNothing, reason: 'a list at rest shows no top fade');

      final list = find.byKey(const ValueKey('list'));
      tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable))).position.jumpTo(300);
      await tester.pumpAndSettle();
      expect(_topFade, findsOneWidget);
      expect(tester.widget<EdgeFade>(_topFade).opacity, 1);
      // It sits on the list's top edge, just under the header strip.
      expect(tester.getTopLeft(_topFade).dy, tester.getTopLeft(list).dy);

      // A row under the fade still takes the tap: the fade is never hit-tested.
      _tapped = null;
      await tester.tapAt(tester.getTopLeft(_topFade) + const Offset(40, 10));
      expect(_tapped, 5);

      // And one under the nav's fade, above the bar.
      _tapped = null;
      final navTop = tester.getRect(find.byType(BottomNav)).top;
      await tester.tapAt(Offset(40, navTop - 10));
      expect(_tapped, isNotNull);
    });

    testWidgets('fades and the page use the v11 light page, and the dark page in dark', (tester) async {
      _phoneWith(tester);
      await _pump(tester, _shellRouter());
      final ctx = tester.element(find.byType(AppShell));
      expect(ctx.colors.page, const Color(0xFFFBFCFD));
      expect(Theme.of(ctx).scaffoldBackgroundColor, const Color(0xFFFBFCFD));
      expect(ctx.colors.bg, const Color(0xFFECEFF3), reason: 'the well on white surfaces');
      expect(ctx.colors.hilite, const Color(0xFFE8EBF0));

      await _pump(tester, _shellRouter(), brightness: Brightness.dark);
      final dark = tester.element(find.byType(AppShell));
      expect(dark.colors.page, const Color(0xFF0E0E0E));
      expect(dark.colors.bg, const Color(0xFF0E0E0E));
    });
  });

  group('route change puts the keyboard away', () {
    GoRouter router() => GoRouter(
          initialLocation: '/name',
          observers: [DismissKeyboardObserver()],
          routes: [
            GoRoute(
              path: '/name',
              builder: (_, _) => const Scaffold(body: Center(child: TextField(key: ValueKey('name')))),
            ),
            GoRoute(
              path: '/feel',
              builder: (_, _) => const Scaffold(body: Center(child: Text('no field here'))),
            ),
            GoRoute(
              path: '/otp',
              builder: (_, _) => const Scaffold(
                body: Center(child: TextField(key: ValueKey('otp'), autofocus: true)),
              ),
            ),
          ],
        );

    EditableTextState editable(WidgetTester tester, String key) => tester.state<EditableTextState>(
          find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText)),
        );

    testWidgets('on push, the old field lets go and the keyboard hides', (tester) async {
      final r = router();
      await _pump(tester, r);
      await tester.showKeyboard(find.byKey(const ValueKey('name')));
      expect(tester.testTextInput.isVisible, isTrue);

      unawaited(r.push('/feel'));
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<EditableText>()));
      expect(tester.testTextInput.isVisible, isFalse);

      // Back again: the field does not grab focus back on its own.
      r.pop();
      await tester.pumpAndSettle();
      expect(editable(tester, 'name').widget.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('on go (a replace, as sign-in → Plan does) too', (tester) async {
      final r = router();
      await _pump(tester, r);
      await tester.showKeyboard(find.byKey(const ValueKey('name')));
      r.go('/feel');
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a page that autofocuses still gets its keyboard', (tester) async {
      final r = router();
      await _pump(tester, r);
      await tester.showKeyboard(find.byKey(const ValueKey('name')));

      unawaited(r.push('/otp'));
      await tester.pumpAndSettle();
      expect(editable(tester, 'otp').widget.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('the app router registers it on the root navigator and every tab branch', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final appRouter = container.read(routerProvider);
      addTearDown(appRouter.dispose);

      expect(appRouter.routerDelegate.builder.observers.whereType<DismissKeyboardObserver>(), hasLength(1));
      final shell = appRouter.configuration.routes.whereType<StatefulShellRoute>().single;
      expect(shell.branches, hasLength(5));
      for (final b in shell.branches) {
        expect(b.observers?.whereType<DismissKeyboardObserver>(), hasLength(1));
      }
    });
  });
}
