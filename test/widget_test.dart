import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_new_app/analytics.dart';
import 'package:my_new_app/main.dart';
import 'package:my_new_app/onboarding.dart';
import 'package:my_new_app/photo_food/api_error.dart';
import 'package:my_new_app/photo_food/controller.dart';
import 'package:my_new_app/photo_food/models.dart';
import 'package:my_new_app/photo_food/photo_picker.dart';
import 'package:my_new_app/photo_food/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tap + opens source bottom sheet', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('runs in manual local-only mode without API configuration', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(skipOnboarding: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-analysis-unavailable')), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    expect(find.text('Choose from gallery'), findsNothing);
    expect(find.byKey(const Key('add-manual')), findsOneWidget);
  });

  testWidgets('records app-open and onboarding funnel events', (tester) async {
    final analytics = _RecordingAnalytics();
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, analytics: analytics),
    );
    await tester.pumpAndSettle();

    expect(
      analytics.events.map((event) => event.name),
      containsAll(<String>[
        AnalyticsEvents.appOpened,
        AnalyticsEvents.onboardingStepViewed,
      ]),
    );
    expect(
      analytics.events
          .firstWhere(
            (event) => event.name == AnalyticsEvents.onboardingStepViewed,
          )
          .properties,
      {'step': 0},
    );

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(
      analytics.events.map((event) => event.name),
      contains(AnalyticsEvents.onboardingStarted),
    );
    expect(
      analytics.events
          .where((event) => event.name == AnalyticsEvents.onboardingStepViewed)
          .last
          .properties,
      {'step': 1},
    );
  });

  testWidgets('records an app open when returning from the background', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, analytics: analytics),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(
      analytics.events.where(
        (event) => event.name == AnalyticsEvents.appOpened,
      ),
      hasLength(2),
    );
  });

  testWidgets('manual logging records core-loop and same-session events', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true, analytics: analytics),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    expect(
      analytics.events.map((event) => event.name),
      containsAll(<String>[
        AnalyticsEvents.mealLogged,
        AnalyticsEvents.firstMealLogged,
      ]),
    );
    expect(
      analytics.events
          .firstWhere((event) => event.name == AnalyticsEvents.mealLogged)
          .properties,
      {'source': 'manual', 'day_offset': 0, 'creates_new_session': true},
    );

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final secondFields = find.byType(TextField);
    await tester.enterText(secondFields.at(0), 'Second test meal');
    await tester.enterText(secondFields.at(2), '250');
    await tester.enterText(secondFields.at(3), '25');
    await tester.enterText(secondFields.at(4), '10');
    await tester.enterText(secondFields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    expect(
      analytics.events
          .where((event) => event.name == AnalyticsEvents.mealLogged)
          .last
          .properties,
      {'source': 'manual', 'day_offset': 0, 'creates_new_session': false},
    );
    expect(
      analytics.events
          .lastWhere(
            (event) =>
                event.name == AnalyticsEvents.mealLoggedInExistingSession,
          )
          .properties,
      {'source': 'manual', 'day_offset': 0},
    );
  });

  testWidgets('manual meal requires a non-empty name', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '   ');
    await tester.enterText(fields.at(1), '420');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '40');
    await tester.tap(find.byKey(const Key('manual-meal-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-form-message')), findsOneWidget);
    expect(find.text('Add Meal'), findsWidgets);
    expect(find.byKey(const Key('latest-added-card')), findsNothing);
  });

  testWidgets('requires confirmation opens portion bottom sheet', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    final controller = PhotoFoodController(
      repository: _FakeRepository(requiresConfirmation: true),
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true, analytics: analytics),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clarification-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clarification-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('portion-sheet')), findsOneWidget);
    expect(find.byKey(const Key('portion-input')), findsOneWidget);
    expect(find.byKey(const Key('portion-use-ai-estimate')), findsOneWidget);
    expect(
      analytics.events.map((event) => event.name),
      contains(AnalyticsEvents.photoAnalysisSucceeded),
    );
    expect(
      analytics.events
          .firstWhere(
            (event) => event.name == AnalyticsEvents.photoAnalysisSucceeded,
          )
          .properties,
      {'source': 'gallery', 'requires_portion_confirmation': true},
    );
  });

  testWidgets('photo failure records an event and offers manual fallback', (
    tester,
  ) async {
    final analytics = _RecordingAnalytics();
    final controller = PhotoFoodController(
      repository: _FailingRepository(),
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true, analytics: analytics),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clarification-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Add manually'), findsOneWidget);
    expect(
      analytics.events.map((event) => event.name),
      contains(AnalyticsEvents.photoAnalysisFailed),
    );

    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();

    expect(find.text('Add Meal'), findsWidgets);
    expect(
      analytics.events.map((event) => event.name),
      contains(AnalyticsEvents.manualFallbackUsed),
    );
  });

  testWidgets(
    'photo flow shows clarification sheet before single analyze request',
    (tester) async {
      final repository = _FakeRepository(
        clarificationCategories: const [DishCategory.soup, DishCategory.salad],
      );
      final controller = PhotoFoodController(
        repository: repository,
        photoPicker: _FakePicker(file: XFile('fake.jpg')),
      );

      await tester.pumpWidget(
        MyApp(controller: controller, skipOnboarding: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fab-add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pick-gallery')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clarification-sheet')), findsOneWidget);
      expect(find.byKey(const Key('clarification-skip')), findsOneWidget);
      expect(
        find.byKey(const Key('clarification-category-soup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('clarification-category-salad')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('clarification-category-soup')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('clarification-hint-chicken')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('clarification-hint-chicken')),
      );
      await tester.tap(find.byKey(const Key('clarification-hint-chicken')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('clarification-continue')),
      );
      await tester.tap(find.byKey(const Key('clarification-continue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clarification-sheet')), findsNothing);
      expect(repository.lastClarification?.dishCategory, DishCategory.soup);
      expect(repository.lastClarification?.ingredientHints, ['chicken']);
      expect(repository.lastLocale, 'en-US');
      expect(repository.analyzeCallCount, 1);
      expect(find.text('Clarified meal estimate'), findsWidgets);
    },
  );

  testWidgets(
    'skip keeps single request and no manual improve action is shown later',
    (tester) async {
      final repository = _FakeRepository();
      final controller = PhotoFoodController(
        repository: repository,
        photoPicker: _FakePicker(file: XFile('fake.jpg')),
      );

      await tester.pumpWidget(
        MyApp(controller: controller, skipOnboarding: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fab-add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pick-gallery')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clarification-skip')));
      await tester.pumpAndSettle();

      expect(repository.analyzeCallCount, 1);
      await tester.ensureVisible(find.byKey(const Key('latest-added-card')));
      await tester.tap(find.byKey(const Key('latest-added-card')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('clarification-improve-action')),
        findsNothing,
      );
    },
  );

  testWidgets('tapping outside clarification sheet behaves like skip', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final controller = PhotoFoodController(
      repository: repository,
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clarification-sheet')), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clarification-sheet')), findsNothing);
    expect(repository.analyzeCallCount, 1);
  });

  testWidgets('category without hints submits clarification immediately', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final controller = PhotoFoodController(
      repository: repository,
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clarification-category-bowl')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clarification-sheet')), findsNothing);
    expect(repository.analyzeCallCount, 1);
    expect(repository.lastClarification?.dishCategory, DishCategory.bowl);
    expect(repository.lastClarification?.ingredientHints, isEmpty);
  });

  testWidgets('not sure action confirms portion using ai estimate', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(requiresConfirmation: true),
      photoPicker: _FakePicker(file: XFile('fake.jpg')),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pick-gallery')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('clarification-skip')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('portion-use-ai-estimate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('portion-sheet')), findsNothing);
    expect(controller.state.status, HomeStatus.loaded);
    expect(
      controller.state.response?.meta.portionBasis,
      'ai_estimate_confirmed',
    );
  });

  testWidgets('onboarding back from Goal returns to Welcome', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Track calories from food photos'), findsOneWidget);
    expect(find.text('I already have an account'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text("What's your goal?"), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text('Track calories from food photos'), findsOneWidget);
  });

  testWidgets('onboarding back from Result returns to Macro step', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Basic profile').evaluate().isNotEmpty) {
      await tester.tap(find.text('Male'));
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '24');
      await tester.enterText(
        find.widgetWithText(TextField, 'Height, cm'),
        '178',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Weight, kg'),
        '82',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Activity level').evaluate().isNotEmpty) {
      await tester.tap(find.text('Moderately active'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Choose your pace').evaluate().isNotEmpty) {
      await tester.tap(find.text('Balanced').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Macro preference').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Your plan is ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();
    expect(find.text('Macro preference'), findsOneWidget);
  });

  testWidgets('onboarding profile shows e.g. placeholders', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Basic profile'), findsOneWidget);
    expect(find.text('e.g. 24'), findsOneWidget);
    expect(find.text('e.g. 178'), findsOneWidget);
    expect(find.text('e.g. 82'), findsOneWidget);
  });

  testWidgets('onboarding profile validates new height and weight ranges', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Basic profile'), findsOneWidget);
    await tester.tap(find.text('Male'));
    await tester.enterText(find.widgetWithText(TextField, 'Age'), '24');
    await tester.enterText(find.widgetWithText(TextField, 'Height, cm'), '60');
    await tester.enterText(find.widgetWithText(TextField, 'Weight, kg'), '82');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Height must be between 70 and 220 cm.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Height, cm'), '178');
    await tester.enterText(find.widgetWithText(TextField, 'Weight, kg'), '20');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Weight must be between 30 and 250 kg.'), findsOneWidget);
  });

  testWidgets('profile tab renders expected summary UI', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Male Profile'), findsOneWidget);
    expect(find.text('Daily plan'), findsOneWidget);
    expect(find.text('Profile settings'), findsOneWidget);
    expect(find.text('Weekly Consistency'), findsNothing);
  });

  testWidgets('profile preferences opens account screen sections', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Profile settings'));
    await tester.tap(find.text('Profile settings'));
    await tester.pumpAndSettle();

    expect(find.text('Profile settings'), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.text('BETA TOOLS'), findsOneWidget);
    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(find.text('Local-only beta'), findsOneWidget);
    expect(find.text('Debug meal details'), findsOneWidget);
    expect(find.byKey(const Key('debug-meal-details-switch')), findsOneWidget);
  });

  testWidgets(
    'home hides latest card and shows compact history state on empty day',
    (tester) async {
      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          onboardingResult: _testOnboardingResult(),
          nowProvider: () => _fixedNow,
        ),
      );
      await tester.pumpAndSettle();

      final consumedY = tester.getTopLeft(find.text('Consumed')).dy;
      final coachY = tester.getTopLeft(find.byKey(const Key('coach-card'))).dy;
      final proteinY = tester.getTopLeft(find.text('Protein')).dy;

      expect(coachY, greaterThan(consumedY));
      expect(coachY, lessThan(proteinY));
      expect(find.text('Today\'s tip'), findsOneWidget);
      expect(find.text('Coach'), findsNothing);
      expect(find.text('Start your day'), findsOneWidget);
      expect(
        find.text('Log your first meal to shape the rest of today'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('latest-added-card')), findsNothing);
      expect(find.byKey(const Key('latest-added-empty')), findsNothing);
      expect(find.byKey(const Key('history-empty-card')), findsOneWidget);
      expect(find.byKey(const Key('category-card-breakfast')), findsNothing);
      expect(find.byKey(const Key('category-card-lunch')), findsNothing);
      expect(find.byKey(const Key('category-card-dinner')), findsNothing);
      expect(find.byKey(const Key('category-card-snacks')), findsNothing);
    },
  );

  testWidgets('coach card shows empty copy for non-today selected day', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => _fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-chip-4')));
    await tester.pumpAndSettle();

    expect(find.text('No meals logged'), findsOneWidget);
    expect(find.text('Add a meal to see how this day looked'), findsOneWidget);
  });

  testWidgets(
    'coach card uses historical summary instead of next meal advice on past day',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app.meals': jsonEncode([
          _mealJson(
            requestId: 'past_day_meal',
            day: _fixedYesterday,
            timestamp: DateTime(
              _fixedYesterday.year,
              _fixedYesterday.month,
              _fixedYesterday.day,
              12,
              30,
            ),
            kcal: 900,
            proteinG: 90,
            mealType: 'lunch',
            sessionId: 'session_past_day',
          ),
        ]),
      });

      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          onboardingResult: _testOnboardingResult(),
          nowProvider: () => _fixedNow,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('day-chip-4')));
      await tester.pumpAndSettle();

      expect(find.text('This day ran a bit light'), findsOneWidget);
      expect(
        find.text('You finished well under your calorie target'),
        findsOneWidget,
      );
      expect(find.textContaining('Keep your next meal around'), findsNothing);
    },
  );

  testWidgets('coach card shows over target state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        _mealJson(
          requestId: 'over_target_meal',
          day: _fixedToday,
          timestamp: DateTime(
            _fixedToday.year,
            _fixedToday.month,
            _fixedToday.day,
            12,
            30,
          ),
          kcal: 2200,
          proteinG: 120,
          mealType: 'lunch',
          sessionId: 'session_over_target',
        ),
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => _fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You\'re past today\'s target'), findsOneWidget);
    expect(
      find.text('If you eat again, keep it protein-first and light'),
      findsOneWidget,
    );
  });

  testWidgets('coach card shows low calories left state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        _mealJson(
          requestId: 'low_cal_meal',
          day: _fixedToday,
          timestamp: DateTime(
            _fixedToday.year,
            _fixedToday.month,
            _fixedToday.day,
            12,
            30,
          ),
          kcal: 1700,
          proteinG: 90,
          mealType: 'lunch',
          sessionId: 'session_low_cal',
        ),
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => _fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not much room left today'), findsOneWidget);
    expect(find.text('Keep the next meal light'), findsOneWidget);
  });

  testWidgets('coach card shows low protein today state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        _mealJson(
          requestId: 'protein_today_meal',
          day: _fixedToday,
          timestamp: DateTime(
            _fixedToday.year,
            _fixedToday.month,
            _fixedToday.day,
            12,
            30,
          ),
          kcal: 800,
          proteinG: 20,
          mealType: 'lunch',
          sessionId: 'session_protein_today',
        ),
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => _fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protein is running low today'), findsOneWidget);
    expect(find.text('Try to make lunch 30-40g protein'), findsOneWidget);
  });

  testWidgets('coach card uses dinner context after 21 00 instead of snack', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        _mealJson(
          requestId: 'late_evening_protein_meal',
          day: _fixedToday,
          timestamp: DateTime(
            _fixedToday.year,
            _fixedToday.month,
            _fixedToday.day,
            19,
            0,
          ),
          kcal: 800,
          proteinG: 20,
          mealType: 'dinner',
          sessionId: 'session_late_evening',
        ),
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => DateTime(2026, 4, 2, 21, 15),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protein is running low today'), findsOneWidget);
    expect(find.text('Try to make dinner 30-40g protein'), findsOneWidget);
    expect(find.text('Try to add a 15-20g protein snack'), findsNothing);
  });

  testWidgets('coach card shows yesterday protein state only for today', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        _mealJson(
          requestId: 'today_ok_meal',
          day: _fixedToday,
          timestamp: DateTime(
            _fixedToday.year,
            _fixedToday.month,
            _fixedToday.day,
            12,
            30,
          ),
          kcal: 900,
          proteinG: 90,
          mealType: 'lunch',
          sessionId: 'session_today_ok',
        ),
        _mealJson(
          requestId: 'yesterday_low_protein',
          day: _fixedYesterday,
          timestamp: DateTime(
            _fixedYesterday.year,
            _fixedYesterday.month,
            _fixedYesterday.day,
            12,
            30,
          ),
          kcal: 900,
          proteinG: 40,
          mealType: 'lunch',
          sessionId: 'session_yesterday_low',
        ),
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => _fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yesterday was light on protein'), findsOneWidget);
    expect(
      find.text('Today, try to get 30-40g protein at lunch'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('day-chip-4')));
    await tester.pumpAndSettle();

    expect(find.text('Yesterday was light on protein'), findsNothing);
  });

  testWidgets(
    'coach card shows plenty calories left state when day is still light',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app.meals': jsonEncode([
          _mealJson(
            requestId: 'plenty_left_meal',
            day: _fixedToday,
            timestamp: DateTime(
              _fixedToday.year,
              _fixedToday.month,
              _fixedToday.day,
              12,
              30,
            ),
            kcal: 800,
            proteinG: 80,
            mealType: 'lunch',
            sessionId: 'session_plenty_left',
          ),
          _mealJson(
            requestId: 'yesterday_ok_meal',
            day: _fixedYesterday,
            timestamp: DateTime(
              _fixedYesterday.year,
              _fixedYesterday.month,
              _fixedYesterday.day,
              12,
              30,
            ),
            kcal: 950,
            proteinG: 150,
            mealType: 'lunch',
            sessionId: 'session_yesterday_ok',
          ),
        ]),
      });

      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          onboardingResult: _testOnboardingResult(),
          nowProvider: () => _fixedNow,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You still have room for a full meal'), findsOneWidget);
      expect(
        find.text('Don\'t let lunch turn into just a snack'),
        findsOneWidget,
      );
    },
  );

  testWidgets('coach card shows strong protein progress state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        _mealJson(
          requestId: 'strong_protein_meal',
          day: _fixedToday,
          timestamp: DateTime(
            _fixedToday.year,
            _fixedToday.month,
            _fixedToday.day,
            11,
            45,
          ),
          kcal: 1100,
          proteinG: 95,
          mealType: 'lunch',
          sessionId: 'session_strong_protein',
        ),
        _mealJson(
          requestId: 'yesterday_ok_meal',
          day: _fixedYesterday,
          timestamp: DateTime(
            _fixedYesterday.year,
            _fixedYesterday.month,
            _fixedYesterday.day,
            12,
            30,
          ),
          kcal: 950,
          proteinG: 150,
          mealType: 'lunch',
          sessionId: 'session_yesterday_ok_2',
        ),
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        onboardingResult: _testOnboardingResult(),
        nowProvider: () => _fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protein looks solid so far'), findsOneWidget);
    expect(
      find.text('The next meal can stay balanced instead of protein-heavy'),
      findsOneWidget,
    );
  });

  testWidgets(
    'coach card shows on track state when no stronger state applies',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app.meals': jsonEncode([
          _mealJson(
            requestId: 'on_track_meal',
            day: _fixedToday,
            timestamp: DateTime(
              _fixedToday.year,
              _fixedToday.month,
              _fixedToday.day,
              12,
              30,
            ),
            kcal: 1200,
            proteinG: 70,
            mealType: 'lunch',
            sessionId: 'session_on_track',
          ),
          _mealJson(
            requestId: 'yesterday_ok_meal',
            day: _fixedYesterday,
            timestamp: DateTime(
              _fixedYesterday.year,
              _fixedYesterday.month,
              _fixedYesterday.day,
              12,
              30,
            ),
            kcal: 950,
            proteinG: 150,
            mealType: 'lunch',
            sessionId: 'session_yesterday_ok_3',
          ),
        ]),
      });

      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          onboardingResult: _testOnboardingResult(),
          nowProvider: () => _fixedNow,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Steady so far'), findsOneWidget);
      expect(
        find.text('Keep your next meal around 400-500 kcal'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'latest card uses selected day and category entry opens details',
    (tester) async {
      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(controller: controller, skipOnboarding: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fab-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-manual')));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'CategoryTapMeal');
      await tester.enterText(fields.at(1), '420');
      await tester.enterText(fields.at(2), '250');
      await tester.enterText(fields.at(3), '24');
      await tester.enterText(fields.at(4), '12');
      await tester.enterText(fields.at(5), '40');
      await tester.ensureVisible(find.byKey(const Key('meal-type-lunch')));
      await tester.tap(find.byKey(const Key('meal-type-lunch')));
      await tester.ensureVisible(find.text('Add Meal').last);
      await tester.tap(find.text('Add Meal').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('latest-added-filled')), findsOneWidget);
      expect(find.text('CategoryTapMeal'), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('category-card-lunch')));
      await tester.tap(find.byKey(const Key('category-card-lunch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-content-lunch')), findsOneWidget);

      final entryFinder = find.descendant(
        of: find.byKey(const Key('category-content-lunch')),
        matching: find.text('CategoryTapMeal'),
      );
      await tester.tap(entryFinder.first);
      await tester.pumpAndSettle();
      expect(find.text('Meal type: Lunch'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('day-chip-0')));
      await tester.tap(find.byKey(const Key('day-chip-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('latest-added-card')), findsNothing);
      expect(find.byKey(const Key('history-empty-card')), findsOneWidget);
    },
  );

  testWidgets('lunch category splits sessions into Main meal and Extras', (
    tester,
  ) async {
    final today = DateTime.now();
    final dayOnly = DateTime(today.year, today.month, today.day);

    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        {
          'requestId': 'lunch_main',
          'origin': 'manual',
          'name': 'LunchMainMeal',
          'day': dayOnly.toIso8601String(),
          'timestamp': DateTime(
            dayOnly.year,
            dayOnly.month,
            dayOnly.day,
            13,
            0,
          ).toIso8601String(),
          'kcal': 420.0,
          'proteinG': 28.0,
          'carbsG': 35.0,
          'fatG': 14.0,
          'portionG': 250.0,
          'confidence': 1.0,
          'per100Kcal': 168.0,
          'per100ProteinG': 11.2,
          'per100CarbsG': 14.0,
          'per100FatG': 5.6,
          'userSelectedType': 'lunch',
          'autoDetectedType': 'lunch',
          'finalType': 'lunch',
          'autoDetectedTier': 'mainMeal',
          'finalTier': 'mainMeal',
          'sessionId': 'session_a',
        },
        {
          'requestId': 'lunch_extra',
          'origin': 'manual',
          'name': 'LunchExtraMeal',
          'day': dayOnly.toIso8601String(),
          'timestamp': DateTime(
            dayOnly.year,
            dayOnly.month,
            dayOnly.day,
            14,
            0,
          ).toIso8601String(),
          'kcal': 120.0,
          'proteinG': 2.0,
          'carbsG': 27.0,
          'fatG': 1.0,
          'portionG': 120.0,
          'confidence': 1.0,
          'per100Kcal': 100.0,
          'per100ProteinG': 1.7,
          'per100CarbsG': 22.5,
          'per100FatG': 0.8,
          'userSelectedType': 'lunch',
          'autoDetectedType': 'lunch',
          'finalType': 'lunch',
          'autoDetectedTier': 'extra',
          'finalTier': 'extra',
          'sessionId': 'session_b',
        },
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('category-card-lunch')));
    await tester.tap(find.byKey(const Key('category-card-lunch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-content-lunch')), findsOneWidget);
    expect(find.byKey(const Key('main-meal-section-title')), findsOneWidget);
    expect(find.byKey(const Key('extras-section-title')), findsOneWidget);
    expect(find.text('LunchMainMeal'), findsWidgets);
    expect(find.text('LunchExtraMeal'), findsWidgets);

    final snackKcal = find.descendant(
      of: find.byKey(const Key('category-card-snacks')),
      matching: find.byKey(const Key('category-kcal-snacks')),
    );
    expect(snackKcal, findsOneWidget);
    final snackKcalText = tester.widget<Text>(snackKcal).data ?? '';
    expect(snackKcalText, contains('0 /'));
  });

  testWidgets('activity step has 4 options without athlete', (tester) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    if (find.text("What's your goal?").evaluate().isNotEmpty) {
      await tester.tap(find.text('Lose fat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    if (find.text('Basic profile').evaluate().isNotEmpty) {
      await tester.tap(find.text('Male'));
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '24');
      await tester.enterText(
        find.widgetWithText(TextField, 'Height, cm'),
        '178',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Weight, kg'),
        '82',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Activity level'), findsOneWidget);
    expect(find.text('Sedentary'), findsOneWidget);
    expect(find.text('Lightly active'), findsOneWidget);
    expect(find.text('Moderately active'), findsOneWidget);
    expect(find.text('Light workouts 1-2 times/week'), findsOneWidget);
    expect(find.text('Athlete'), findsNothing);
  });

  testWidgets('restores completed onboarding result on cold start', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    SharedPreferences.setMockInitialValues({
      'app.onboarding.result': jsonEncode({
        'goalType': 'loseWeight',
        'sex': 'male',
        'age': 28,
        'heightCm': 180.0,
        'weightKg': 82.0,
        'activityLevel': 'lightlyActive',
        'targetPace': 'balanced',
        'macroProfile': 'balanced',
        'plan': {
          'calorieTarget': 2200,
          'proteinTargetG': 150,
          'fatTargetG': 65,
          'carbsTargetG': 240,
        },
      }),
    });

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fab-add')), findsOneWidget);
    expect(find.text('Track calories from food photos'), findsNothing);
  });

  testWidgets('restores onboarding draft step when result is missing', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    SharedPreferences.setMockInitialValues({
      'app.onboarding.draft': jsonEncode({
        'step': 2,
        'goalType': 'loseWeight',
        'sexType': 'male',
        'activityLevel': null,
        'targetPace': null,
        'macroProfile': 'balanced',
        'heightUnit': 'cm',
        'weightUnit': 'kg',
        'ageText': '24',
        'heightText': '178',
        'feetText': '',
        'inchesText': '',
        'weightText': '82',
      }),
    });

    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Basic profile'), findsOneWidget);
    expect(find.text('Track calories from food photos'), findsNothing);
  });

  testWidgets(
    'editing meal grams recalculates kcal and macros proportionally',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app.debug.meal_details': false});
      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(controller: controller, skipOnboarding: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fab-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-manual')));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Test Meal');
      await tester.enterText(fields.at(1), '250');
      await tester.enterText(fields.at(2), '250');
      await tester.enterText(fields.at(3), '25');
      await tester.enterText(fields.at(4), '10');
      await tester.enterText(fields.at(5), '30');
      await tester.ensureVisible(find.text('Add Meal').last);
      await tester.tap(find.text('Add Meal').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Test Meal'));
      await tester.tap(find.text('Test Meal'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Meal'), findsOneWidget);
      expect(find.text('Confidence: 100%'), findsNothing);

      final editFields = find.byType(TextField);
      await tester.enterText(editFields.at(2), '100');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Test Meal'));
      await tester.tap(find.text('Test Meal'));
      await tester.pumpAndSettle();
      final updatedFields = find.byType(TextField);
      expect(
        tester.widget<TextField>(updatedFields.at(1)).controller!.text,
        '124.0',
      );
      expect(
        tester.widget<TextField>(updatedFields.at(3)).controller!.text,
        '10.0',
      );
      expect(
        tester.widget<TextField>(updatedFields.at(4)).controller!.text,
        '4.0',
      );
      expect(
        tester.widget<TextField>(updatedFields.at(5)).controller!.text,
        '12.0',
      );
    },
  );
  testWidgets(
    'new manual meal clears auto-filled zeroes when numeric fields receive focus',
    (tester) async {
      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(controller: controller, skipOnboarding: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fab-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-manual')));
      await tester.pumpAndSettle();

      Finder input(String suffix) => find.descendant(
        of: find.byKey(Key('meal-input-$suffix')),
        matching: find.byType(TextField),
      );

      await tester.enterText(input('calories'), '400');
      await tester.pump();

      for (final suffix in ['weight', 'protein', 'fat', 'carbs']) {
        final field = input(suffix);
        await tester.ensureVisible(field);
        expect(tester.widget<TextField>(field).controller!.text, '0.0');
        await tester.tap(field);
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      }
    },
  );
  testWidgets('editing meal protein saves manual macro override', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Protein Edit Meal');
    await tester.enterText(fields.at(1), '250');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Protein Edit Meal'));
    await tester.tap(find.text('Protein Edit Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(3), '40');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Protein Edit Meal'));
    await tester.tap(find.text('Protein Edit Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Calories: 370.0 kcal'), findsOneWidget);
    expect(find.text('Protein: 40.0 g'), findsOneWidget);
    expect(find.text('Fat: 10.0 g'), findsOneWidget);
    expect(find.text('Carbs: 30.0 g'), findsOneWidget);
  });
  testWidgets('editing meal uses original meal values as numeric hints', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Hint Source Meal');
    await tester.enterText(fields.at(1), '290');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Hint Source Meal'));
    await tester.tap(find.text('Hint Source Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(editFields[1].decoration?.hintText, '290');
    expect(editFields[2].decoration?.hintText, '250');
    expect(editFields[3].decoration?.hintText, '25');
    expect(editFields[4].decoration?.hintText, '10');
    expect(editFields[5].decoration?.hintText, '30');
  });
  testWidgets('editing inconsistent meal shows reset auto calc immediately', (
    tester,
  ) async {
    final now = DateTime(2026, 4, 2, 13, 0);
    SharedPreferences.setMockInitialValues({
      'app.meals': jsonEncode([
        {
          'requestId': 'manual_inconsistent',
          'origin': 'manual',
          'name': 'Inconsistent Meal',
          'day': now.toIso8601String(),
          'timestamp': now.toIso8601String(),
          'kcal': 500.0,
          'proteinG': 25.0,
          'carbsG': 30.0,
          'fatG': 10.0,
          'portionG': 250.0,
          'confidence': 1.0,
          'per100Kcal': 200.0,
          'per100ProteinG': 10.0,
          'per100CarbsG': 12.0,
          'per100FatG': 4.0,
          'autoDetectedType': 'lunch',
          'finalType': 'lunch',
          'autoDetectedTier': 'extra',
          'finalTier': 'extra',
          'sessionId': 'manual_inconsistent',
        },
      ]),
    });

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(
        controller: controller,
        skipOnboarding: true,
        nowProvider: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Inconsistent Meal'));
    await tester.tap(find.text('Inconsistent Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset-auto-calc')), findsOneWidget);
    expect(
      find.text(
        'This meal has inconsistent nutrition values. Reset auto-calc to normalize it.',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'editing meal ignores small calorie mismatch within fifteen percent',
    (tester) async {
      final now = DateTime(2026, 4, 2, 13, 0);
      SharedPreferences.setMockInitialValues({
        'app.meals': jsonEncode([
          {
            'requestId': 'manual_small_mismatch',
            'origin': 'manual',
            'name': 'Small Mismatch Meal',
            'day': now.toIso8601String(),
            'timestamp': now.toIso8601String(),
            'kcal': 330.0,
            'proteinG': 25.0,
            'carbsG': 30.0,
            'fatG': 10.0,
            'portionG': 250.0,
            'confidence': 1.0,
            'per100Kcal': 132.0,
            'per100ProteinG': 10.0,
            'per100CarbsG': 12.0,
            'per100FatG': 4.0,
            'autoDetectedType': 'lunch',
            'finalType': 'lunch',
            'autoDetectedTier': 'extra',
            'finalTier': 'extra',
            'sessionId': 'manual_small_mismatch',
          },
        ]),
      });

      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(
          controller: controller,
          skipOnboarding: true,
          nowProvider: () => now,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Small Mismatch Meal'));
      await tester.tap(find.text('Small Mismatch Meal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset-auto-calc')), findsNothing);
      expect(find.byKey(const Key('meal-form-message')), findsNothing);
    },
  );
  testWidgets('locked calories protein conflict can save as entered', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Locked Calories Proposal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Locked Calories Proposal'));
    await tester.tap(find.text('Locked Calories Proposal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(1), '400');
    await tester.enterText(editFields.at(3), '40');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Keep calories fixed?'), findsOneWidget);
    expect(
      find.byKey(const Key('locked-calories-save-as-entered')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('locked-calories-auto-save')), findsOneWidget);

    await tester.tap(find.byKey(const Key('locked-calories-save-as-entered')));
    await tester.pumpAndSettle();

    expect(find.text('Keep calories fixed?'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);

    await tester.ensureVisible(find.text('Locked Calories Proposal'));
    await tester.tap(find.text('Locked Calories Proposal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final savedFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(savedFields[1].controller?.text, '400.0');
    expect(savedFields[3].controller?.text, '40.0');
    expect(savedFields[4].controller?.text, '12.9');
    expect(savedFields[5].controller?.text, '38.7');
  });
  testWidgets('locked calories protein conflict auto adjusts and saves', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Protein Auto Save Meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Protein Auto Save Meal'));
    await tester.tap(find.text('Protein Auto Save Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(1), '400');
    await tester.enterText(editFields.at(3), '40');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Keep calories fixed?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locked-calories-auto-save')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Protein Auto Save Meal'));
    await tester.tap(find.text('Protein Auto Save Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Calories: 400.0 kcal'), findsOneWidget);
    expect(find.text('Protein: 40.0 g'), findsOneWidget);
    expect(find.text('Fat: 11.4 g'), findsOneWidget);
    expect(find.text('Carbs: 34.3 g'), findsOneWidget);
  });
  testWidgets('locked field shows yellow outline and unlock icon', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(3), '40');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-lock-protein')), findsOneWidget);
    final proteinContainer = tester.widget<Container>(
      find.byKey(const Key('meal-input-protein')),
    );
    final decoration = proteinContainer.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, const Color(0xFFFACC15));
  });
  testWidgets('double tap locks meal field without changing its value', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Double Tap Lock Meal');
    await tester.enterText(fields.at(1), '250');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Double Tap Lock Meal'));
    await tester.tap(find.text('Double Tap Lock Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final proteinField = find.byKey(const Key('meal-input-protein'));
    await tester.tap(proteinField);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(proteinField);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-lock-protein')), findsOneWidget);
    final proteinContainer = tester.widget<Container>(proteinField);
    final decoration = proteinContainer.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, const Color(0xFFFACC15));

    final proteinTextField = tester
        .widgetList<TextField>(find.byType(TextField))
        .elementAt(3);
    expect(proteinTextField.controller?.text, '25.0');
  });
  testWidgets('unlocking calories immediately recalculates them from macros', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.enterText(fields.at(1), '400');
    await tester.enterText(fields.at(3), '40');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-lock-calories')), findsOneWidget);
    await tester.tap(find.byKey(const Key('meal-lock-calories')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-lock-calories')), findsNothing);
    expect(find.text('370.0'), findsOneWidget);
  });
  testWidgets('locked protein stays fixed when calories are edited later', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Locked Protein Meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.enterText(fields.at(3), '40');
    await tester.enterText(fields.at(1), '500');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Locked Protein Meal'));
    await tester.tap(find.text('Locked Protein Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Calories: 500.0 kcal'), findsOneWidget);
    expect(find.text('Protein: 40.0 g'), findsOneWidget);
  });
  testWidgets('locked calories fat conflict auto adjusts and saves', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Fat Auto Save Meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Fat Auto Save Meal'));
    await tester.tap(find.text('Fat Auto Save Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(1), '400');
    await tester.enterText(editFields.at(4), '25');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Keep calories fixed?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locked-calories-auto-save')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Fat Auto Save Meal'));
    await tester.tap(find.text('Fat Auto Save Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Calories: 400.0 kcal'), findsOneWidget);
    expect(find.text('Protein: 19.9 g'), findsOneWidget);
    expect(find.text('Fat: 25.0 g'), findsOneWidget);
    expect(find.text('Carbs: 23.9 g'), findsOneWidget);
  });
  testWidgets(
    'locked calories confirm respects all manual macro changes in one session',
    (tester) async {
      final controller = PhotoFoodController(
        repository: _FakeRepository(),
        photoPicker: _FakePicker(file: null),
      );

      await tester.pumpWidget(
        MyApp(controller: controller, skipOnboarding: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fab-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-manual')));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Multi Manual Macro Meal');
      await tester.enterText(fields.at(2), '250');
      await tester.enterText(fields.at(3), '25');
      await tester.enterText(fields.at(4), '10');
      await tester.enterText(fields.at(5), '30');
      await tester.ensureVisible(find.text('Add Meal').last);
      await tester.tap(find.text('Add Meal').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Multi Manual Macro Meal'));
      await tester.tap(find.text('Multi Manual Macro Meal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final editFields = find.byType(TextField);
      await tester.enterText(editFields.at(1), '400');
      await tester.enterText(editFields.at(3), '40');
      await tester.enterText(editFields.at(4), '20');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Keep calories fixed?'), findsOneWidget);
      expect(find.text('Updated fields: Carbs'), findsOneWidget);
      await tester.tap(find.byKey(const Key('locked-calories-auto-save')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Multi Manual Macro Meal'));
      await tester.tap(find.text('Multi Manual Macro Meal'));
      await tester.pumpAndSettle();
      expect(find.text('Calories: 400.0 kcal'), findsOneWidget);
      expect(find.text('Protein: 40.0 g'), findsOneWidget);
      expect(find.text('Fat: 20.0 g'), findsOneWidget);
      expect(find.text('Carbs: 15.0 g'), findsOneWidget);
    },
  );
  testWidgets('locked calories carbs conflict auto adjusts and saves', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Carbs Auto Save Meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Carbs Auto Save Meal'));
    await tester.tap(find.text('Carbs Auto Save Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(1), '400');
    await tester.enterText(editFields.at(5), '60');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Keep calories fixed?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('locked-calories-auto-save')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Carbs Auto Save Meal'));
    await tester.tap(find.text('Carbs Auto Save Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Calories: 400.0 kcal'), findsOneWidget);
    expect(find.text('Protein: 21.1 g'), findsOneWidget);
    expect(find.text('Fat: 8.4 g'), findsOneWidget);
    expect(find.text('Carbs: 60.0 g'), findsOneWidget);
  });
  testWidgets('unlocking protein lets auto-calc rebalance it again', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '40');
    await tester.enterText(fields.at(4), '20');
    await tester.enterText(fields.at(5), '50');
    await tester.enterText(fields.at(1), '400');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'All macros are manually locked. Unlock one macro or reset auto-calc to continue.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('meal-lock-protein')), findsOneWidget);
    await tester.tap(find.byKey(const Key('meal-lock-protein')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal-lock-protein')), findsNothing);
    expect(find.text('5.0'), findsOneWidget);
    expect(
      find.text(
        'All macros are manually locked. Unlock one macro or reset auto-calc to continue.',
      ),
      findsNothing,
    );
    expect(
      find.text(
        'This field can’t be auto-adjusted because other nutrition values were edited manually.',
      ),
      findsNothing,
    );
  });
  testWidgets('locked protein remains unchanged when weight changes later', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Weight Lock Meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Weight Lock Meal'));
    await tester.tap(find.text('Weight Lock Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(3), '40');
    await tester.enterText(editFields.at(2), '500');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Weight Lock Meal'));
    await tester.tap(find.text('Weight Lock Meal'));
    await tester.pumpAndSettle();
    expect(find.text('Protein: 40.0 g'), findsOneWidget);
    expect(find.text('Fat: 20.0 g'), findsOneWidget);
    expect(find.text('Carbs: 60.0 g'), findsOneWidget);
    expect(find.text('Calories: 580.0 kcal'), findsOneWidget);
  });
  testWidgets('reset auto calc clears locks and recalculates calories', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.enterText(fields.at(1), '400');
    await tester.enterText(fields.at(3), '40');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset-auto-calc')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reset-auto-calc')));
    await tester.tap(find.byKey(const Key('reset-auto-calc')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset-auto-calc')), findsNothing);
    expect(find.byKey(const Key('meal-lock-calories')), findsNothing);
    expect(find.byKey(const Key('meal-lock-protein')), findsNothing);
    expect(find.byKey(const Key('meal-form-message')), findsNothing);
    expect(find.text('370.0'), findsOneWidget);
  });
  testWidgets('restore start values returns edit session to initial state', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Restore Start Meal');
    await tester.enterText(fields.at(1), '290');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Restore Start Meal'));
    await tester.tap(find.text('Restore Start Meal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final editFields = find.byType(TextField);
    await tester.enterText(editFields.at(1), '400');
    await tester.enterText(editFields.at(3), '40');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('restore-session-start')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('restore-session-start')));
    await tester.tap(find.byKey(const Key('restore-session-start')));
    await tester.pumpAndSettle();

    final restoredFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(restoredFields[0].controller?.text, 'Restore Start Meal');
    expect(restoredFields[1].controller?.text, '290.0');
    expect(restoredFields[2].controller?.text, '250.0');
    expect(restoredFields[3].controller?.text, '25.0');
    expect(restoredFields[4].controller?.text, '10.0');
    expect(restoredFields[5].controller?.text, '30.0');
    expect(find.byKey(const Key('meal-lock-calories')), findsNothing);
    expect(find.byKey(const Key('meal-lock-protein')), findsNothing);
    expect(find.byKey(const Key('restore-session-start')), findsNothing);
  });
  testWidgets('conflicting locked nutrition values show form error', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Conflict Meal');
    await tester.enterText(fields.at(2), '250');
    await tester.enterText(fields.at(3), '25');
    await tester.enterText(fields.at(4), '10');
    await tester.enterText(fields.at(5), '30');
    await tester.enterText(fields.at(3), '40');
    await tester.enterText(fields.at(4), '20');
    await tester.enterText(fields.at(5), '50');
    await tester.enterText(fields.at(1), '400');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'All macros are manually locked. Unlock one macro or reset auto-calc to continue.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Add Meal').last);
    await tester.tap(find.text('Add Meal').last);
    await tester.pumpAndSettle();
    expect(find.text('Keep calories fixed?'), findsNothing);
    expect(find.text('Conflict Meal'), findsWidgets);
  });
  testWidgets('manual meal sheet shows redesigned meal type cards', (
    tester,
  ) async {
    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );

    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    expect(find.text('Add Meal'), findsWidgets);
    expect(find.text('Meal Type'), findsOneWidget);
    expect(find.byKey(const Key('meal-type-breakfast')), findsOneWidget);
    expect(find.byKey(const Key('meal-type-lunch')), findsOneWidget);
    expect(find.byKey(const Key('meal-type-dinner')), findsOneWidget);
    expect(find.byKey(const Key('meal-type-snack')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('meal-type-lunch')));
    await tester.tap(find.byKey(const Key('meal-type-lunch')));
    await tester.pumpAndSettle();
  });

  testWidgets('manual meal submit stays visible on a compact screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(432, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = PhotoFoodController(
      repository: _FakeRepository(),
      photoPicker: _FakePicker(file: null),
    );
    await tester.pumpWidget(
      MyApp(controller: controller, skipOnboarding: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('manual-meal-submit'));
    expect(submit, findsOneWidget);
    expect(
      tester.getRect(submit).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );

    await tester.showKeyboard(find.byType(TextField).first);
    await tester.pump();
    expect(
      tester.getRect(submit).bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
    );
  });
}

final DateTime _fixedNow = DateTime(2026, 4, 2, 13, 0);
final DateTime _fixedToday = DateTime(
  _fixedNow.year,
  _fixedNow.month,
  _fixedNow.day,
);
final DateTime _fixedYesterday = _fixedToday.subtract(const Duration(days: 1));

OnboardingResult _testOnboardingResult() {
  return decodeOnboardingResultForTest(
        jsonEncode({
          'goalType': 'loseWeight',
          'sex': 'male',
          'age': 28,
          'heightCm': 180.0,
          'weightKg': 82.0,
          'activityLevel': 'lightlyActive',
          'targetPace': 'balanced',
          'macroProfile': 'balanced',
          'plan': {
            'calorieTarget': 2000,
            'proteinTargetG': 150,
            'fatTargetG': 65,
            'carbsTargetG': 220,
          },
        }),
      ) ??
      (throw StateError('Failed to build test onboarding result'));
}

Map<String, dynamic> _mealJson({
  required String requestId,
  required DateTime day,
  required DateTime timestamp,
  required double kcal,
  required double proteinG,
  required String mealType,
  required String sessionId,
}) {
  return {
    'requestId': requestId,
    'origin': 'manual',
    'name': requestId,
    'day': day.toIso8601String(),
    'timestamp': timestamp.toIso8601String(),
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': 30.0,
    'fatG': 12.0,
    'portionG': 250.0,
    'confidence': 1.0,
    'per100Kcal': kcal / 2.5,
    'per100ProteinG': proteinG / 2.5,
    'per100CarbsG': 12.0,
    'per100FatG': 4.8,
    'userSelectedType': mealType,
    'autoDetectedType': mealType,
    'finalType': mealType,
    'autoDetectedTier': 'mainMeal',
    'finalTier': 'mainMeal',
    'sessionId': sessionId,
  };
}

class _FakePicker implements PhotoPicker {
  final XFile? file;

  _FakePicker({required this.file});

  @override
  Future<XFile?> pick(PickSource source) async => file;
}

class _RecordingAnalytics implements Analytics {
  final List<AnalyticsEvent> events = [];

  @override
  void track(AnalyticsEvent event) => events.add(event);
}

class _FakeRepository implements PhotoFoodRepository {
  final bool requiresConfirmation;
  final List<DishCategory> clarificationCategories;
  PhotoClarificationInput? lastClarification;
  String? lastLocale;
  int analyzeCallCount = 0;

  _FakeRepository({
    this.requiresConfirmation = false,
    this.clarificationCategories = const [],
  });

  @override
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale = 'en-US',
    String? mealTime,
    PhotoClarificationInput? clarification,
  }) async {
    analyzeCallCount += 1;
    lastLocale = locale;
    lastClarification = clarification;
    final isClarified = clarification != null;
    return PhotoFoodResponse(
      requestId: 'req_123',
      item: Item(
        name: isClarified ? 'Clarified meal estimate' : 'Oatmeal with berries',
        category: 'breakfast',
        foodType: 'solid',
        confidence: 0.92,
        nutritionPer100g: const NutritionPer100g(
          kcal: 120,
          proteinG: 4,
          fatG: 3,
          carbsG: 18,
        ),
        warnings: [],
      ),
      uiFlags: UiFlags(
        requiresUserConfirmation: requiresConfirmation,
        highlightLevel: requiresConfirmation ? 'orange' : 'none',
      ),
      meta: Meta(
        needsConfirmation: requiresConfirmation,
        estimatedPortionG: requiresConfirmation ? 240 : 250,
        portionBasis: requiresConfirmation ? 'visual estimate' : 'model',
        confirmationSource: null,
        totalsAreEstimate: true,
        estimatedTotals: const EstimatedTotals(
          kcal: 300,
          proteinG: 10,
          fatG: 8,
          carbsG: 45,
        ),
        clarificationCategories: clarificationCategories,
      ),
    );
  }

  @override
  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  }) async {
    final confirmed = useAiEstimate ? 240.0 : (portionG ?? 0.0);
    return PhotoFoodResponse(
      requestId: requestId,
      item: const Item(
        name: 'Oatmeal with berries',
        category: 'breakfast',
        foodType: 'solid',
        confidence: 0.92,
        nutritionPer100g: NutritionPer100g(
          kcal: 120,
          proteinG: 4,
          fatG: 3,
          carbsG: 18,
        ),
        warnings: [],
      ),
      uiFlags: UiFlags(requiresUserConfirmation: false, highlightLevel: 'none'),
      meta: Meta(
        needsConfirmation: false,
        estimatedPortionG: confirmed,
        portionBasis: useAiEstimate
            ? 'ai_estimate_confirmed'
            : 'user_confirmed',
        confirmationSource: useAiEstimate ? 'ai_estimate' : 'user_input',
        totalsAreEstimate: true,
        estimatedTotals: EstimatedTotals(
          kcal: confirmed * 1.2,
          proteinG: confirmed * 0.04,
          fatG: confirmed * 0.03,
          carbsG: confirmed * 0.18,
        ),
        clarificationCategories: clarificationCategories,
      ),
    );
  }
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale = 'en-US',
    String? mealTime,
    PhotoClarificationInput? clarification,
  }) async {
    throw const ApiException(
      ApiError(code: 'NETWORK_ERROR', message: 'Network error'),
    );
  }
}
