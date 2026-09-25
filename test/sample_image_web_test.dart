import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'package:my_new_app/app_config.dart';
import 'package:my_new_app/photo_food/api_client.dart';
import 'package:my_new_app/photo_food/api_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sample JPEG can be uploaded through the web photo client', () async {
    final data = await rootBundle.load('assets/demo_food/chicken_rice.jpg');
    final image = XFile.fromData(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      name: 'chicken_rice.jpg',
      mimeType: 'image/jpeg',
    );
    var sent = false;
    final client = MockClient((request) async {
      sent = true;
      expect(request.url.toString(), 'https://example.test/v0/ai/photo-food');
      expect(request.headers.containsKey('X-API-Key'), isFalse);
      if (kIsWeb) {
        expect(
          request.headers['X-Demo-Visitor'],
          matches(RegExp(r'^[a-f0-9]{32}$')),
        );
      }
      expect(request.bodyBytes.length, greaterThan(data.lengthInBytes));
      return http.Response(
        '{"error":{"code":"RATE_LIMITED","message":"test"}}',
        429,
      );
    });
    final api = PhotoFoodApiClient(
      config: const AppConfig(apiBaseUrl: 'https://example.test', apiKey: ''),
      httpClient: client,
    );

    await expectLater(api.analyzePhoto(image), throwsA(isA<ApiException>()));
    expect(sent, isTrue);
  });
}
