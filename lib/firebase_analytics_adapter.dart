import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics.dart';

class FirebaseAnalyticsAdapter implements Analytics {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsAdapter({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  void track(AnalyticsEvent event) {
    _analytics.logEvent(
      name: event.name,
      parameters: encodeAnalyticsParameters(event),
    );
  }
}

Map<String, Object> encodeAnalyticsParameters(AnalyticsEvent event) {
  final parameters = <String, Object>{};
  for (final entry in event.properties.entries) {
    final value = entry.value;
    switch (value) {
      case String():
        parameters[entry.key] = value;
      case num():
        parameters[entry.key] = value;
      case bool():
        parameters[entry.key] = value ? 1 : 0;
    }
  }
  return parameters;
}
