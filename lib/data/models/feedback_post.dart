import 'package:meta/meta.dart';

import 'enums.dart';

/// A feedback-board suggestion. The UI model widgets consume (mock-stable);
/// DTO drift is absorbed by `data/adapters` (README §7 seam 2).
///
/// Hand-written immutable class (deliberately codegen-free, like
/// `models/enums.dart`) so the feedback feature builds without a
/// `build_runner` pass.
@immutable
class FeedbackPost {
  const FeedbackPost({
    required this.id,
    required this.number,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.status = FeedbackStatus.underReview,
    this.category = FeedbackCategory.feature,
    this.votes = 0,
    this.hasVoted = false,
    this.commentCount = 0,
    this.author = '',
  });

  final String id;

  /// Human-facing sequence number shown as `#12` on cards.
  final int number;
  final String title;
  final String body;
  final FeedbackStatus status;
  final FeedbackCategory category;
  final int votes;

  /// Whether the current user has upvoted this post.
  final bool hasVoted;
  final int commentCount;
  final String author;
  final DateTime createdAt;

  FeedbackPost copyWith({
    String? id,
    int? number,
    String? title,
    String? body,
    FeedbackStatus? status,
    FeedbackCategory? category,
    int? votes,
    bool? hasVoted,
    int? commentCount,
    String? author,
    DateTime? createdAt,
  }) =>
      FeedbackPost(
        id: id ?? this.id,
        number: number ?? this.number,
        title: title ?? this.title,
        body: body ?? this.body,
        status: status ?? this.status,
        category: category ?? this.category,
        votes: votes ?? this.votes,
        hasVoted: hasVoted ?? this.hasVoted,
        commentCount: commentCount ?? this.commentCount,
        author: author ?? this.author,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackPost &&
          other.id == id &&
          other.number == number &&
          other.title == title &&
          other.body == body &&
          other.status == status &&
          other.category == category &&
          other.votes == votes &&
          other.hasVoted == hasVoted &&
          other.commentCount == commentCount &&
          other.author == author &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        number,
        title,
        body,
        status,
        category,
        votes,
        hasVoted,
        commentCount,
        author,
        createdAt,
      );
}

/// A comment under a [FeedbackPost].
@immutable
class FeedbackComment {
  const FeedbackComment({
    required this.id,
    required this.postId,
    required this.createdAt,
    this.author = '',
    this.body = '',
    this.isTeam = false,
  });

  final String id;
  final String postId;
  final String author;
  final String body;

  /// Marks official Aqademiq-team replies (badged in the UI).
  final bool isTeam;
  final DateTime createdAt;

  FeedbackComment copyWith({
    String? id,
    String? postId,
    String? author,
    String? body,
    bool? isTeam,
    DateTime? createdAt,
  }) =>
      FeedbackComment(
        id: id ?? this.id,
        postId: postId ?? this.postId,
        author: author ?? this.author,
        body: body ?? this.body,
        isTeam: isTeam ?? this.isTeam,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackComment &&
          other.id == id &&
          other.postId == postId &&
          other.author == author &&
          other.body == body &&
          other.isTeam == isTeam &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, postId, author, body, isTeam, createdAt);
}
