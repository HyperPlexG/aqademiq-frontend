/// A change Ada wants to make to the user's data, waiting on their approval.
///
/// The agent can only ever *propose*: the backend parks every create/update/
/// delete as a pending action and applies nothing until the user taps Approve.
/// These are plain immutable classes rather than freezed ones to match the rest
/// of Ada's data layer (`AdaConversationDto`, `AdaAttachmentRef` are records too)
/// and to keep the confirmation path free of generated code.
library;

/// Wire values of `ada_pending_actions.status`.
enum AdaActionStatus {
  pending,
  approved,
  executed,
  rejected,
  failed,
  superseded;

  static AdaActionStatus parse(String? raw) => switch (raw) {
        'approved' => AdaActionStatus.approved,
        'executed' => AdaActionStatus.executed,
        'rejected' => AdaActionStatus.rejected,
        'failed' => AdaActionStatus.failed,
        'superseded' => AdaActionStatus.superseded,
        _ => AdaActionStatus.pending,
      };

  bool get isPending => this == AdaActionStatus.pending;
  bool get isApplied => this == AdaActionStatus.executed;
  bool get isDeclined => this == AdaActionStatus.rejected;
  bool get isFailed => this == AdaActionStatus.failed;

  /// True once the user has decided — the card stops being interactive.
  bool get isDecided => !isPending;
}

/// What the change does, used to colour and label the card.
enum AdaActionOperation {
  create,
  update,
  delete;

  static AdaActionOperation parse(String? raw) => switch (raw) {
        'create' => AdaActionOperation.create,
        'delete' => AdaActionOperation.delete,
        _ => AdaActionOperation.update,
      };

  String get label => switch (this) {
        AdaActionOperation.create => 'Add',
        AdaActionOperation.update => 'Change',
        AdaActionOperation.delete => 'Delete',
      };
}

/// One line of the before/after diff shown on the card.
class AdaActionField {
  const AdaActionField({required this.label, this.from, this.to});

  factory AdaActionField.fromJson(Map<String, dynamic> json) => AdaActionField(
        label: json['label'] as String? ?? '',
        from: json['from'] as String?,
        to: json['to'] as String?,
      );

  final String label;
  final String? from;
  final String? to;

  /// True when this field is being changed rather than set for the first time.
  bool get isChange => from != null && from!.isNotEmpty;
}

class AdaAction {
  const AdaAction({
    required this.id,
    required this.operation,
    required this.resource,
    required this.title,
    this.fields = const [],
    this.warning,
    this.status = AdaActionStatus.pending,
    this.error,
    this.messageId,
  });

  factory AdaAction.fromJson(Map<String, dynamic> json) => AdaAction(
        id: json['id'] as String? ?? '',
        operation: AdaActionOperation.parse(json['operation'] as String?),
        resource: json['resource'] as String? ?? '',
        title: json['title'] as String? ?? 'Change',
        fields: (json['fields'] is List)
            ? (json['fields'] as List)
                .whereType<Map<String, dynamic>>()
                .map(AdaActionField.fromJson)
                .toList(growable: false)
            : const [],
        warning: json['warning'] as String?,
        status: AdaActionStatus.parse(json['status'] as String?),
        error: json['error'] as String?,
        messageId: json['message_id'] as String?,
      );

  final String id;
  final AdaActionOperation operation;

  /// `task` | `subject` | `semester` | `study_tag` | `mood` | `profile` | `settings`.
  final String resource;
  final String title;
  final List<AdaActionField> fields;
  final String? warning;
  final AdaActionStatus status;
  final String? error;
  final String? messageId;

  AdaAction copyWith({AdaActionStatus? status, String? error}) => AdaAction(
        id: id,
        operation: operation,
        resource: resource,
        title: title,
        fields: fields,
        warning: warning,
        status: status ?? this.status,
        error: error ?? this.error,
        messageId: messageId,
      );
}
