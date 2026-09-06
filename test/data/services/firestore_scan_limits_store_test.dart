import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/constants/app_constants.dart';
import 'package:highlighted_text_reader/data/services/firestore_scan_limits_store.dart';

void main() {
  test('uses a published 0 as a real cap', () {
    expect(
      FirestoreScanLimitsStore.parseMaxScansPerDay({'maxScansPerDay': 0}),
      0,
    );
  });

  test('uses a published positive cap', () {
    expect(
      FirestoreScanLimitsStore.parseMaxScansPerDay({'maxScansPerDay': 4}),
      4,
    );
  });

  test('falls back when the field is missing or invalid', () {
    expect(FirestoreScanLimitsStore.parseMaxScansPerDay(null), AppConstants.maxScansPerDay);
    expect(FirestoreScanLimitsStore.parseMaxScansPerDay({}), AppConstants.maxScansPerDay);
    expect(
      FirestoreScanLimitsStore.parseMaxScansPerDay({'maxScansPerDay': -1}),
      AppConstants.maxScansPerDay,
    );
    expect(
      FirestoreScanLimitsStore.parseMaxScansPerDay({'maxScansPerDay': 10001}),
      AppConstants.maxScansPerDay,
    );
  });
}
