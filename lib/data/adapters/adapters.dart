import '../dtos/ada_message_dto.dart';
import '../dtos/app_user_dto.dart';
import '../dtos/feedback_dto.dart';
import '../dtos/focus_session_dto.dart';
import '../dtos/mood_log_dto.dart';
import '../dtos/subject_dto.dart';
import '../dtos/tag_dto.dart';
import '../dtos/task_dto.dart';
import '../dtos/user_stats_dto.dart';
import '../dtos/weekly_report_dto.dart';
import '../models/ada_message.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/feedback_meta.dart';
import '../models/feedback_post.dart';
import '../models/focus_session.dart';
import '../models/mood_log.dart';
import '../models/subject.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../models/user_stats.dart';
import '../models/weekly_report.dart';

/// The single seam (README §7, seam 2) that maps raw API DTOs onto the immutable
/// UI models widgets consume. When the NestJS schema drifts, this file changes —
/// not the 88 screens.

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

extension TaskDtoX on TaskDto {
  Task toModel() => Task(
        id: id,
        title: title,
        tagId: tagId,
        date: date,
        note: note,
        subjectId: subjectId,
        dayPart: DayPartX.fromWire(timeOfDay),
        startTime: startTime,
        durationMin: durationMin,
        repeat: repeat?.toModel(),
        subtasks: subtasks.map((s) => s.toModel()).toList(),
        done: done,
      );
}

extension SubtaskDtoX on SubtaskDto {
  Subtask toModel() => Subtask(id: id, title: title, done: done);
}

/// Reverse mappers (UI model -> DTO) for writes (create / update).
extension TaskX on Task {
  TaskDto toDto() => TaskDto(
        id: id,
        title: title,
        tagId: tagId,
        date: date,
        note: note,
        subjectId: subjectId,
        timeOfDay: dayPart?.wire,
        startTime: startTime,
        durationMin: durationMin,
        repeat: repeat?.toDto(),
        subtasks: subtasks.map((s) => s.toDto()).toList(),
        done: done,
      );
}

extension SubtaskX on Subtask {
  SubtaskDto toDto() => SubtaskDto(id: id, title: title, done: done);
}

extension RepeatRuleX on RepeatRule {
  RepeatRuleDto toDto() => RepeatRuleDto(
        frequency: frequency.name,
        interval: interval,
        weekdays: weekdays,
      );
}

extension RepeatRuleDtoX on RepeatRuleDto {
  RepeatRule toModel() => RepeatRule(
        frequency:
            _enumByName(RepeatFrequency.values, frequency, RepeatFrequency.none),
        interval: interval,
        weekdays: weekdays,
      );
}

extension SubjectDtoX on SubjectDto {
  Subject toModel() => Subject(
        id: id,
        name: name,
        color: color,
        semesterId: semesterId,
        code: code,
        target: target?.toModel(),
        targetGrade: targetGrade,
        professor: professor,
        credits: credits,
        mood: mood,
        nextLabel: nextLabel,
        focusHours: focusHours,
        fileCount: fileCount,
      );
}

extension SubjectTargetDtoX on SubjectTargetDto {
  SubjectTarget toModel() => SubjectTarget(
        kind: _enumByName(
          SubjectTargetKind.values,
          kind,
          SubjectTargetKind.gpa,
        ),
        value: value,
      );
}

extension SubjectX on Subject {
  SubjectDto toDto() => SubjectDto(
        id: id,
        name: name,
        color: color,
        semesterId: semesterId,
        code: code,
        target: target?.toDto(),
        targetGrade: targetGrade,
        professor: professor,
        credits: credits,
        mood: mood,
        nextLabel: nextLabel,
        focusHours: focusHours,
        fileCount: fileCount,
      );
}

extension SubjectTargetX on SubjectTarget {
  SubjectTargetDto toDto() => SubjectTargetDto(kind: kind.name, value: value);
}

extension SemesterDtoX on SemesterDto {
  Semester toModel() => Semester(id: id, name: name);
}

extension SemesterX on Semester {
  SemesterDto toDto() => SemesterDto(id: id, name: name);
}

extension TagDtoX on TagDto {
  Tag toModel() => Tag(id: id, label: label, color: color);
}

extension FocusSessionDtoX on FocusSessionDto {
  FocusSession toModel() => FocusSession(
        id: id,
        durationMin: durationMin,
        taskId: taskId,
        prismMode: prismMode,
        elapsedSec: elapsedSec,
        status: _enumByName(FocusStatus.values, status, FocusStatus.idle),
        startedAt: startedAt,
        completedAt: completedAt,
        endMood: endMood,
        controlArm: controlArm,
      );
}

extension MoodLogDtoX on MoodLogDto {
  MoodLog toModel() => MoodLog(
        id: id,
        date: date,
        phase: _enumByName(MoodPhase.values, phase, MoodPhase.adhoc),
        mood: mood,
        note: note,
      );
}

extension AdaMessageDtoX on AdaMessageDto {
  AdaMessage toModel() => AdaMessage(
        id: id,
        role: _enumByName(AdaRole.values, role, AdaRole.ada),
        text: text,
        createdAt: createdAt,
        hasPlan: hasPlan,
      );
}

extension AppUserDtoX on AppUserDto {
  AppUser toModel() => AppUser(
        id: id,
        name: name,
        email: email,
        university: university,
        program: program,
        gender: gender,
        avatarUrl: avatarUrl,
        isGuest: isGuest,
      );
}

extension UserStatsDtoX on UserStatsDto {
  UserStats toModel() => UserStats(
        streakDays: streakDays,
        focusMinutesLifetime: focusMinutesLifetime,
        tasksCompletedLifetime: tasksCompletedLifetime,
        totalActiveDays: totalActiveDays,
        weekMoods: weekMoods.map((m) => m.toModel()).toList(),
      );
}

extension FeedbackPostDtoX on FeedbackPostDto {
  FeedbackPost toModel() => FeedbackPost(
        id: id,
        number: number,
        title: title,
        body: body,
        status: FeedbackStatusX.fromWire(status),
        category: FeedbackCategoryX.fromWire(category),
        votes: votes,
        hasVoted: hasVoted,
        commentCount: commentCount,
        author: author,
        createdAt: createdAt,
      );
}

extension FeedbackPostX on FeedbackPost {
  FeedbackPostDto toDto() => FeedbackPostDto(
        id: id,
        number: number,
        title: title,
        body: body,
        status: status.wire,
        category: category.wire,
        votes: votes,
        hasVoted: hasVoted,
        commentCount: commentCount,
        author: author,
        createdAt: createdAt,
      );
}

extension FeedbackCommentDtoX on FeedbackCommentDto {
  FeedbackComment toModel() => FeedbackComment(
        id: id,
        postId: postId,
        author: author,
        body: body,
        isTeam: isTeam,
        createdAt: createdAt,
      );
}

extension FeedbackCommentX on FeedbackComment {
  FeedbackCommentDto toDto() => FeedbackCommentDto(
        id: id,
        postId: postId,
        author: author,
        body: body,
        isTeam: isTeam,
        createdAt: createdAt,
      );
}

extension FeedbackMetaDtoX on FeedbackMetaDto {
  FeedbackMeta toModel() => FeedbackMeta(
        statuses: statuses
            .map(
              (s) => FeedbackStatusMeta(
                key: s.key,
                label: s.label,
                color: s.color,
                onRoadmap: s.onRoadmap,
              ),
            )
            .toList(growable: false),
        categories: categories
            .map((c) => FeedbackCategoryMeta(key: c.key, label: c.label))
            .toList(growable: false),
      );
}

/// The weekly report. Mostly a widening of wire strings into types, with one
/// real decision: `date` arrives as `yyyy-MM-dd` and is parsed as a *local*
/// calendar day. The report is about days the student lived through, so a
/// UTC parse would shift the whole core by a band for anyone west of Greenwich.
DateTime _reportDay(String ymd) =>
    DateTime.tryParse(ymd)?.toLocal() ?? DateTime.now();

extension WeeklyReportDtoX on WeeklyReportDto {
  WeeklyReport toModel() => WeeklyReport(
        weekStart: _reportDay(weekStart),
        weekEnd: _reportDay(weekEnd),
        days: days.map((d) => d.toModel()).toList(growable: false),
        shape: WeekShape.fromWire(shape),
        activeDays: activeDays,
        daysOnBoard: daysOnBoard,
        subjects: subjects.map((s) => s.toModel()).toList(growable: false),
        subjectBasis: SubjectBasis.fromWire(subjectBasis),
        unattributedFocusMinutes: unattributedFocusMinutes,
        unattributedTasksCompleted: unattributedTasksCompleted,
        moment: moment?.toModel(),
        recovery: recovery?.toModel(),
        longestSession: longestSession?.toModel(),
        heldMinutes: heldMinutes,
        prismMix: prismMix.map((p) => p.toModel()).toList(growable: false),
        rhythmWeekdays: rhythmWeekdays,
        focusMinutes: focusMinutes,
        focusSessions: focusSessions,
        tasksCompleted: tasksCompleted,
      );
}

extension WeeklyReportDayDtoX on WeeklyReportDayDto {
  ReportDay toModel() => ReportDay(
        date: _reportDay(date),
        weekday: weekday,
        moodIndex: moodIndex,
        hasActivity: hasActivity,
        tasksCompleted: tasksCompleted,
        focusMinutes: focusMinutes,
        focusSessions: focusSessions,
      );
}

extension ReportSubjectDtoX on ReportSubjectDto {
  ReportSubject toModel() => ReportSubject(
        id: subjectId,
        name: name,
        colorHex: color,
        focusMinutes: focusMinutes,
        tasksCompleted: tasksCompleted,
        share: share,
      );
}

extension ReportMomentDtoX on ReportMomentDto {
  ReportMoment toModel() =>
      ReportMoment(date: _reportDay(date), title: title, subjectId: subjectId);
}

extension ReportRecoveryDtoX on ReportRecoveryDto {
  ReportRecovery toModel() => ReportRecovery(
        sessions: sessions,
        beforeAvg: beforeAvg,
        afterAvg: afterAvg,
        lift: lift,
      );
}

extension ReportLongestDtoX on ReportLongestDto {
  ReportLongest toModel() =>
      ReportLongest(minutes: minutes, date: _reportDay(date), taskTitle: taskTitle);
}

extension ReportPrismSliceDtoX on ReportPrismSliceDto {
  ReportPrismSlice toModel() =>
      ReportPrismSlice(presetId: presetId, name: name, sessions: sessions, share: share);
}
