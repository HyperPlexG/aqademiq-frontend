// Ada's proposals arriving tick once per arrival (haptic architecture §4,
// "05 · Ada"): not once per card, not on a rebuild, and not when a past chat
// with waiting cards is opened from history.

import 'package:aqademiq/data/models/ada_action.dart';
import 'package:aqademiq/data/models/ada_message.dart';
import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/repositories/ada_repository.dart';
import 'package:aqademiq/features/ada/presentation/ada_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const _you = AdaMessage(id: 'u1', role: AdaRole.user, text: 'Plan my week');
const _ada = AdaMessage(id: 'a1', role: AdaRole.ada, text: 'Here you go');

AdaAction _card(String id, {AdaActionStatus status = AdaActionStatus.pending}) =>
    AdaAction(id: id, operation: AdaActionOperation.create, resource: 'task', title: id, status: status);

void main() {
  test('a reply bringing three cards is one arrival', () {
    const asked = AdaChatState(messages: [_you], typing: true, awaitingReply: true);
    final replied = AdaChatState(
      messages: const [_you, _ada],
      actionsByMessage: {
        'a1': [_card('x'), _card('y'), _card('z')],
      },
    );
    expect(proposalsArrivedBetween(asked, replied), isTrue);
  });

  test('the same cards again are not an arrival', () {
    final state = AdaChatState(
      messages: const [_you, _ada],
      actionsByMessage: {
        'a1': [_card('x')],
      },
    );
    expect(proposalsArrivedBetween(state, state.copyWith(typing: true)), isFalse);
  });

  test('deciding a card is not an arrival', () {
    final before = AdaChatState(
      messages: const [_you, _ada],
      actionsByMessage: {
        'a1': [_card('x'), _card('y')],
      },
    );
    final after = before.copyWith(
      actionsByMessage: {
        'a1': [_card('x', status: AdaActionStatus.executed), _card('y')],
      },
    );
    expect(proposalsArrivedBetween(before, after), isFalse);
  });

  test('a card moved to a newer reply is not an arrival', () {
    const second = AdaMessage(id: 'a2', role: AdaRole.ada, text: 'Still waiting');
    final before = AdaChatState(
      messages: const [_you, _ada],
      actionsByMessage: {
        'a1': [_card('x')],
      },
    );
    final after = AdaChatState(
      messages: const [_you, _ada, second],
      actionsByMessage: {
        'a1': const [],
        'a2': [_card('x')],
      },
    );
    expect(proposalsArrivedBetween(before, after), isFalse);
  });

  test('a past chat opened from history is not an arrival', () {
    const loading = AdaChatState(typing: true);
    final loaded = AdaChatState(
      messages: const [_you, _ada],
      actionsByMessage: {
        'a1': [_card('x')],
      },
    );
    expect(proposalsArrivedBetween(loading, loaded), isFalse);
  });

  test("a decision's follow-up with a new card is an arrival", () {
    const followUp = AdaMessage(id: 'a2', role: AdaRole.ada, text: 'One more');
    final before = AdaChatState(
      messages: const [_you, _ada],
      actionsByMessage: {
        'a1': [_card('x', status: AdaActionStatus.executed)],
      },
    );
    final after = AdaChatState(
      messages: const [_you, _ada, followUp],
      actionsByMessage: {
        'a1': [_card('x', status: AdaActionStatus.executed)],
        'a2': [_card('w')],
      },
    );
    expect(proposalsArrivedBetween(before, after), isTrue);
  });
}
