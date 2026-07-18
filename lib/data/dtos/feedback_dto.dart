/// Wire DTOs for the feedback board (suggestions + comments).
///
/// Deliberately hand-written and codegen-free (like `models/enums.dart`) so the
/// feedback feature compiles without a `build_runner` pass; the shape mirrors
/// the freezed DTOs elsewhere in `data/dtos`. Convert to freezed later if the
/// codegen pipeline is convenient — nothing outside `data/` will notice.
library;

/// A suggestion on the feedback board.
class FeedbackPostDto {
  const FeedbackPostDto({
    required this.id,
    required this.number,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.status = 'open', // open|planned|in_progress|completed|acknowledged|exists_already
    this.category = 'feature', // feature|improvement|bug
    this.votes = 0,
    this.hasVoted = false,
    this.commentCount = 0,
    this.author = '',
  });

  factory FeedbackPostDto.fromJson(Map<String, dynamic> json) =>
      FeedbackPostDto(
        id: json['id'] as String? ?? '',
        number: (json['number'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        category: json['category'] as String? ?? 'feature',
        votes: (json['votes'] as num?)?.toInt() ?? 0,
        hasVoted: json['hasVoted'] as bool? ?? false,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        author: json['author'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;

  /// Human-facing sequence number shown as `#12` on cards.
  final int number;
  final String title;
  final String body;
  final String status;
  final String category;
  final int votes;

  /// Whether the current user has upvoted this post.
  final bool hasVoted;
  final int commentCount;
  final String author;
  final DateTime createdAt;

  FeedbackPostDto copyWith({
    String? id,
    int? number,
    String? title,
    String? body,
    String? status,
    String? category,
    int? votes,
    bool? hasVoted,
    int? commentCount,
    String? author,
    DateTime? createdAt,
  }) =>
      FeedbackPostDto(
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'number': number,
        'title': title,
        'body': body,
        'status': status,
        'category': category,
        'votes': votes,
        'hasVoted': hasVoted,
        'commentCount': commentCount,
        'author': author,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A comment under a feedback post.
class FeedbackCommentDto {
  const FeedbackCommentDto({
    required this.id,
    required this.postId,
    required this.createdAt,
    this.author = '',
    this.body = '',
    this.isTeam = false,
  });

  factory FeedbackCommentDto.fromJson(Map<String, dynamic> json) =>
      FeedbackCommentDto(
        id: json['id'] as String? ?? '',
        postId: json['postId'] as String? ?? '',
        author: json['author'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isTeam: json['isTeam'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String postId;
  final String author;
  final String body;

  /// Marks official Aqademiq-team replies (badged in the UI).
  final bool isTeam;
  final DateTime createdAt;

  FeedbackCommentDto copyWith({
    String? id,
    String? postId,
    String? author,
    String? body,
    bool? isTeam,
    DateTime? createdAt,
  }) =>
      FeedbackCommentDto(
        id: id ?? this.id,
        postId: postId ?? this.postId,
        author: author ?? this.author,
        body: body ?? this.body,
        isTeam: isTeam ?? this.isTeam,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'postId': postId,
        'author': author,
        'body': body,
        'isTeam': isTeam,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Board config from `GET /feedback/meta` (statuses + categories).
class FeedbackMetaDto {
  const FeedbackMetaDto({this.statuses = const [], this.categories = const []});

  final List<FeedbackStatusMetaDto> statuses;
  final List<FeedbackCategoryMetaDto> categories;
}

/// One `{ key, label, color, on_roadmap }` status entry.
class FeedbackStatusMetaDto {
  const FeedbackStatusMetaDto({
    required this.key,
    required this.label,
    this.color,
    this.onRoadmap = false,
  });

  final String key;
  final String label;
  final String? color;
  final bool onRoadmap;
}

/// One `{ key, label }` category entry.
class FeedbackCategoryMetaDto {
  const FeedbackCategoryMetaDto({required this.key, required this.label});

  final String key;
  final String label;
}
