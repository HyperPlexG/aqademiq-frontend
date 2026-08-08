/// Something Ada has stored about the user, carried into every conversation.
///
/// Plain immutable classes rather than freezed, matching `ada_action.dart` — the
/// Ada data layer keeps its models free of generated code, and these are only
/// ever read and deleted, never constructed by the client.
library;

/// What sort of thing is remembered. Drives the grouping on the screen, because
/// a hard constraint deserves different weight from a soft preference.
enum AdaMemoryKind {
  preference,
  constraint,
  pattern,
  goal,
  fact;

  static AdaMemoryKind parse(String? raw) => switch (raw) {
        'preference' => AdaMemoryKind.preference,
        'constraint' => AdaMemoryKind.constraint,
        'pattern' => AdaMemoryKind.pattern,
        'goal' => AdaMemoryKind.goal,
        _ => AdaMemoryKind.fact,
      };

  /// Section heading, phrased from the user's point of view.
  String get heading => switch (this) {
        AdaMemoryKind.preference => 'How you like to work',
        AdaMemoryKind.constraint => 'Your commitments',
        AdaMemoryKind.pattern => 'Patterns Ada has noticed',
        AdaMemoryKind.goal => "What you're working toward",
        AdaMemoryKind.fact => 'Other things Ada knows',
      };
}

/// Where a memory came from.
///
/// Worth surfacing plainly: `ada` means Ada worked it out by watching, which the
/// user never explicitly agreed to and is the thing they are most likely to want
/// corrected or removed.
enum AdaMemoryOrigin {
  user,
  ada;

  static AdaMemoryOrigin parse(String? raw) =>
      raw == 'user' ? AdaMemoryOrigin.user : AdaMemoryOrigin.ada;

  bool get isInferred => this == AdaMemoryOrigin.ada;

  String get label => switch (this) {
        AdaMemoryOrigin.user => 'You told Ada this',
        AdaMemoryOrigin.ada => 'Ada worked this out',
      };
}

class AdaMemory {
  const AdaMemory({
    required this.id,
    required this.kind,
    required this.content,
    required this.source,
    this.confidence = 3,
    this.subjectId,
    this.expiresAt,
    this.updatedAt,
  });

  factory AdaMemory.fromJson(Map<String, dynamic> json) => AdaMemory(
        id: json['id'] as String? ?? '',
        kind: AdaMemoryKind.parse(json['kind'] as String?),
        content: json['content'] as String? ?? '',
        source: AdaMemoryOrigin.parse(json['source'] as String?),
        confidence: (json['confidence'] as num?)?.toInt() ?? 3,
        subjectId: json['subject_id'] as String?,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );

  final String id;
  final AdaMemoryKind kind;
  final String content;
  final AdaMemoryOrigin source;

  /// 1–5. Inferences start lower and climb as Ada sees the same thing again.
  final int confidence;

  /// Set when the memory applies to a single subject rather than broadly.
  final String? subjectId;

  /// Set when it stops being true after a known date (e.g. exam week).
  final DateTime? expiresAt;
  final DateTime? updatedAt;
}
