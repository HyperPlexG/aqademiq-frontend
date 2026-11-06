// Undo on an added proposal, and Stop on a reply in flight (v11 `ada-applied`,
// `ada-thinking`).
//
// Undo is offered only where it can be true: the card is an approved "add
// task", and the app knows exactly which task it made — the id comes back in
// the action's `result`. Then Undo deletes that task through the ordinary tasks
// repository. Today's server does not send `result`, so these tests pin down
// both halves: with the id Undo works, without it no card offers it.
//
// There is no server cancel for a reply. Stop lets go on the client: the answer
// that lands afterwards is dropped.

import 'dart:async';

import 'package:aqademiq/data/dtos/ada_message_dto.dart';
import 'package:aqademiq/data/models/ada_action.dart';
import 'package:aqademiq/data/repositories/ada_repository.dart';
import 'package:aqademiq/data/repositories/tasks_repository.dart';
import 'package:aqademiq/data/sources/ada_source.dart';
import 'package:aqademiq/data/sources/tasks_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _addTaskJson({Object? result, String status = 'executed', String operation = 'create'}) => {
      'id': 'act-1',
      'operation': operation,
      'resource': 'task',
      'title': 'Add task “Proper workout”',
      'fields': [
        {'label': 'Date', 'to': '2026-11-04'},
      ],
      'status': status,
      'result': ?result,
    };

class _FakeAdaSource implements AdaSource {
  /// What opening a conversation returns.
  List<AdaTurn> history = [];

  /// The reply in flight, completed by the test.
  Completer<AdaTurn>? pendingReply;

  @override
  String? conversationId = 'c1';

  @override
  Future<List<AdaTurn>> messages(String conversationId) async => history;

  @override
  Future<AdaTurn> reply(String userText, List<AdaMessageDto> history, {List<AdaAttachmentRef> attachments = const []}) =>
      (pendingReply = Completer<AdaTurn>()).future;

  @override
  Future<List<AdaAction>> pendingActions() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _FakeTasksSource implements TasksSource {
  final deleted = <String>[];
  bool fail = false;

  @override
  Future<void> delete(String id) async {
    if (fail) throw StateError('offline');
    deleted.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

AdaTurn _turn(String id, List<AdaAction> actions) =>
    (message: AdaMessageDto(id: id, role: 'ada', text: 'Two tasks for today.'), actions: actions);

void main() {
  group('which cards can be undone', () {
    test('an added one-off task whose id came back can be undone', () {
      final a = AdaAction.fromJson(_addTaskJson(result: {'id': 'task-9', 'repeat': {'kind': 'none'}}));
      expect(a.createdTaskId, 'task-9');
      expect(a.canUndo, isTrue);
    });

    test("without the created task's id — today's server — there is no Undo", () {
      final a = AdaAction.fromJson(_addTaskJson());
      expect(a.status, AdaActionStatus.executed);
      expect(a.createdTaskId, isNull);
      expect(a.canUndo, isFalse);
    });

    test('a repeating task is not undone by deleting one day of it', () {
      expect(
        AdaAction.fromJson(_addTaskJson(result: {'id': 'series-1', 'repeat': {'kind': 'weekly'}})).canUndo,
        isFalse,
      );
      expect(
        AdaAction.fromJson(_addTaskJson(result: {'id': 'series-1@2026-11-04'})).canUndo,
        isFalse,
      );
    });

    test('an edit has nothing to put back, so no Undo', () {
      final a = AdaAction.fromJson(_addTaskJson(operation: 'update', result: {'id': 'task-9'}));
      expect(a.canUndo, isFalse);
    });

    test('a card still waiting cannot be undone', () {
      final a = AdaAction.fromJson(_addTaskJson(status: 'pending', result: {'id': 'task-9'}));
      expect(a.canUndo, isFalse);
    });
  });

  group('the chat', () {
    late _FakeAdaSource ada;
    late _FakeTasksSource tasks;
    late ProviderContainer container;
    AdaChatController chat() => container.read(adaChatProvider.notifier);
    AdaChatState state() => container.read(adaChatProvider);
    AdaAction card() => state().actionsByMessage['m1']!.single;

    setUp(() {
      ada = _FakeAdaSource();
      tasks = _FakeTasksSource();
      container = ProviderContainer(overrides: [
        adaRepositoryProvider.overrideWithValue(AdaRepository(ada)),
        tasksRepositoryProvider.overrideWithValue(TasksRepository(tasks)),
      ]);
    });
    tearDown(() => container.dispose());

    Future<void> openWithAddedTask() async {
      ada.history = [
        _turn('m1', [AdaAction.fromJson(_addTaskJson(result: {'id': 'task-9'}))]),
      ];
      await chat().openConversation('c1');
    }

    test('Undo deletes the task the approval created, and the card says so', () async {
      await openWithAddedTask();

      expect(await chat().undoAction('act-1'), isTrue);

      expect(tasks.deleted, ['task-9']);
      expect(card().undone, isTrue);
      expect(card().canUndo, isFalse);
      expect(state().decidingActionIds, isEmpty);
    });

    test('a second Undo does nothing', () async {
      await openWithAddedTask();
      await chat().undoAction('act-1');

      expect(await chat().undoAction('act-1'), isFalse);
      expect(tasks.deleted, ['task-9']);
    });

    test('when the delete fails the card still reads as added', () async {
      await openWithAddedTask();
      tasks.fail = true;

      expect(await chat().undoAction('act-1'), isFalse);
      expect(card().undone, isFalse);
      expect(card().canUndo, isTrue);
    });

    test('without the id, Undo touches nothing', () async {
      ada.history = [
        _turn('m1', [AdaAction.fromJson(_addTaskJson())]),
      ];
      await chat().openConversation('c1');

      expect(await chat().undoAction('act-1'), isFalse);
      expect(tasks.deleted, isEmpty);
    });

    test('an undone card stays undone when the chat is opened again', () async {
      await openWithAddedTask();
      await chat().undoAction('act-1');

      // The server still has the approval as executed.
      await chat().openConversation('c1');

      expect(card().undone, isTrue);
    });

    test('Stop drops the reply in flight', () async {
      final sending = chat().send('plan my week');
      await Future<void>.delayed(Duration.zero);
      expect(state().awaitingReply, isTrue);
      final asked = state().messages.single.id;

      chat().stop();
      expect(state().awaitingReply, isFalse);
      expect(state().typing, isFalse);
      expect(state().stoppedReplies, {asked});

      ada.pendingReply!.complete(_turn('late', const []));
      await sending;

      expect(state().messages.map((m) => m.id), [asked], reason: 'the late answer must not land');
    });

    test('a reply for a chat that was left does not land in the next one', () async {
      final sending = chat().send('plan my week');
      await Future<void>.delayed(Duration.zero);

      chat().newConversation();
      ada.pendingReply!.complete(_turn('late', const []));
      await sending;

      expect(state().messages, isEmpty);
    });
  });
}
