import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/user_settings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/widgets/settings_row.dart';
import 'widgets/settings_scaffold.dart';

/// settings-email — Email settings route. Loads real marketing-email opt-ins
/// (`/me/email-preferences`) and persists each toggle via PATCH.
class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen> {
  EmailPrefs? _prefs;

  Future<void> _save(EmailPrefs next) async {
    setState(() => _prefs = next);
    await ref.read(settingsRepositoryProvider).patchEmailPrefs(next).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    ref.listen(emailPrefsProvider, (_, next) {
      final v = next.value;
      if (v != null && _prefs == null) setState(() => _prefs = v);
    });
    final async = ref.watch(emailPrefsProvider);
    final prefs = _prefs;

    if (prefs == null) {
      return SettingsScaffold(
        title: 'Email settings',
        children: [
          const SizedBox(height: 40),
          Center(
            child: async.hasError
                ? Text(
                    "Couldn't load your email settings",
                    style: AppText.sans(size: 13, color: colors.textMed),
                  )
                : CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5),
          ),
        ],
      );
    }

    return SettingsScaffold(
      title: 'Email settings',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 20),
          child: Text(
            "We'll only reach out when it's genuinely useful — a new feature, "
            "a study tip, or the occasional offer. You're in control, and you "
            'can change this anytime.',
            style: AppText.sans(size: 13, height: 1.55, color: colors.text),
          ),
        ),
        SetGroup(
          children: [
            SettingsRow(
              label: 'Product updates',
              toggle: prefs.productUpdates,
              onToggle: (v) =>
                  unawaited(_save(prefs.copyWith(productUpdates: v))),
            ),
            SettingsRow(
              label: 'Study tips & guides',
              toggle: prefs.studyTips,
              onToggle: (v) => unawaited(_save(prefs.copyWith(studyTips: v))),
            ),
            SettingsRow(
              label: 'Offers & promotions',
              toggle: prefs.offers,
              onToggle: (v) => unawaited(_save(prefs.copyWith(offers: v))),
            ),
            SettingsRow(
              label: 'Research & surveys',
              toggle: prefs.surveys,
              onToggle: (v) => unawaited(_save(prefs.copyWith(surveys: v))),
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}
