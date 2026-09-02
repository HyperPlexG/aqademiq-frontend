import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/task.dart';
import '../../features/ada/presentation/ada_screen.dart';
import '../../features/auth/presentation/guest_ada_prompt.dart';
import '../../features/auth/presentation/guest_save_prompt.dart';
import '../../features/auth/presentation/guest_stats_prompt.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signin_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/feedback/presentation/feedback_board_screen.dart';
import '../../features/feedback/presentation/feedback_detail_screen.dart';
import '../../features/focus/presentation/focus_end_screen.dart';
import '../../features/focus/presentation/timer_screen.dart';
import '../../features/ice_breakers/presentation/ice_breaker_screen.dart';
import '../../features/ice_breakers/presentation/ice_breakers_screen.dart';
import '../../features/mood/presentation/mood_evening_screen.dart';
import '../../features/mood/presentation/mood_morning_screen.dart';
import '../../features/onboarding/presentation/ada_loading_screen.dart';
import '../../features/onboarding/presentation/ob_age_screen.dart';
import '../../features/onboarding/presentation/ob_blocked_screen.dart';
import '../../features/onboarding/presentation/ob_consent_screen.dart';
import '../../features/onboarding/presentation/ob_mood_screen.dart';
import '../../features/onboarding/presentation/ob_name_screen.dart';
import '../../features/onboarding/presentation/ob_peak_screen.dart';
import '../../features/onboarding/presentation/ob_prism_screen.dart';
import '../../features/onboarding/presentation/ob_referral_screen.dart';
import '../../features/onboarding/presentation/ob_study_screen.dart';
import '../../features/onboarding/presentation/ob_syllabus_screen.dart';
import '../../features/plan/presentation/add_task_screen.dart';
import '../../features/plan/presentation/plan_screen.dart';
import '../../features/settings/presentation/settings_email_screen.dart';
import '../../features/settings/presentation/settings_home_screen.dart';
import '../../features/settings/presentation/settings_memories_screen.dart';
import '../../features/settings/presentation/settings_notif_screen.dart';
import '../../features/settings/presentation/settings_profile_screen.dart';
import '../../features/settings/presentation/settings_sounds_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/stats/presentation/stats_screen.dart';
import '../../features/subjects/presentation/subject_detail_screen.dart';
import '../../features/subjects/presentation/subjects_screen.dart';

/// Route paths. Tab branch order MUST match the `NavTab` semantic indices
/// (subjects 0 · planner 1 · timer 2 · stats 3 · ada 4).
abstract final class Routes {
  // Entry & auth (full-screen, outside the tab shell).
  static const splash = '/';
  static const welcome = '/welcome';
  static const signin = '/signin';
  static const signup = '/signup';
  static const verify = '/verify';
  static const resetPassword = '/reset-password';

  // Onboarding steps.
  static const obAge = '/onboarding/age';
  static const obBlocked = '/onboarding/age-blocked';
  static const obConsent = '/onboarding/consent';
  static const obReferral = '/onboarding/referral';
  static const obName = '/onboarding/name';
  static const obStudy = '/onboarding/study';
  static const obMood = '/onboarding/mood';
  static const obSyllabus = '/onboarding/syllabus';
  static const obPeak = '/onboarding/peak';
  static const obPrism = '/onboarding/prism';
  static const obLoading = '/onboarding/building';

  // Guest gating prompts (pushed over the shell).
  static const guestAda = '/unlock/ada';
  static const guestStats = '/unlock/stats';
  static const guestSave = '/unlock/save';

  // Plan sub-routes (pushed over the shell).
  static const addTask = '/plan/add';

  // Focus session complete (full-screen, pushed over the shell).
  static const focusEnd = '/focus/end';

  // Settings (full-screen, pushed over the shell).
  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const settingsNotif = '/settings/notifications';
  static const settingsSounds = '/settings/prism';
  static const settingsMemories = '/settings/memories';
  static const settingsEmail = '/settings/email';

  // Feedback board (full-screen, pushed over the shell).
  // Ice Breakers — the tutorial shelf. Full-screen and pushed, not a tab, so
  // it covers the bottom nav the way the feedback board does. Deep-linkable to
  // one video so the empty-planner CTA can open exactly the right one.
  static const iceBreakers = '/ice-breakers';
  static String iceBreaker(String id) => '/ice-breakers/$id';

  static const settingsFeedback = '/settings/feedback';
  static String feedbackPost(String id) => '/settings/feedback/post/$id';

  // Mood check-ins (full-screen, time/system-triggered).
  static const moodMorning = '/mood/morning';
  static const moodEvening = '/mood/evening';

  // Tab shell destinations.
  static const subjects = '/subjects';
  static String subjectDetail(String id) => '/subjects/detail/$id';
  static const plan = '/plan';
  static const timer = '/timer';
  static const stats = '/stats';
  static const ada = '/ada';
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.signin, builder: (_, _) => const SigninScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
      GoRoute(path: Routes.verify, builder: (_, _) => const OtpScreen()),
      GoRoute(path: Routes.resetPassword, builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(path: Routes.guestAda, builder: (_, _) => const GuestAdaPrompt()),
      GoRoute(path: Routes.guestStats, builder: (_, _) => const GuestStatsPrompt()),
      GoRoute(path: Routes.guestSave, builder: (_, _) => const GuestSavePrompt()),
      GoRoute(path: Routes.obAge, builder: (_, _) => const ObAgeScreen()),
      GoRoute(path: Routes.obBlocked, builder: (_, _) => const ObBlockedScreen()),
      GoRoute(path: Routes.obConsent, builder: (_, _) => const ObConsentScreen()),
      GoRoute(path: Routes.obReferral, builder: (_, _) => const ObReferralScreen()),
      GoRoute(path: Routes.obName, builder: (_, _) => const ObNameScreen()),
      GoRoute(path: Routes.obStudy, builder: (_, _) => const ObStudyScreen()),
      GoRoute(path: Routes.obMood, builder: (_, _) => const ObMoodScreen()),
      GoRoute(path: Routes.obSyllabus, builder: (_, _) => const ObSyllabusScreen()),
      GoRoute(path: Routes.obPeak, builder: (_, _) => const ObPeakScreen()),
      GoRoute(path: Routes.obPrism, builder: (_, _) => const ObPrismScreen()),
      GoRoute(path: Routes.obLoading, builder: (_, _) => const AdaLoadingScreen()),
      GoRoute(
        path: Routes.addTask,
        // `extra` carries the task to edit (null → create a new task).
        builder: (_, state) => AddTaskScreen(existing: state.extra as Task?),
      ),
      GoRoute(path: Routes.focusEnd, builder: (_, _) => const FocusEndScreen()),
      GoRoute(path: Routes.moodMorning, builder: (_, _) => const MoodMorningScreen()),
      GoRoute(path: Routes.moodEvening, builder: (_, _) => const MoodEveningScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsHomeScreen()),
      GoRoute(path: Routes.settingsProfile, builder: (_, _) => const SettingsProfileScreen()),
      GoRoute(path: Routes.settingsNotif, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.settingsSounds, builder: (_, _) => const PrismSettingsScreen()),
      GoRoute(path: Routes.settingsMemories, builder: (_, _) => const SettingsMemoriesScreen()),
      GoRoute(path: Routes.settingsEmail, builder: (_, _) => const EmailSettingsScreen()),
      GoRoute(
      path: Routes.iceBreakers,
      builder: (_, _) => const IceBreakersScreen(),
      routes: [
        // Nested so a back gesture from a video lands on the section rather
        // than wherever the student happened to open it from.
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              IceBreakerScreen(id: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(path: Routes.settingsFeedback, builder: (_, _) => const FeedbackBoardScreen()),
      GoRoute(
        path: '/settings/feedback/post/:id',
        builder: (_, state) => FeedbackDetailScreen(id: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0 — Subjects
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.subjects,
                builder: (_, _) => const SubjectsScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (_, state) => SubjectDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // 1 — Planner
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.plan, builder: (_, _) => const PlanScreen()),
            ],
          ),
          // 2 — Timer
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.timer, builder: (_, _) => const TimerScreen()),
            ],
          ),
          // 3 — Stats
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.stats, builder: (_, _) => const StatsScreen()),
            ],
          ),
          // 4 — Ada
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.ada, builder: (_, _) => const AdaScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
