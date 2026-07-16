import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/analytics.dart';

void main() {
  test('analytics event keeps an immutable copy of its properties', () {
    final source = <String, Object?>{'source': 'manual'};
    final event = AnalyticsEvent(
      AnalyticsEvents.mealLogged,
      properties: source,
    );
    source['source'] = 'ai';

    expect(event.name, AnalyticsEvents.mealLogged);
    expect(event.properties, {'source': 'manual'});
    expect(() => event.properties['source'] = 'other', throwsUnsupportedError);
  });

  test('beta core-loop event names stay stable', () {
    expect(AnalyticsEvents.appOpened, 'app_opened');
    expect(AnalyticsEvents.onboardingStarted, 'onboarding_started');
    expect(AnalyticsEvents.onboardingStepViewed, 'onboarding_step_viewed');
    expect(AnalyticsEvents.onboardingCompleted, 'onboarding_completed');
    expect(AnalyticsEvents.firstMealLogged, 'first_meal_logged');
    expect(AnalyticsEvents.mealLogged, 'meal_logged');
    expect(
      AnalyticsEvents.mealLoggedInExistingSession,
      'meal_logged_in_existing_session',
    );
    expect(AnalyticsEvents.photoAnalysisSucceeded, 'photo_analysis_succeeded');
    expect(AnalyticsEvents.photoAnalysisFailed, 'photo_analysis_failed');
    expect(AnalyticsEvents.manualFallbackUsed, 'manual_fallback_used');
    expect(AnalyticsEvents.mealEdited, 'meal_edited');
    expect(AnalyticsEvents.mealDeleted, 'meal_deleted');
  });
}
