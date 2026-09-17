import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/photo_food/api_error.dart';
import 'package:my_new_app/photo_food/controller.dart';
import 'package:my_new_app/main.dart';

void main() {
  test('ApiError envelope parsing', () {
    final error = ApiError.fromEnvelope({
      'error': {
        'code': 'UNAUTHORIZED',
        'message': 'Invalid key',
        'request_id': 'req_1',
      },
    }, statusCode: 401);

    expect(error.code, 'UNAUTHORIZED');
    expect(error.requestId, 'req_1');
    expect(error.statusCode, 401);
  });

  test('Error code mapping', () {
    expect(
      mapErrorCodeToMessage('NO_FOOD_DETECTED'),
      'No food detected in the photo.',
    );
    expect(
      mapErrorCodeToMessage('RATE_LIMITED'),
      'Too many requests. Please try again later.',
    );
    expect(
      mapErrorCodeToMessage('CONNECTION_ERROR'),
      'Cannot reach the analysis service. Check the connection and try again.',
    );
    expect(
      mapErrorCodeToMessage('INVALID_SERVER_RESPONSE'),
      'Analysis service returned an invalid response. Please try again.',
    );
  });

  test('Portion validation', () {
    expect(PhotoFoodController.validatePortionInput('0'), isNotNull);
    expect(PhotoFoodController.validatePortionInput('2001'), isNotNull);
    expect(PhotoFoodController.validatePortionInput('250'), isNull);
  });

  test('Onboarding decode fallback handles unknown enums', () {
    final raw = jsonEncode({
      'goalType': 'legacy_goal',
      'sex': 'legacy_sex',
      'age': 29,
      'heightCm': 176.0,
      'weightKg': 78.0,
      'activityLevel': 'legacy_activity',
      'targetPace': 'legacy_pace',
      'macroProfile': 'legacy_macro',
    });

    final decoded = decodeOnboardingResultForTest(raw);
    expect(decoded, isNotNull);
    expect(decoded!.plan.calorieTarget, greaterThan(0));
    expect(decoded.plan.proteinTargetG, greaterThan(0));
  });
}
