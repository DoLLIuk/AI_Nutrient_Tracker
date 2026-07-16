import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/analytics.dart';
import 'package:my_new_app/firebase_analytics_adapter.dart';

void main() {
  test('encodes same-session diagnostic properties for Firebase', () {
    final parameters = encodeAnalyticsParameters(
      AnalyticsEvent(
        AnalyticsEvents.mealLoggedInExistingSession,
        properties: const {'source': 'manual', 'day_offset': 0},
      ),
    );

    expect(parameters, {'source': 'manual', 'day_offset': 0});
  });

  test('encodes booleans as Firebase-compatible integers', () {
    final parameters = encodeAnalyticsParameters(
      AnalyticsEvent(
        AnalyticsEvents.mealLogged,
        properties: const {'creates_new_session': false},
      ),
    );

    expect(parameters, {'creates_new_session': 0});
  });
}
