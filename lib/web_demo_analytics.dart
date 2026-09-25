import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'analytics.dart';
import 'demo_visitor.dart';

/// Sends a small allowlisted event, never image or profile data.
class WebDemoAnalytics implements Analytics {
  final String apiBaseUrl;
  final http.Client _client;

  WebDemoAnalytics({required this.apiBaseUrl, http.Client? client})
    : _client = client ?? http.Client();

  @override
  void track(AnalyticsEvent event) {
    if (!_allowedEvents.contains(event.name)) return;
    unawaited(_send(event));
  }

  Future<void> _send(AnalyticsEvent event) async {
    try {
      final visitorId = await demoVisitorId();
      final uri = Uri.parse(
        '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}/v0/demo/event',
      );
      final step = event.name == AnalyticsEvents.onboardingStepViewed
          ? event.properties['step']
          : null;
      await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Demo-Visitor': visitorId,
            },
            body: jsonEncode({
              'name': event.name,
              if (step is int && step >= 0 && step <= 6) 'step': step,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Analytics is best effort and must never interrupt the demo.
    }
  }
}

const _allowedEvents = <String>{
  AnalyticsEvents.appOpened,
  AnalyticsEvents.onboardingStarted,
  AnalyticsEvents.onboardingStepViewed,
  AnalyticsEvents.onboardingCompleted,
  AnalyticsEvents.firstMealLogged,
  AnalyticsEvents.mealLogged,
  AnalyticsEvents.mealLoggedInExistingSession,
  AnalyticsEvents.mealEdited,
  AnalyticsEvents.mealDeleted,
  AnalyticsEvents.photoAnalysisSucceeded,
  AnalyticsEvents.photoAnalysisFailed,
  AnalyticsEvents.manualFallbackUsed,
};
