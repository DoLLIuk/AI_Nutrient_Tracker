import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/main.dart';
import 'package:my_new_app/photo_food/controller.dart';
import 'package:my_new_app/photo_food/models.dart';
import 'package:my_new_app/photo_food/pending_operation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'photo_flow_recovery_test.dart' as fixtures;

Finder input(String field) => find.descendant(
  of: find.byKey(Key('meal-input-$field')),
  matching: find.byType(TextField),
);

double value(WidgetTester tester, String field) => double.parse(
  tester.widget<TextField>(input(field)).controller!.text.replaceAll(',', '.'),
);

Future<void> edit(WidgetTester tester, String field, String text) async {
  await tester.ensureVisible(input(field));
  await tester.enterText(input(field), text);
  await tester.pumpAndSettle();
}

Future<void> openBurger(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'app.debug.meal_details': false});
  final json = fixtures.result().toJson();
  json['item']['name'] = 'Bacon Egg Cheeseburger';
  json['item']['nutrition_per_100g'] = {
    'kcal': 280,
    'protein_g': 16,
    'fat_g': 18,
    'carbs_g': 17,
  };
  json['meta']['estimated_portion_g'] = 310;
  json['meta']['estimated_totals'] = {
    'kcal': 868,
    'protein_g': 49.6,
    'fat_g': 55.8,
    'carbs_g': 52.7,
  };
  final store = MemoryPhotoOperationStore()
    ..value = fixtures.operation(response: PhotoFoodResponse.fromJson(json));
  final controller = PhotoFoodController(
    repository: fixtures.Repository(),
    photoPicker: fixtures.Picker(),
    operationStore: store,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MyApp(
      controller: controller,
      skipOnboarding: true,
      nowProvider: () => fixtures.scanDate,
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Bacon Egg Cheeseburger').first);
  await tester.tap(find.text('Bacon Egg Cheeseburger').first);
  await tester.pumpAndSettle();
}

void expectPortion(WidgetTester tester, double grams) {
  expect(value(tester, 'weight'), grams);
  expect(value(tester, 'protein'), closeTo(grams * .16, .051));
  expect(value(tester, 'fat'), closeTo(grams * .18, .051));
  expect(value(tester, 'carbs'), closeTo(grams * .17, .051));
  expect(value(tester, 'calories'), closeTo(grams * 2.8, .051));
}

void main() {
  testWidgets('unlocking weight preserves locked-calorie save confirmation', (
    tester,
  ) async {
    await openBurger(tester);
    await edit(tester, 'weight', '250');
    await edit(tester, 'calories', '700');
    await edit(tester, 'protein', '100');
    await tester.ensureVisible(find.byKey(const Key('meal-lock-weight')));
    await tester.tap(find.byKey(const Key('meal-lock-weight')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('locked-calories-auto-save')), findsOneWidget);
    expect(
      find.byKey(const Key('locked-calories-save-as-entered')),
      findsOneWidget,
    );
  });

  testWidgets('typing weight through zero cannot inflate nutrition', (
    tester,
  ) async {
    await openBurger(tester);
    // This edit sequence reproduced the reported 60 / 67.5 / 63.8 g macros.
    for (final text in ['3.0', '0.0', '2.0', '25.0', '250.0']) {
      await edit(tester, 'weight', text);
    }
    expectPortion(tester, 250);
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final row = (jsonDecode(prefs.getString('app.meals')!) as List).single;
    expect(row['kcal'], closeTo(700, .000001));
    expect(row['portionG'], 250);
    await tester.tap(find.text('Bacon Egg Cheeseburger').first);
    await tester.pumpAndSettle();
    await edit(tester, 'weight', '310');
    expectPortion(tester, 310);
  });

  testWidgets('weight scales stored calories without implicit normalization', (
    tester,
  ) async {
    await openBurger(tester);
    for (final text in ['300', '250,5', '', '.', '310', '0', '155', '310']) {
      await edit(tester, 'weight', text);
      final grams = double.tryParse(text.replaceAll(',', '.'));
      if (grams != null) expectPortion(tester, grams);
    }
  });

  testWidgets(
    'calories can be retyped through zero without losing macro ratios',
    (tester) async {
      await openBurger(tester);
      for (final text in ['0', '7', '70', '700']) {
        await edit(tester, 'calories', text);
      }
      expect(value(tester, 'calories'), 700);
      expect(value(tester, 'weight'), 310);
      const ratio = 700 / 911.4;
      expect(value(tester, 'protein'), closeTo(49.6 * ratio, .051));
      expect(value(tester, 'fat'), closeTo(55.8 * ratio, .051));
      expect(value(tester, 'carbs'), closeTo(52.7 * ratio, .051));
    },
  );

  testWidgets('locking and unlocking weight does not change nutrition', (
    tester,
  ) async {
    await openBurger(tester);
    final field = find.byKey(const Key('meal-input-weight'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meal-lock-weight')), findsOneWidget);
    expectPortion(tester, 310);
    await tester.tap(find.byKey(const Key('meal-lock-weight')));
    await tester.pumpAndSettle();
    expectPortion(tester, 310);
  });

  testWidgets('weight edit rebases after a manual macro change and revert', (
    tester,
  ) async {
    await openBurger(tester);
    await edit(tester, 'weight', '155');
    await edit(tester, 'protein', '30');
    await edit(tester, 'weight', '0');
    await edit(tester, 'weight', '310');
    expect(value(tester, 'protein'), 30);
    expect(value(tester, 'fat'), 55.8);
    expect(value(tester, 'carbs'), 52.7);
    expect(value(tester, 'calories'), 833);
    await tester.ensureVisible(find.byKey(const Key('revert-changes')));
    await tester.tap(find.byKey(const Key('revert-changes')));
    await tester.pumpAndSettle();
    expectPortion(tester, 310);
    await edit(tester, 'weight', '250');
    expectPortion(tester, 250);
  });

  testWidgets('non-finite nutrition input cannot be saved', (tester) async {
    await openBurger(tester);
    for (final text in ['NaN', 'Infinity', '1e309']) {
      await edit(tester, 'weight', text);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Meal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await edit(tester, 'weight', '250');
    expectPortion(tester, 250);
  });

  testWidgets('calorie retyping preserves a manually fixed macro', (
    tester,
  ) async {
    await openBurger(tester);
    await edit(tester, 'protein', '40');
    for (final text in ['0', '7', '70', '700']) {
      await edit(tester, 'calories', text);
    }
    expect(value(tester, 'protein'), 40);
    expect(value(tester, 'weight'), 310);
    expect(value(tester, 'calories'), 700);
    const ratio = (700 - 40 * 4) / (55.8 * 9 + 52.7 * 4);
    expect(value(tester, 'fat'), closeTo(55.8 * ratio, .051));
    expect(value(tester, 'carbs'), closeTo(52.7 * ratio, .051));
  });
}
