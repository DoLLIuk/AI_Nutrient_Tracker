import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_new_app/main.dart';
import 'package:my_new_app/photo_food/api_error.dart';
import 'package:my_new_app/photo_food/controller.dart';
import 'package:my_new_app/photo_food/models.dart';
import 'package:my_new_app/photo_food/pending_operation.dart';
import 'package:my_new_app/photo_food/photo_picker.dart';
import 'package:my_new_app/photo_food/operation_store_native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'photo_flow_recovery_test.dart' as fixtures;

PhotoFoodResponse confirmed(double grams) {
  final json = fixtures.result().toJson();
  final meta = json['meta'] as Map;
  meta['confirmation_source'] = 'user_input';
  meta['needs_confirmation'] = false;
  meta['estimated_portion_g'] = grams;
  meta['estimated_totals'] = {
    'kcal': grams * 2.4,
    'protein_g': grams * .12,
    'fat_g': grams * .1,
    'carbs_g': grams * .25,
  };
  (json['ui_flags'] as Map)['requires_user_confirmation'] = false;
  return PhotoFoodResponse.fromJson(json);
}

class ConfirmRepository extends fixtures.Repository {
  final confirmations = <double?>[];
  Completer<PhotoFoodResponse>? confirmationGate;
  MemoryPhotoOperationStore? journal;
  @override
  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  }) async {
    confirmations.add(portionG);
    if (journal != null) {
      expect(journal!.value!.confirmationPending, true);
      expect(journal!.value!.confirmationGrams, portionG);
    }
    return confirmationGate?.future ?? confirmed(portionG ?? 400);
  }
}

class RecoveringPicker extends fixtures.Picker
    implements RecoverablePhotoPicker {
  int recoveries = 0;
  @override
  Future<XFile?> recoverLostImage() async {
    recoveries++;
    return fixtures.operation().image;
  }
}

class SlowReadStore extends MemoryPhotoOperationStore {
  final readGate = Completer<PendingPhotoOperation?>();
  @override
  Future<PendingPhotoOperation?> read() => readGate.future;
}

class CaptureProbePicker extends fixtures.Picker {
  final MemoryPhotoOperationStore store;
  CaptureProbePicker(this.store);
  @override
  Future<XFile?> pick(PickSource source) async {
    expect(store.value!.awaitingPicker, true);
    expect(store.value!.diaryDate, fixtures.scanDate);
    expect(store.value!.image, isNull);
    return super.pick(source);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture context is written before opening camera', () async {
    final store = MemoryPhotoOperationStore();
    final controller = PhotoFoodController(
      repository: ConfirmRepository(),
      photoPicker: CaptureProbePicker(store),
      operationStore: store,
    );
    await controller.pickImage(PickSource.camera, diaryDate: fixtures.scanDate);
    expect(controller.hasDraft, true);
    controller.dispose();
  });

  testWidgets('recovered draft stays inline and is explicitly discardable', (
    tester,
  ) async {
    final font = Platform.environment['PHOTO_FLOW_TEST_FONT'];
    if (font != null) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = File(font).readAsBytesSync();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    SharedPreferences.setMockInitialValues({});
    final store = MemoryPhotoOperationStore()
      ..value = fixtures.operation().withImage(fixtures.operation().image!);
    final repo = ConfirmRepository();
    final controller = PhotoFoodController(
      repository: repo,
      photoPicker: fixtures.Picker(),
      operationStore: store,
    );
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MyApp(
          controller: controller,
          skipOnboarding: true,
          nowProvider: () => fixtures.scanDate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-draft-continue')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('photo-draft-continue')).hitTestable(), findsOneWidget);
    expect(repo.calls, isEmpty);
    if (font != null) {
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/photo-flow-recovered-draft.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.byKey(const Key('photo-draft-discard')));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(repo.calls, isEmpty);
    controller.dispose();
  });

  testWidgets(
    'confirmation updates matching revision once and replay is harmless',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MemoryPhotoOperationStore()
        ..value = fixtures.operation(response: fixtures.result());
      final controller = PhotoFoodController(
        repository: ConfirmRepository(),
        photoPicker: fixtures.Picker(),
        operationStore: store,
      );
      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          nowProvider: () => fixtures.scanDate,
        ),
      );
      await tester.pumpAndSettle();
      await controller.confirmPortion(300);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final row = (jsonDecode(prefs.getString('app.meals')!) as List).single;
      expect(row['portionG'], 300);
      expect(row['kcal'], 720);
      expect(row['revision'], 1);
      await tester.pumpWidget(const SizedBox.shrink());
      store.value = fixtures
          .operation(response: fixtures.result())
          .confirming(grams: 300, useEstimate: false, revision: 0)
          .completed(confirmed(300));
      final next = PhotoFoodController(
        repository: ConfirmRepository(),
        photoPicker: fixtures.Picker(),
        operationStore: store,
      );
      await tester.pumpWidget(
        MyApp(
          controller: next,
          skipOnboarding: true,
          nowProvider: () => fixtures.scanDate,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (jsonDecode(prefs.getString('app.meals')!) as List).single['revision'],
        1,
      );
      controller.dispose();
      next.dispose();
    },
  );

  test(
    'camera interruption restores a draft, original date and no paid call',
    () async {
      final store = MemoryPhotoOperationStore()
        ..value = PendingPhotoOperation(
          id: 'camera_draft_123456789',
          diaryDate: fixtures.scanDate,
          capturedAt: fixtures.scanDate,
          draft: true,
          awaitingPicker: true,
        );
      final picker = RecoveringPicker();
      final repo = ConfirmRepository();
      final controller = PhotoFoodController(
        repository: repo,
        photoPicker: picker,
        operationStore: store,
      );
      await controller.restorePending();
      expect(picker.recoveries, 1);
      expect(controller.hasDraft, true);
      expect(controller.scanDate, fixtures.scanDate);
      expect(repo.calls, isEmpty);
      expect(store.value!.awaitingPicker, false);
      await controller.analyzePickedImage();
      expect(repo.calls, ['camera_draft_123456789']);
      controller.dispose();
    },
  );

  test(
    'photo is durable before clarification and is not auto-uploaded on restart',
    () async {
      final store = MemoryPhotoOperationStore();
      final repo = ConfirmRepository();
      final controller = PhotoFoodController(
        repository: repo,
        photoPicker: fixtures.Picker(),
        operationStore: store,
      );
      await controller.pickImage(
        PickSource.camera,
        diaryDate: fixtures.scanDate,
      );
      expect(store.value!.draft, true);
      expect(store.value!.image, isNotNull);
      controller.dispose();
      final next = PhotoFoodController(
        repository: repo,
        photoPicker: fixtures.Picker(),
        operationStore: store,
      );
      await next.restorePending();
      expect(next.state.status, HomeStatus.draftReady);
      expect(repo.calls, isEmpty);
      next.dispose();
    },
  );

  test(
    'interrupted weight confirmation retries saved grams without analyzing a photo',
    () async {
      final store = MemoryPhotoOperationStore()
        ..value = fixtures.operation(response: fixtures.result());
      final repo = ConfirmRepository()
        ..journal = store
        ..confirmationGate = Completer<PhotoFoodResponse>();
      final controller = PhotoFoodController(
        repository: repo,
        photoPicker: fixtures.Picker(),
        operationStore: store,
      );
      await controller.restorePending();
      final running = controller.confirmPortion(300, baseRevision: 4);
      await Future<void>.delayed(Duration.zero);
      // This is the durable state an abrupt process exit would leave behind.
      final recoveredStore = MemoryPhotoOperationStore()
        ..value = PendingPhotoOperation.fromJson(await store.value!.toJson());
      expect(controller.pendingReceipt, isNull);
      controller.dispose();
      repo.confirmationGate!.completeError(
        const ApiException(
          ApiError(code: 'CONNECTION_ERROR', message: 'offline'),
        ),
      );
      expect(await running, false);
      final nextRepo = ConfirmRepository()..journal = recoveredStore;
      final next = PhotoFoodController(
        repository: nextRepo,
        photoPicker: fixtures.Picker(),
        operationStore: recoveredStore,
      );
      await next.restorePending();
      expect(nextRepo.calls, isEmpty);
      expect(nextRepo.confirmations, [300]);
      expect(next.state.response!.meta.estimatedPortionG, 300);
      expect(next.resultBaseRevision, 4);
      next.dispose();
    },
  );

  test(
    'native draft keeps large image bytes out of repeated JSON writes',
    () async {
      final dir = await Directory.systemTemp.createTemp('photo-draft-');
      try {
        final store = DurablePhotoOperationStore(
          supportDirectory: () async => dir,
        );
        final original = fixtures.operation();
        final draft = original.withImage(
          XFile.fromData(Uint8List(1024 * 1024), name: 'large.jpg'),
        );
        await store.write(draft);
        final metadata = File('${dir.path}/pending_photo.json');
        expect(await metadata.length(), lessThan(2048));
        expect(await (await store.read())!.image!.length(), 1024 * 1024);
        await store.write(draft.ready());
        expect(await metadata.length(), lessThan(2048));
        await store.write(draft.completed(fixtures.result()));
        expect(
          await File('${dir.path}/pending_${draft.id}.image').exists(),
          false,
        );
        await store.clear();
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets('slow recovery does not block home or manual logging', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SlowReadStore();
    final controller = PhotoFoodController(
      repository: ConfirmRepository(),
      photoPicker: fixtures.Picker(),
      operationStore: store,
    );
    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    // No completion of the simulated slow disk: home must already be usable.
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-manual')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();
    expect(find.text('Meal Name'), findsOneWidget);
    store.readGate.complete(null);
    await tester.pumpAndSettle();
    controller.dispose();
  });

  for (final delete in [false, true]) {
    testWidgets(
      delete
          ? 'late confirmation cannot resurrect a deleted meal, including restart'
          : 'late confirmation preserves a newer manual edit',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'app.debug.meal_details': delete,
        });
        final store = MemoryPhotoOperationStore()
          ..value = fixtures.operation(response: fixtures.result());
        final repo = ConfirmRepository()
          ..confirmationGate = Completer<PhotoFoodResponse>();
        final controller = PhotoFoodController(
          repository: repo,
          photoPicker: fixtures.Picker(),
          operationStore: store,
        );
        await tester.pumpWidget(
          MyApp(
            controller: controller,
            skipOnboarding: true,
            nowProvider: () => fixtures.scanDate,
          ),
        );
        await tester.pumpAndSettle();
        final confirmation = controller.confirmPortion(300, baseRevision: 0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.ensureVisible(find.text('Cheeseburger with fries').first);
        await tester.tap(find.text('Cheeseburger with fries').first);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        if (delete) {
          await tester.tap(find.text('Delete'));
        } else {
          await tester.enterText(
            find.byType(TextField).first,
            'My edited plate',
          );
          await tester.pump();
          await tester.ensureVisible(find.text('Save Changes'));
          await tester.tap(find.text('Save Changes'));
        }
        await tester.pump(const Duration(milliseconds: 400));
        repo.confirmationGate!.complete(confirmed(300));
        await tester.pumpAndSettle();
        expect(await confirmation, true);
        final prefs = await SharedPreferences.getInstance();
        final rows = jsonDecode(prefs.getString('app.meals')!) as List;
        if (delete) {
          expect(rows, isEmpty);
          expect(
            prefs.getStringList('app.meals.deleted_ids'),
            contains('op_test'),
          );
        } else {
          expect(rows.single['name'], 'My edited plate');
          expect(rows.single['kcal'], 960);
          expect(rows.single['portionG'], 400);
          expect(rows.single['revision'], 1);
        }
        expect(store.value, isNull);
        if (delete) {
          await tester.pumpWidget(const SizedBox.shrink());
          store.value = fixtures.operation(response: fixtures.result());
          final next = PhotoFoodController(
            repository: ConfirmRepository(),
            photoPicker: fixtures.Picker(),
            operationStore: store,
          );
          await tester.pumpWidget(
            MyApp(
              controller: next,
              skipOnboarding: true,
              nowProvider: () => fixtures.scanDate,
            ),
          );
          await tester.pumpAndSettle();
          expect(jsonDecode(prefs.getString('app.meals')!) as List, isEmpty);
          expect(store.value, isNull);
          next.dispose();
        }
        controller.dispose();
      },
    );
  }
}
