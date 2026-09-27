import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_new_app/main.dart';
import 'package:my_new_app/app_config.dart';
import 'package:my_new_app/photo_food/api_client.dart';
import 'package:my_new_app/photo_food/api_error.dart';
import 'package:my_new_app/photo_food/controller.dart';
import 'package:my_new_app/photo_food/models.dart';
import 'package:my_new_app/photo_food/operation_store_native.dart';
import 'package:my_new_app/photo_food/pending_operation.dart';
import 'package:my_new_app/photo_food/photo_picker.dart';
import 'package:my_new_app/photo_food/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

PhotoFoodResponse result() => PhotoFoodResponse.fromJson({
  'request_id': 'op_test',
  'item': {
    'name': 'Cheeseburger with fries',
    'confidence': 0.8,
    'nutrition_per_100g': {
      'kcal': 240,
      'protein_g': 12,
      'fat_g': 10,
      'carbs_g': 25,
    },
  },
  'ui_flags': {'requires_user_confirmation': true, 'highlight_level': 'orange'},
  'meta': {
    'needs_confirmation': true,
    'estimated_portion_g': 400,
    'totals_are_estimate': true,
    'estimated_totals': {
      'kcal': 960,
      'protein_g': 48,
      'fat_g': 40,
      'carbs_g': 100,
    },
  },
});

final scanDate = DateTime(2026, 9, 24);
PendingPhotoOperation operation({PhotoFoodResponse? response}) =>
    PendingPhotoOperation(
      id: 'saved_scan_1234567890',
      diaryDate: scanDate,
      capturedAt: DateTime(2026, 9, 24, 12, 5),
      image: response == null
          ? XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'food.jpg')
          : null,
      response: response,
    );

class Picker implements PhotoPicker {
  @override
  Future<XFile?> pick(PickSource source) async => operation().image;
}

class Repository implements PhotoFoodRepository {
  final List<String?> calls = [];
  Completer<PhotoFoodResponse>? gate;
  bool fail = false;
  @override
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale = 'en-US',
    String? mealTime,
    PhotoClarificationInput? clarification,
    String? operationId,
  }) async {
    calls.add(operationId);
    if (fail) {
      throw const ApiException(
        ApiError(code: 'CONNECTION_ERROR', message: 'offline'),
      );
    }
    return gate?.future ?? result();
  }

  @override
  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  }) async {
    final json = result().toJson();
    (json['meta'] as Map)['confirmation_source'] = 'user_input';
    (json['meta'] as Map)['needs_confirmation'] = false;
    (json['ui_flags'] as Map)['requires_user_confirmation'] = false;
    return PhotoFoodResponse.fromJson(json);
  }
}

class FailingStore extends MemoryPhotoOperationStore {
  @override
  Future<void> write(PendingPhotoOperation operation) async =>
      throw FileSystemException('disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('API requires durable capability and forwards the stable key', () async {
    SharedPreferences.setMockInitialValues({});
    var supported = false;
    var uploads = 0;
    final client = PhotoFoodApiClient(
      config: const AppConfig(
        apiBaseUrl: 'https://example.test',
        apiKey: 'test',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/v0/health') {
          return http.Response(
            jsonEncode({
              'photo_flow_version': 2,
              'durable_operations': supported,
            }),
            200,
          );
        }
        uploads++;
        expect(request.headers['Idempotency-Key'], 'saved_scan_1234567890');
        return http.Response(jsonEncode(result().toJson()), 200);
      }),
    );
    final photo = XFile.fromData(
      Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
      name: 'food.jpg',
    );
    await expectLater(
      client.analyzePhoto(photo, operationId: 'saved_scan_1234567890'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.error.code,
          'code',
          'RECOVERY_NOT_SUPPORTED',
        ),
      ),
    );
    expect(uploads, 0);
    supported = true;
    await client.analyzePhoto(photo, operationId: 'saved_scan_1234567890');
    expect(uploads, 1);
  });

  testWidgets('weight review icon saves review without changing the estimate', (
    tester,
  ) async {
    final font = Platform.environment['PHOTO_FLOW_TEST_FONT'];
    // Ahem's square test glyphs are much wider than the production font.
    // Use the real-font capture to inspect the compact phone layout.
    tester.view.physicalSize = font == null ? const Size(800, 1000) : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (font != null) {
      final bytes = File(font).readAsBytesSync();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
    }
    SharedPreferences.setMockInitialValues({'app.debug.meal_details': false});
    final store = MemoryPhotoOperationStore()
      ..value = operation(response: result());
    final controller = PhotoFoodController(
      repository: Repository(),
      photoPicker: Picker(),
      operationStore: store,
    );
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MyApp(
          controller: controller,
          skipOnboarding: true,
          nowProvider: () => scanDate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cheeseburger with fries').first);
    await tester.tap(find.text('Cheeseburger with fries').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-mark-reviewed')), findsOneWidget);
    if (font != null) {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/photo-flow-weight-review.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byKey(const Key('portion-mark-reviewed')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-mark-reviewed')), findsNothing);
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final row = (jsonDecode(prefs.getString('app.meals')!) as List).single;
    expect(row['portionReviewed'], true);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
  test(
    'restart retries the same operation and preserves the captured date',
    () async {
      final store = MemoryPhotoOperationStore();
      final repository = Repository()..fail = true;
      final controller = PhotoFoodController(
        repository: repository,
        photoPicker: Picker(),
        operationStore: store,
      );
      await controller.pickImage(PickSource.gallery);
      await controller.analyzePickedImage(
        diaryDate: scanDate,
        capturedAt: DateTime(2026, 9, 24, 12, 5),
      );
      final id = repository.calls.single;
      expect(store.value!.response, isNull);
      controller.dispose();
      repository.fail = false;
      final restored = PhotoFoodController(
        repository: repository,
        photoPicker: Picker(),
        operationStore: store,
      );
      await restored.restorePending();
      expect(repository.calls, [id, id]);
      expect(restored.scanDate, scanDate);
      expect(restored.state.response!.item.name, 'Cheeseburger with fries');
      expect(store.value!.image, isNull);
      restored.dispose();
    },
  );

  test(
    'concurrent retry cannot duplicate a request and completion survives dispose',
    () async {
      final store = MemoryPhotoOperationStore()..value = operation();
      final repository = Repository()..gate = Completer<PhotoFoodResponse>();
      final controller = PhotoFoodController(
        repository: repository,
        photoPicker: Picker(),
        operationStore: store,
      );
      final running = controller.restorePending();
      await Future<void>.delayed(Duration.zero);
      await controller.retryLastAnalysis();
      expect(repository.calls.length, 1);
      controller.dispose();
      repository.gate!.complete(result());
      await running;
      expect(store.value!.response!.requestId, 'op_test');
    },
  );

  test('disk failure prevents a paid request', () async {
    final repository = Repository();
    final controller = PhotoFoodController(
      repository: repository,
      photoPicker: Picker(),
      operationStore: FailingStore(),
    );
    await controller.pickImage(PickSource.gallery);
    await controller.analyzePickedImage();
    expect(repository.calls, isEmpty);
    expect(controller.state.error!.code, 'SCAN_STORAGE_FAILED');
    controller.dispose();
  });

  test(
    'completed journal replays locally and is cleared only after diary acknowledgement',
    () async {
      final store = MemoryPhotoOperationStore()
        ..value = operation(response: result());
      final repository = Repository();
      final controller = PhotoFoodController(
        repository: repository,
        photoPicker: Picker(),
        operationStore: store,
      );
      await controller.restorePending();
      expect(repository.calls, isEmpty);
      final receipt = controller.pendingReceipt;
      await controller.acknowledgeSaved({'wrong'}, receipt);
      expect(store.value, isNotNull);
      await controller.acknowledgeSaved({'op_test'}, Object());
      expect(store.value, isNotNull);
      await controller.acknowledgeSaved({'op_test'}, receipt);
      expect(store.value, isNull);
      controller.dispose();
    },
  );

  test(
    'native journal persists photo, atomically replaces it with result, then removes it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'photo-flow-test-',
      );
      try {
        final store = DurablePhotoOperationStore(
          supportDirectory: () async => directory,
        );
        await store.write(operation());
        expect(await (await store.read())!.image!.readAsBytes(), [1, 2, 3]);
        await store.write(operation(response: result()));
        final restored = await store.read();
        expect(restored!.image, isNull);
        expect(restored.response!.toJson(), result().toJson());
        await store.clear();
        expect(await store.read(), isNull);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'recovered scan logs on original day and replay preserves user edits',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MemoryPhotoOperationStore()
        ..value = operation(response: result());
      final controller = PhotoFoodController(
        repository: Repository(),
        photoPicker: Picker(),
        operationStore: store,
      );
      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          nowProvider: () => DateTime(2026, 9, 26, 20),
        ),
      );
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final rows = jsonDecode(prefs.getString('app.meals')!) as List;
      expect(rows.length, 1);
      expect(rows.single['day'], scanDate.toIso8601String());
      expect(rows.single['portionReviewed'], false);
      expect(store.value, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      rows.single['name'] = 'My edited meal';
      rows.single['portionReviewed'] = true;
      await prefs.setString('app.meals', jsonEncode(rows));
      store.value = operation(
        response: result(),
      ); // Crash after diary save, before acknowledgement.
      final second = PhotoFoodController(
        repository: Repository(),
        photoPicker: Picker(),
        operationStore: store,
      );
      await tester.pumpWidget(MyApp(controller: second, skipOnboarding: true));
      await tester.pumpAndSettle();
      final after = jsonDecode(prefs.getString('app.meals')!) as List;
      expect(after.length, 1);
      expect(after.single['name'], 'My edited meal');
      expect(after.single['portionReviewed'], true);
      expect(store.value, isNull);
      controller.dispose();
      second.dispose();
    },
  );
}
