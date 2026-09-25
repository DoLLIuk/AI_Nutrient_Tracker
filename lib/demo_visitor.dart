import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _visitorKey = 'demo.visitor_id';

Future<String> demoVisitorId() async {
  final preferences = await SharedPreferences.getInstance();
  final existing = preferences.getString(_visitorKey);
  if (existing != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) {
    return existing;
  }
  final random = Random.secure();
  final visitorId = List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  await preferences.setString(_visitorKey, visitorId);
  return visitorId;
}
