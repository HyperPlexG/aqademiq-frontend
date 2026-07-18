import '../dtos/app_user_dto.dart';
import '../dtos/feedback_dto.dart';
import '../dtos/focus_session_dto.dart';
import '../dtos/mood_log_dto.dart';
import '../dtos/subject_dto.dart';
import '../dtos/tag_dto.dart';
import '../dtos/task_dto.dart';
import '../dtos/user_stats_dto.dart';

/// Seed data for the mock sources. The PLAN_TIMELINE values mirror the v5
/// artboard exactly (Wednesday, JUN 2026; the four demo tasks) so the default
/// home screen is pixel-faithful out of the box.
abstract final class Fixtures {
  /// The demo "today" used by the default Plan view (artboard shows Wed, week 1–7).
  static final DateTime today = DateTime(2026, 6, 3);

  /// Course-code tags shown on the timeline (CC 401 violet, NLP 302 lecture-blue).
  static const List<TagDto> tags = [
    TagDto(id: 'cc401', label: 'CC 401', color: '#6b5cf0'),
    TagDto(id: 'nlp302', label: 'NLP 302', color: '#5cbbff'),
  ];

  /// Default study-tag palette (Settings CRUD seed) — README §3.
  static const List<TagDto> studyTagPalette = [
    TagDto(id: 'lecture', label: 'Lecture', color: '#5cbbff'),
    TagDto(id: 'class', label: 'Class', color: '#6b5cf0'),
    TagDto(id: 'exam', label: 'Exam', color: '#e85476'),
    TagDto(id: 'assignment', label: 'Assignment', color: '#2a9d6b'),
    TagDto(id: 'report', label: 'Report', color: '#e8a430'),
    TagDto(id: 'presentation', label: 'Presentation', color: '#c0497b'),
    TagDto(id: 'reading', label: 'Reading', color: '#7a8699'),
  ];

  static List<TaskDto> tasksForToday() => [
        // Anytime
        TaskDto(
          id: 't1',
          title: 'Read chapter 4',
          tagId: 'cc401',
          date: today,
          timeOfDay: 'anytime',
          durationMin: 10,
        ),
        TaskDto(
          id: 't2',
          title: 'Review lecture slides',
          tagId: 'nlp302',
          date: today,
          timeOfDay: 'anytime',
          durationMin: 5,
        ),
        // Planned
        TaskDto(
          id: 't3',
          title: 'LL(1) parsing notes',
          tagId: 'cc401',
          date: today,
          startTime: DateTime(2026, 6, 3, 11, 30),
          durationMin: 30,
          subtasks: const [
            SubtaskDto(id: 't3s1', title: 'Re-read grammar', done: true),
            SubtaskDto(id: 't3s2', title: 'Build parse table'),
            SubtaskDto(id: 't3s3', title: 'Trace an example'),
          ],
        ),
        TaskDto(
          id: 't4',
          title: 'Assignment 3 draft',
          tagId: 'nlp302',
          date: today,
          startTime: DateTime(2026, 6, 3, 12),
          durationMin: 30,
        ),
      ];

  static const List<SubjectDto> subjects = [
    SubjectDto(
      id: 'cc401',
      name: 'Compiler Construction',
      color: '#6b5cf0',
      semesterId: 'sem1',
      code: 'CC 401',
      targetGrade: 'A',
      professor: 'Prof. S. Rao',
      credits: 4,
      mood: 1,
      nextLabel: 'Viva · 3 days',
      focusHours: 4.5,
      fileCount: 3,
    ),
    SubjectDto(
      id: 'nlp302',
      name: 'Natural Language Processing',
      color: '#5cbbff',
      semesterId: 'sem1',
      code: 'NLP 302',
      targetGrade: 'A−',
      professor: 'Dr. A. Mehta',
      credits: 3,
      mood: 3,
      nextLabel: 'Assignment · Fri',
      focusHours: 2,
      fileCount: 2,
    ),
    SubjectDto(
      id: 'net305',
      name: 'Computer Networks',
      color: '#2a9d6b',
      semesterId: 'sem1',
      code: 'NET 305',
      targetGrade: 'B+',
      professor: 'Prof. K. Iyer',
      credits: 4,
      mood: 2,
      nextLabel: 'Lab · tomorrow',
      focusHours: 3,
      fileCount: 4,
    ),
    SubjectDto(
      id: 'dbs310',
      name: 'Database Systems',
      color: '#e8a430',
      semesterId: 'sem1',
      code: 'DBS 310',
      targetGrade: 'A',
      professor: 'Dr. N. Khan',
      mood: 3,
      focusHours: 1.5,
      fileCount: 1,
    ),
  ];

  static const List<SemesterDto> semesters = [
    SemesterDto(id: 'sem1', name: "Spring '26"),
  ];

  static const AppUserDto guestUser = AppUserDto(
    id: 'guest-local',
    name: 'Guest',
  );

  static final List<MoodLogDto> weekMoods = [
    MoodLogDto(id: 'm1', date: today.subtract(const Duration(days: 2)), phase: 'evening', mood: 3),
    MoodLogDto(id: 'm2', date: today.subtract(const Duration(days: 1)), phase: 'evening', mood: 2),
    MoodLogDto(id: 'm3', date: today, phase: 'morning', mood: 4),
  ];

  static UserStatsDto stats() => UserStatsDto(
        streakDays: 5,
        focusMinutesThisWeek: 220,
        tasksCompletedThisWeek: 12,
        weekMoods: weekMoods,
      );

  static const List<FocusSessionDto> recentSessions = [];

  /// Feedback-board seed — suggestions spread across every status column with
  /// realistic vote counts, so both the list and the kanban view demo well.
  /// `commentCount` values match the seeded [feedbackComments] rows.
  static List<FeedbackPostDto> feedbackPosts() => [
        FeedbackPostDto(
          id: 'fb1',
          number: 1,
          title: 'Repeat tasks every X days',
          body:
              'For things I do every 2 days regardless of the weekday — "review flashcards" might be Mon Wed Fri one week and Tue Thu Sat the next. Weekly repeat cannot model this.',
          status: 'planned',
          votes: 251,
          commentCount: 2,
          author: 'Maya',
          createdAt: today.subtract(const Duration(days: 44)),
        ),
        FeedbackPostDto(
          id: 'fb2',
          number: 2,
          title: "Vacation mode / cancel today's plan",
          body:
              'Disable notifications and pause the plan for a while without deleting anything. Coming back to 40 overdue tasks after a break is demotivating.',
          status: 'planned',
          votes: 198,
          author: 'Jonas',
          createdAt: today.subtract(const Duration(days: 39)),
        ),
        FeedbackPostDto(
          id: 'fb3',
          number: 3,
          title: 'Skip a task or mark it as incomplete',
          body:
              'Ability to mark a task as skipped by holding it instead of tapping. This way you can tell "done" apart from "did not get to it" in your history.',
          votes: 176,
          hasVoted: true,
          author: 'Priya',
          createdAt: today.subtract(const Duration(days: 35)),
        ),
        FeedbackPostDto(
          id: 'fb4',
          number: 4,
          title: 'Statistics to track completed tasks',
          body:
              'Add statistics to track the tasks performed per subject and per week — I want to see where my time actually goes.',
          status: 'in_progress',
          votes: 143,
          commentCount: 2,
          author: 'Alex',
          createdAt: today.subtract(const Duration(days: 31)),
        ),
        FeedbackPostDto(
          id: 'fb5',
          number: 5,
          title: "A 'Due by' option on tasks",
          body:
              "As a college student, I'd love my homework to show up on my day tab with its 'Due by' date and time, not just the day I plan to do it.",
          votes: 121,
          author: 'Sofia',
          createdAt: today.subtract(const Duration(days: 27)),
        ),
        FeedbackPostDto(
          id: 'fb6',
          number: 6,
          title: 'Home screen widgets',
          body:
              "A small widget with today's next task and the focus streak, so I don't have to open the app to remember what's next.",
          status: 'planned',
          votes: 96,
          author: 'Daniel',
          createdAt: today.subtract(const Duration(days: 24)),
        ),
        FeedbackPostDto(
          id: 'fb7',
          number: 7,
          title: 'Add a Pomodoro focus mode',
          body:
              'Classic 25/5 cycles with a long break every 4 rounds inside the focus timer.',
          status: 'exists_already',
          votes: 55,
          author: 'Hana',
          createdAt: today.subtract(const Duration(days: 21)),
        ),
        FeedbackPostDto(
          id: 'fb8',
          number: 8,
          title: 'Sort subjects by next deadline',
          body:
              'The subject list should be able to order itself by whatever is due soonest.',
          status: 'completed',
          votes: 64,
          commentCount: 1,
          author: 'Leo',
          createdAt: today.subtract(const Duration(days: 18)),
        ),
        FeedbackPostDto(
          id: 'fb9',
          number: 9,
          title: 'Keep the focus timer visible with anytime tasks',
          body:
              'Make the focus timer accessible while an anytime activity is running — right now starting one hides the other.',
          status: 'acknowledged',
          votes: 71,
          author: 'Ines',
          createdAt: today.subtract(const Duration(days: 14)),
        ),
        FeedbackPostDto(
          id: 'fb10',
          number: 10,
          title: 'Attach photos to tasks',
          body:
              'Let me snap the whiteboard or a worksheet and pin it to the task so everything I need is in one place.',
          votes: 39,
          author: 'Tomás',
          createdAt: today.subtract(const Duration(days: 10)),
        ),
        FeedbackPostDto(
          id: 'fb11',
          number: 11,
          title: 'Timeline feels cramped on small phones',
          body:
              'On a 5.4" screen the planned rows overlap their time labels. A compact density option would help.',
          status: 'acknowledged',
          category: 'improvement',
          votes: 27,
          author: 'Grace',
          createdAt: today.subtract(const Duration(days: 6)),
        ),
        FeedbackPostDto(
          id: 'fb12',
          number: 12,
          title: 'Reminders fire twice on some Android phones',
          body:
              'Task reminders arrive twice about a minute apart on my Pixel. Happens only when battery saver is off.',
          category: 'bug',
          votes: 18,
          author: 'Ravi',
          createdAt: today.subtract(const Duration(days: 3)),
        ),
      ];

  /// Comments for the seeded feedback posts (counts must stay in sync with
  /// each post's `commentCount` above).
  static List<FeedbackCommentDto> feedbackComments() => [
        FeedbackCommentDto(
          id: 'fbc1',
          postId: 'fb1',
          author: 'Aqademiq team',
          body:
              "This is on the roadmap — we're aiming for the next milestone. Keep the ideas coming!",
          isTeam: true,
          createdAt: today.subtract(const Duration(days: 12)),
        ),
        FeedbackCommentDto(
          id: 'fbc2',
          postId: 'fb1',
          author: 'Zara',
          body:
              'Would love this for language practice — every 2nd day is my whole routine.',
          createdAt: today.subtract(const Duration(days: 9)),
        ),
        FeedbackCommentDto(
          id: 'fbc3',
          postId: 'fb4',
          author: 'Aqademiq team',
          body:
              'In progress! A per-subject breakdown lands on the Stats tab first, weekly trends right after.',
          isTeam: true,
          createdAt: today.subtract(const Duration(days: 8)),
        ),
        FeedbackCommentDto(
          id: 'fbc4',
          postId: 'fb4',
          author: 'Noor',
          body: 'Please include focus minutes per subject too 🙏',
          createdAt: today.subtract(const Duration(days: 5)),
        ),
        FeedbackCommentDto(
          id: 'fbc5',
          postId: 'fb8',
          author: 'Aqademiq team',
          body: 'Shipped! Sort subjects → "Next deadline" in the ··· menu.',
          isTeam: true,
          createdAt: today.subtract(const Duration(days: 4)),
        ),
      ];
}
