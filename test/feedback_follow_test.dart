// FBK-6 (16 Oct 2026 test report): POST and DELETE /feedback/posts/:ref/subscribe
// existed and nothing in the app called them. Following has to take effect and
// stick, in mock mode as in live.

import 'package:aqademiq/data/sources/feedback_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('following a post sticks, and so does unfollowing', () async {
    final source = MockFeedbackSource();
    final id = (await source.posts()).posts.first.id;

    expect(await source.subscribed(id), isFalse);
    expect(await source.setSubscribed(id, subscribed: true), isTrue);
    expect(await source.subscribed(id), isTrue);
    expect(await source.setSubscribed(id, subscribed: false), isFalse);
    expect(await source.subscribed(id), isFalse);
  });

  test('following a post that does not exist fails rather than pretending', () {
    expect(
      () => MockFeedbackSource().setSubscribed('no-such-post', subscribed: true),
      throwsA(anything),
    );
  });
}
