import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/models/retrain_status.dart';

void main() {
  group('RetrainJobStatus.fromJson', () {
    test('parses backend RetrainDtos shape', () {
      final status = RetrainJobStatus.fromJson({
        'phase': 'TRAINING',
        'decision': 'PENDING',
        'message': 'Training new model with feedback data...',
        'modelVersion': null,
        'metrics': null,
        'startedAt': '2026-07-14T12:00:00Z',
        'completedAt': null,
      });

      expect(status.status, RetrainStatus.running);
      expect(status.phase, 'training');
      expect(status.isRunning, isTrue);
      expect(status.decision, isNull);
    });

    test('parses completed promoted job with metrics', () {
      final status = RetrainJobStatus.fromJson({
        'phase': 'COMPLETED',
        'decision': 'PROMOTED',
        'message': 'Model promoted',
        'modelVersion': 'xgboost-retrain-1',
        'metrics': {
          'recall': 0.93,
          'current_recall': 0.89,
          'overfitting': 0.02,
        },
        'startedAt': '2026-07-14T12:00:00Z',
        'completedAt': '2026-07-14T12:05:00Z',
      });

      expect(status.status, RetrainStatus.completed);
      expect(status.decision, 'promoted');
      expect(status.details!.newRecall, closeTo(0.93, 0.001));
      expect(status.details!.modelReloaded, isTrue);
    });

    test('parses feedback counters from metrics.feedback', () {
      final status = RetrainJobStatus.fromJson({
        'phase': 'COMPLETED',
        'decision': 'DISCARDED',
        'message': 'Done',
        'modelVersion': 'xgboost-retrain-2',
        'metrics': {
          'recall': 0.88,
          'feedback': {
            'total_records': 3,
            'augmented_windows': 2,
          },
        },
      });

      expect(status.details!.feedbackRecords, 3);
      expect(status.details!.augmentedWindows, 2);
    });
  });
}
