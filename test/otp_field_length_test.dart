import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/auth/presentation/widgets/otp_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() =>
    buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet);

/// Guards the referral-code fix: the onboarding referral field is an OtpField,
/// and codes are 8 chars (backend generates randomBytes(4).hex). The field was
/// capped at 5, so a full code could never be typed. These assert an 8-length
/// field holds exactly 8 characters and refuses a 9th.
void main() {
  Future<String> enterInto(
    WidgetTester tester, {
    required int length,
    required String input,
  }) async {
    var latest = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: Scaffold(
          body: OtpField(
            length: length,
            keyboardType: TextInputType.text,
            inputFormatters: const [],
            onChanged: (v) => latest = v,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), input);
    await tester.pump();
    return latest;
  }

  testWidgets('a length-8 field accepts a full 8-character code', (tester) async {
    final value = await enterInto(tester, length: 8, input: '26332F5D');
    expect(value, '26332F5D');
    expect(value.length, 8);
  });

  testWidgets('a length-8 field caps input at 8 characters', (tester) async {
    final value = await enterInto(tester, length: 8, input: '26332F5DEXTRA');
    expect(value.length, 8, reason: 'input beyond the code length is dropped');
    expect(value, '26332F5D');
  });

  testWidgets('renders one box per character slot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: const Scaffold(body: OtpField(length: 8)),
      ),
    );
    // The hidden input is a single TextField; the visible boxes are its own
    // widgets. A length-8 field must offer room for all 8 characters.
    final field = tester.widget<TextField>(find.byType(TextField));
    final limiter = field.inputFormatters!
        .whereType<LengthLimitingTextInputFormatter>()
        .single;
    expect(limiter.maxLength, 8);
  });
}
