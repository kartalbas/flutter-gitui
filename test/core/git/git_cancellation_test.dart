// The token's contract: idempotent cancel, callbacks fire exactly once, and
// a registration after cancellation fires immediately - the property that
// closes the race between "kill registered" and "already abandoned", so no
// git process can be leaked by ordering.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_gitui/core/git/git_cancellation.dart';

void main() {
  test('cancel flips the flag once and fires callbacks once', () {
    final token = GitCancellationToken();
    var fired = 0;
    token.onCancel(() => fired++);

    expect(token.isCancelled, isFalse);
    token.cancel();
    token.cancel();

    expect(token.isCancelled, isTrue);
    expect(fired, 1);
  });

  test('a registration after cancellation fires immediately', () {
    final token = GitCancellationToken();
    token.cancel();

    var fired = 0;
    token.onCancel(() => fired++);
    expect(fired, 1);
  });
}
