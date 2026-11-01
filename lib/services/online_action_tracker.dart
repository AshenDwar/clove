import 'dart:async';

import 'package:flutter/foundation.dart';

class _ProgressSample {
  _ProgressSample(this.progress, this.etaSeconds);

  final double progress;
  final int etaSeconds;
  int elapsedMilliseconds = 0;
}

/// Tracks online actions outside a screen so pending indicators survive
/// navigating away from Search and returning to the same result.
class OnlineActionTracker extends ChangeNotifier {
  OnlineActionTracker._();

  static final instance = OnlineActionTracker._();

  static const int _fallbackProgressEstimateSeconds = 20;

  final Map<String, int> _openingCounts = {};
  final Map<String, int> _queueingCounts = {};
  final Map<String, double?> _openingProgress = {};
  final Map<String, double?> _queueingProgress = {};
  final Map<String, _ProgressSample> _progressSamples = {};
  final Map<String, Timer> _progressTimers = {};

  bool isOpening(String trackKey) => (_openingCounts[trackKey] ?? 0) > 0;

  bool isQueueing(String trackKey) => (_queueingCounts[trackKey] ?? 0) > 0;

  double? openingProgress(String trackKey) => _openingProgress[trackKey];

  double? queueingProgress(String trackKey) => _queueingProgress[trackKey];

  void beginOpening(String trackKey) {
    _openingProgress.putIfAbsent(trackKey, () => null);
    _increment(_openingCounts, trackKey);
  }

  void updateOpeningProgress(
    String trackKey,
    double? progress, {
    int? etaSeconds,
  }) => _updateProgress(
    trackKey,
    progress,
    etaSeconds: etaSeconds,
    scope: 'opening',
    values: _openingProgress,
    isActive: () => isOpening(trackKey),
  );

  void updateQueueingProgress(
    String trackKey,
    double? progress, {
    int? etaSeconds,
  }) => _updateProgress(
    trackKey,
    progress,
    etaSeconds: etaSeconds,
    scope: 'queueing',
    values: _queueingProgress,
    isActive: () => isQueueing(trackKey),
  );

  void _updateProgress(
    String trackKey,
    double? progress, {
    required int? etaSeconds,
    required String scope,
    required Map<String, double?> values,
    required bool Function() isActive,
  }) {
    if (!isActive()) return;
    final progressKey = '$scope:$trackKey';
    final value = progress?.clamp(0.0, 1.0).toDouble();
    if (value != null) {
      if (value >= 1) {
        values[trackKey] = 1;
        _stopProgressEstimate(progressKey);
      } else {
        final displayed = values[trackKey] ?? 0;
        final monotonicProgress = value > displayed ? value : displayed;
        values[trackKey] = monotonicProgress;

        final sample = _progressSamples[progressKey];
        final nativeProgressAdvanced =
            sample == null || value > sample.progress;
        if ((etaSeconds != null && etaSeconds > 0) || nativeProgressAdvanced) {
          _progressSamples[progressKey] = _ProgressSample(
            monotonicProgress,
            etaSeconds != null && etaSeconds > 0
                ? etaSeconds
                : _fallbackProgressEstimateSeconds,
          );
        }
        _startProgressEstimate(progressKey, values, isActive);
      }
    } else {
      values[trackKey] = null;
      _stopProgressEstimate(progressKey);
    }
    notifyListeners();
  }

  void _startProgressEstimate(
    String progressKey,
    Map<String, double?> values,
    bool Function() isActive,
  ) {
    if (_progressTimers.containsKey(progressKey)) return;
    _progressTimers[progressKey] = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _advanceProgressEstimate(progressKey, values, isActive),
    );
  }

  void _advanceProgressEstimate(
    String progressKey,
    Map<String, double?> values,
    bool Function() isActive,
  ) {
    final sample = _progressSamples[progressKey];
    if (sample == null || !isActive()) {
      _stopProgressEstimate(progressKey);
      return;
    }

    sample.elapsedMilliseconds += 100;
    final duration = sample.etaSeconds * 1000;
    final estimate =
        (sample.progress +
                (1 - sample.progress) * sample.elapsedMilliseconds / duration)
            .clamp(sample.progress, 0.99)
            .toDouble();
    final trackKey = progressKey.substring(progressKey.indexOf(':') + 1);
    final previous = values[trackKey] ?? sample.progress;
    if (estimate - previous >= 0.002) {
      values[trackKey] = estimate;
      notifyListeners();
    }
    if (estimate >= 0.99) _stopProgressEstimate(progressKey);
  }

  void _stopProgressEstimate(String progressKey) {
    _progressSamples.remove(progressKey);
    _progressTimers.remove(progressKey)?.cancel();
  }

  void finishOpening(String trackKey) {
    final count = _openingCounts[trackKey];
    if (count == null) return;
    if (count <= 1) {
      _openingCounts.remove(trackKey);
      _openingProgress.remove(trackKey);
      _stopProgressEstimate('opening:$trackKey');
    } else {
      _openingCounts[trackKey] = count - 1;
    }
    notifyListeners();
  }

  void beginQueueing(String trackKey) {
    _queueingProgress.putIfAbsent(trackKey, () => null);
    _increment(_queueingCounts, trackKey);
  }

  void finishQueueing(String trackKey) {
    final count = _queueingCounts[trackKey];
    if (count == null) return;
    if (count <= 1) {
      _queueingCounts.remove(trackKey);
      _queueingProgress.remove(trackKey);
      _stopProgressEstimate('queueing:$trackKey');
    } else {
      _queueingCounts[trackKey] = count - 1;
    }
    notifyListeners();
  }

  void _increment(Map<String, int> counts, String trackKey) {
    counts.update(trackKey, (count) => count + 1, ifAbsent: () => 1);
    notifyListeners();
  }
}
