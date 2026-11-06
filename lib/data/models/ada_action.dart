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
    this.createdTaskId,
    this.undone = false,
  });

  factory AdaAction.fromJson(Map<String, dynamic> json) {
    final operation = AdaActionOperation.parse(json['operation'] as String?);
    final resource = json['resource'] as String? ?? '';
    return AdaAction(
      id: json['id'] as String? ?? '',
      operation: operation,
      resource: resource,
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
      createdTaskId: createdTaskIdFrom(
        json['result'],
        operation: operation,
        resource: resource,
      ),
    );
  }

  /// The task an approved "add task" card created, when the action says which.
  ///
  /// Read from the action's `result`: what the server's task create returned,
  /// which it already stores on the `ada_pending_actions` row. The wire shape
  /// (`pendingDto`) does not carry it yet, so against today's server this is
  /// always null and no card offers Undo — nothing here guesses at the id.
  ///
  /// Only a one-off task counts. A repeating one comes back as an occurrence id
  /// (`<series>@<date>`), and deleting that removes a single day, not the series
  /// Ada added: an Undo that does not undo.
  static String? createdTaskIdFrom(
    Object? result, {
    required AdaActionOperation operation,
    required String resource,
  }) {
    if (operation != AdaActionOperation.create || resource != 'task') return null;
    if (result is! Map) return null;
    final id = result['id'];
    if (id is! String || id.isEmpty || id.contains('@')) return null;
    final repeat = result['repeat'];
    if (repeat is Map) {
      final kind = repeat['kind'];
      if (kind != null && kind != 'none') return null;
    }
    return id;
  }

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

  /// The one-off task this card created once approved (see [createdTaskIdFrom]).
  final String? createdTaskId;

  /// Client-only: the student took the added task back with Undo. The server's
  /// row stays `executed` — there is no endpoint that records an undo — so this
  /// lives in the app's own state and is never sent anywhere.
  final bool undone;

  /// An added task that can be taken back: applied, not already undone, and the
  /// app knows exactly which task it was. Edits, moves and deletes never qualify
  /// — the app does not hold what they replaced, so it cannot put it back.
  bool get canUndo => status.isApplied && !undone && createdTaskId != null;

  AdaAction copyWith({AdaActionStatus? status, String? error, bool? undone}) => AdaAction(
        id: id,
        operation: operation,
        resource: resource,
        title: title,
        fields: fields,
        warning: warning,
        status: status ?? this.status,
        error: error ?? this.error,
        messageId: messageId,
        createdTaskId: createdTaskId,
        undone: undone ?? this.undone,
      );
}
