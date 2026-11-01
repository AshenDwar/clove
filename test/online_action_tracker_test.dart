import 'package:clove/services/online_action_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('play and add progress advance between native reports', (
    tester,
  ) async {
    final tracker = OnlineActionTracker.instance;
    const trackKey = 'progress-estimate-test';

    tracker.beginOpening(trackKey);
    tracker.updateOpeningProgress(trackKey, 0);

    await tester.pump(const Duration(seconds: 2));

    final inProgress = tracker.openingProgress(trackKey);
    expect(inProgress, isNotNull);
    expect(inProgress, greaterThan(0));
    expect(inProgress, lessThan(1));

    tracker.updateOpeningProgress(trackKey, 1);
    expect(tracker.openingProgress(trackKey), 1);
    tracker.finishOpening(trackKey);
    expect(tracker.isOpening(trackKey), isFalse);

    const addTrackKey = 'add-progress-estimate-test';
    tracker.beginQueueing(addTrackKey);
    tracker.updateQueueingProgress(addTrackKey, 0);

    await tester.pump(const Duration(seconds: 2));

    final addProgress = tracker.queueingProgress(addTrackKey);
    expect(addProgress, isNotNull);
    expect(addProgress, greaterThan(0));
    expect(addProgress, lessThan(1));

    tracker.updateQueueingProgress(addTrackKey, 1);
    expect(tracker.queueingProgress(addTrackKey), 1);
    tracker.finishQueueing(addTrackKey);
    expect(tracker.isQueueing(addTrackKey), isFalse);
  });
}
