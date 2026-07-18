import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/env.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/repositories/onboarding_repository.dart';
import '../../../data/repositories/subjects_repository.dart';

/// The multi-step onboarding draft (README §6: name, subjects, moods, peak time,
/// goal, prism) plus the PDPL age + consent captured on the first two steps
/// (`ONBOARDING_CONSENT_AGE_INTEGRATION.md`). Held across the step routes; on
/// [OnboardingController.finish] age + consent are submitted with the rest and
/// the guest is linked to a real account so the app shows the onboarded state.
class OnboardingDraft {
  const OnboardingDraft({
    this.age,
    this.consentGiven = false,
    this.consentVersion = '',
    this.referral = '',
    this.name = '',
    this.level = 'Undergraduate',
    this.subjects = const ['Engineering', 'CS'],
    this.subjectMoods = const {'Engineering': 2, 'Computer Science': 4},
    this.peakTimes = const ['Afternoon'],
    this.focusGoalHrs = 3,
    this.prismMode = 'Deep Work',
  });

  /// Age entered on the age gate (`ob-age`). Null until the user enters one.
  final int? age;

  /// Whether the user granted data-use consent (`ob-consent`).
  final bool consentGiven;

  /// The privacy/terms version shown on the consent screen when [consentGiven]
  /// was granted (audit trail). Empty when not yet consented.
  final String consentVersion;

  final String referral;
  final String name;
  final String level;
  final List<String> subjects;
  final Map<String, int> subjectMoods;
  final List<String> peakTimes;
  final double focusGoalHrs;
  final String prismMode;

  OnboardingDraft copyWith({
    int? age,
    bool? consentGiven,
    String? consentVersion,
    String? referral,
    String? name,
    String? level,
    List<String>? subjects,
    Map<String, int>? subjectMoods,
    List<String>? peakTimes,
    double? focusGoalHrs,
    String? prismMode,
  }) {
    return OnboardingDraft(
      age: age ?? this.age,
      consentGiven: consentGiven ?? this.consentGiven,
      consentVersion: consentVersion ?? this.consentVersion,
      referral: referral ?? this.referral,
      name: name ?? this.name,
      level: level ?? this.level,
      subjects: subjects ?? this.subjects,
      subjectMoods: subjectMoods ?? this.subjectMoods,
      peakTimes: peakTimes ?? this.peakTimes,
      focusGoalHrs: focusGoalHrs ?? this.focusGoalHrs,
      prismMode: prismMode ?? this.prismMode,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(OnboardingController.new);

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  /// Record the age from the age gate (`ob-age`).
  void setAge(int v) => state = state.copyWith(age: v);

  /// Record the consent decision + the policy version shown (`ob-consent`).
  void setConsent({required bool given, required String version}) =>
      state = state.copyWith(consentGiven: given, consentVersion: version);

  void setReferral(String v) => state = state.copyWith(referral: v);
  void setName(String v) => state = state.copyWith(name: v);
  void setLevel(String v) => state = state.copyWith(level: v);

  /// Peak times are multi-select (ONB-3) — tap toggles membership.
  void togglePeakTime(String v) {
    final next = [...state.peakTimes];
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(peakTimes: next);
  }

  void setFocusGoal(double v) => state = state.copyWith(focusGoalHrs: v);
  void setPrismMode(String v) => state = state.copyWith(prismMode: v);

  void toggleSubject(String s) {
    final next = [...state.subjects];
    next.contains(s) ? next.remove(s) : next.add(s);
    state = state.copyWith(subjects: next);
  }

  void setSubjectMood(String subject, int mood) =>
      state = state.copyWith(subjectMoods: {...state.subjectMoods, subject: mood});

  /// Default subject-color palette (README §3 study-tag palette) used when the
  /// onboarding UI doesn't collect a per-subject color.
  static const _palette = [
    '#6b5cf0', '#5cbbff', '#2a9d6b', '#e8a430', '#e85476', '#c0497b', '#7a8699',
  ];

  /// Completes onboarding. Live: submit `POST /onboarding/complete` (creates the
  /// semester + subjects server-side, records PDPL age + consent) and refresh
  /// the read models. Mock: keep the demo behavior of flipping the guest to an
  /// onboarded account.
  ///
  /// Throws an [OnboardingCompletionException] on rejection: the client-side
  /// guards below fail fast (doc §5 step 3), and the repository maps the
  /// server's 403/400/401 envelope to the same typed surface so the loading
  /// screen can route/keep the user on the right step.
  Future<void> finish() async {
    final draft = state;

    // Fail fast client-side, but the server stays the source of truth.
    if (!draft.consentGiven) {
      throw const ConsentRequiredException();
    }
    final age = draft.age;
    if (age == null || age < 18) {
      throw const AgeRestrictedException();
    }

    final subjects = [
      for (var i = 0; i < draft.subjects.length; i++)
        OnboardingSubjectEntry(
          name: draft.subjects[i],
          colorHex: _palette[i % _palette.length],
          mood: draft.subjectMoods[draft.subjects[i]] ?? 2,
        ),
    ];
    await ref.read(onboardingRepositoryProvider).complete(
          OnboardingSubmission(
            consentGiven: draft.consentGiven,
            consentVersion:
                draft.consentVersion.isEmpty ? null : draft.consentVersion,
            age: age,
            name: draft.name,
            educationLevel: draft.level,
            dailyFocusGoalMin: (draft.focusGoalHrs * 60).round(),
            subjects: subjects,
            referralCode: draft.referral.isEmpty ? null : draft.referral,
            workBestTimes: {'times': draft.peakTimes},
          ),
        );

    if (Env.useMocks) {
      final auth = ref.read(authRepositoryProvider);
      if (auth.currentUser?.isGuest ?? true) {
        await auth.linkGuestToAccount(
          email: 'you@aqademiq.app',
          password: 'onboarded',
        );
      }
    } else {
      ref
        ..invalidate(subjectsProvider)
        ..invalidate(semestersProvider);
    }
  }
}
