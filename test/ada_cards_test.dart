// Ada's confirmation cards stay in step with the server (26 Oct 2026).
//
// In one conversation the app showed "9 changes waiting" for five tasks: cards
// the server had replaced or moved stayed on screen and in the count, because
// the app only ever learned about a card from the reply that carried it. And
// "Decline all" decided every pending card in the chat, seen or not.

import 'package:aqademiq/data/dtos/ada_message_dto.dart';
import 'package:aqademiq/data/models/ada_action.dart';
import 'package:aqademiq/data/repositories/ada_repository.dart';
import 'package:aqademiq/data/sources/ada_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdaAction card(String id, {String? messageId, AdaActionStatus status = AdaActionStatus.pending}) => AdaAction(
      id: id,
      operation: AdaActionOperation.create,
      resource: 'task',
      title: 'Add task “$id”',
      status: status,
      messageId: messageId,
    );

/// A scripted server: each reply hands back the next queued turn, and
/// `pendingActions` answers with whatever the test says is waiting.
class FakeAdaSource implements AdaSource {
  final List<AdaTurn> replies = [];
  List<AdaAction> serverPending = [];
  List<String>? lastDecideIds;
  int _n = 0;

  @override
  String? conversationId = 'c1';

  @override
  Future<AdaTurn> reply(String userText, List<AdaMessageDto> history, {List<AdaAttachmentRef> attachments = const []}) async =>
      replies.removeAt(0);

  @override
  Future<List<AdaAction>> pendingActions() async => serverPending;

  @override
  Future<AdaBulkDecision> decideAll({required bool approve, List<String>? actionIds}) async {
    lastDecideIds = actionIds;
    return (
      actions: [for (final id in actionIds ?? <String>[]) card(id, status: approve ? AdaActionStatus.executed : AdaActionStatus.rejected)],
      followUps: <AdaTurn>[],
    );
  }

  AdaTurn turn(List<AdaAction> actions) =>
      (message: AdaMessageDto(id: 'm${++_n}', role: 'ada', text: 'reply'), actions: actions);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAdaSource source;
  late ProviderContainer container;
  AdaChatController chat() => container.read(adaChatProvider.notifier);
  AdaChatState state() => container.read(adaChatProvider);

  setUp(() {
    source = FakeAdaSource();
    container = ProviderContainer(overrides: [
      adaRepositoryProvider.overrideWithValue(AdaRepository(source)),
    ]);
  });
  tearDown(() => container.dispose());

  test('a card the server moved to a newer reply shows once, under the newer one', () async {
    source.replies
      ..add(source.turn([card('a')]))
      ..add(source.turn([card('a')])); // re-proposed; the server reused the card
    source.serverPending = [card('a')];

    await chat().send('add a');
    await chat().send('yes');
    await settle();

    expect(state().actionsByMessage['m1'], isEmpty);
    expect(state().actionsByMessage['m2']!.map((a) => a.id), ['a']);
    expect(state().outstandingActions.length, 1);
  });

  test('a card the server no longer has waiting stops being counted', () async {
    source.replies.add(source.turn([card('old'), card('kept')]));
    source.serverPending = [card('kept')]; // "old" was replaced by a corrected card
    await chat().send('add two');
    await settle();

    expect(state().outstandingActions.map((a) => a.id), ['kept']);
    final old = state().actionsByMessage['m1']!.firstWhere((a) => a.id == 'old');
    expect(old.status, AdaActionStatus.superseded);
  });

  test('a card waiting on the server but missing here appears under the latest reply', () async {
    source.replies.add(source.turn(const []));
    source.serverPending = [card('nudge', messageId: 'not-on-screen')];
    await chat().send('hi');
    await settle();

    expect(state().actionsByMessage['m1']!.map((a) => a.id), ['nudge']);
  });

  test('decide all sends only the cards on screen', () async {
    source.replies.add(source.turn([card('x'), card('y')]));
    source.serverPending = [card('x'), card('y')];
    await chat().send('two things');
    await settle();

    await chat().decideAll(approve: false);
    expect(source.lastDecideIds, unorderedEquals(['x', 'y']));
  });
}
