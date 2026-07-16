import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A provider-independent analytics event.
///
/// Event properties must never contain meal names, images, body measurements,
/// API keys, request IDs, or other personal data.
class AnalyticsEvent {
  final String name;
  final Map<String, Object?> properties;

  AnalyticsEvent(this.name, {Map<String, Object?> properties = const {}})
    : properties = Map.unmodifiable(properties);
}

abstract interface class Analytics {
  void track(AnalyticsEvent event);
}

class AnalyticsEvents {
  static const appOpened = 'app_opened';
  static const onboardingStarted = 'onboarding_started';
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingCompleted = 'onboarding_completed';
  static const firstMealLogged = 'first_meal_logged';
  static const mealLogged = 'meal_logged';
  static const mealLoggedInExistingSession = 'meal_logged_in_existing_session';
  static const mealEdited = 'meal_edited';
  static const mealDeleted = 'meal_deleted';
  static const photoAnalysisSucceeded = 'photo_analysis_succeeded';
  static const photoAnalysisFailed = 'photo_analysis_failed';
  static const manualFallbackUsed = 'manual_fallback_used';
}

/// Development-only sink that makes instrumentation observable without sending
/// data outside the app. A beta provider can implement [Analytics] later.
class DebugAnalytics implements Analytics {
  const DebugAnalytics();

  @override
  void track(AnalyticsEvent event) {
    if (!kDebugMode) return;
    debugPrint('[analytics] ${event.name} ${jsonEncode(event.properties)}');
  }
}
