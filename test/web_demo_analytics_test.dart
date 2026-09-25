import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_new_app/analytics.dart';
import 'package:my_new_app/web_demo_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'web analytics records an onboarding step without profile details',
    () async {
      SharedPreferences.setMockInitialValues({});
      final requestCompleter = Completer<http.Request>();
      final client = MockClient((request) async {
        requestCompleter.complete(request);
        return http.Response('{"ok":true}', 200);
      });
      final analytics = WebDemoAnalytics(
        apiBaseUrl: 'https://example.test',
        client: client,
      );

      analytics.track(
        AnalyticsEvent(
          AnalyticsEvents.onboardingStepViewed,
          properties: {'step': 2, 'weight_kg': 65},
        ),
      );

      final request = await requestCompleter.future.timeout(
        const Duration(seconds: 3),
      );
      expect(request.url.toString(), 'https://example.test/v0/demo/event');
      expect(
        request.headers['X-Demo-Visitor'],
        matches(RegExp(r'^[a-f0-9]{32}$')),
      );
      expect(jsonDecode(request.body), {
        'name': AnalyticsEvents.onboardingStepViewed,
        'step': 2,
      });
    },
  );
}
