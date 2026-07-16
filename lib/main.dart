import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics.dart';
import 'app_config.dart';
import 'firebase_analytics_adapter.dart';
import 'home_coach.dart';
import 'meal_session.dart';
import 'meal_type.dart';
import 'onboarding.dart';
import 'photo_food/api_client.dart';
import 'photo_food/api_error.dart';
import 'photo_food/controller.dart';
import 'photo_food/models.dart';
import 'photo_food/photo_picker.dart';
import 'photo_food/repository.dart';
import 'profile/profile_page.dart';

part 'meal_edit_draft.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Analytics? analytics;
  if (_supportsFirebaseAnalytics) {
    try {
      await Firebase.initializeApp();
      analytics = FirebaseAnalyticsAdapter();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase Analytics is unavailable: $error');
      }
    }
  }
  runApp(MyApp(analytics: analytics));
}

bool get _supportsFirebaseAnalytics =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

class MyApp extends StatefulWidget {
  final PhotoFoodController? controller;
  final AppConfig? config;
  final PhotoFoodRepository? repository;
  final PhotoPicker? photoPicker;
  final bool skipOnboarding;
  final OnboardingResult? onboardingResult;
  final DateTime Function()? nowProvider;
  final Analytics? analytics;

  const MyApp({
    super.key,
    this.controller,
    this.config,
    this.repository,
    this.photoPicker,
    this.skipOnboarding = false,
    this.onboardingResult,
    this.nowProvider,
    this.analytics,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const _onboardingResultKey = 'app.onboarding.result';
  static const _onboardingDraftKey = 'app.onboarding.draft';
  static const _mealsKey = 'app.meals';
  static const _debugMealDetailsKey = 'app.debug.meal_details';

  late final PhotoFoodController _controller;
  late final bool _ownsController;
  late final bool _photoAnalysisAvailable;
  late final Analytics _analytics;
  OnboardingResult? _onboardingResult;
  OnboardingDraft? _onboardingDraft;
  List<_MealEntry> _persistedMeals = const [];
  bool _showDebugMealDetails = kDebugMode;
  bool _isHydrated = false;
  bool _wasBackgrounded = false;
  Future<void> _persistQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _onboardingResult = widget.onboardingResult;
    _analytics = widget.analytics ?? const DebugAnalytics();
    _analytics.track(AnalyticsEvent(AnalyticsEvents.appOpened));
    WidgetsBinding.instance.addObserver(this);

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
      _photoAnalysisAvailable = true;
    } else {
      final config = widget.config ?? AppConfig.tryFromEnvironment();
      final repository =
          widget.repository ??
          (config == null
              ? const UnavailablePhotoFoodRepository()
              : PhotoFoodApiClient(config: config));
      final picker = widget.photoPicker ?? ImagePickerPhotoPicker();
      _controller = PhotoFoodController(
        repository: repository,
        photoPicker: picker,
      );
      _ownsController = true;
      _photoAnalysisAvailable = widget.repository != null || config != null;
    }

    _hydrateState();
  }

  Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _hydrateState() async {
    final prefs = await _prefsOrNull();
    if (!mounted) return;

    if (prefs != null) {
      final resultRaw = prefs.getString(_onboardingResultKey);
      final draftRaw = prefs.getString(_onboardingDraftKey);
      final mealsRaw = prefs.getString(_mealsKey);
      final debugMealDetails = prefs.getBool(_debugMealDetailsKey);

      final restoredResult =
          widget.onboardingResult ?? _decodeOnboardingResult(resultRaw);
      final restoredDraft = _decodeOnboardingDraft(draftRaw);
      final restoredMeals = _decodeMeals(mealsRaw);

      setState(() {
        _onboardingResult = restoredResult;
        _onboardingDraft = restoredDraft;
        _persistedMeals = restoredMeals;
        _showDebugMealDetails = debugMealDetails ?? kDebugMode;
        _isHydrated = true;
      });
      if (kDebugMode) {
        debugPrint('[persistence] Hydrated app state');
      }
      return;
    }

    setState(() => _isHydrated = true);
    if (kDebugMode) {
      debugPrint(
        '[persistence] Hydration skipped: SharedPreferences unavailable',
      );
    }
  }

  Future<void> _persistState() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return;

    if (_onboardingResult == null) {
      await prefs.remove(_onboardingResultKey);
    } else {
      await prefs.setString(
        _onboardingResultKey,
        jsonEncode(_encodeOnboardingResult(_onboardingResult!)),
      );
    }

    if (_onboardingDraft == null) {
      await prefs.remove(_onboardingDraftKey);
    } else {
      await prefs.setString(
        _onboardingDraftKey,
        jsonEncode(_onboardingDraft!.toJson()),
      );
    }

    await prefs.setString(
      _mealsKey,
      jsonEncode(_persistedMeals.map((m) => m.toJson()).toList()),
    );
    await prefs.setBool(_debugMealDetailsKey, _showDebugMealDetails);
  }

  Future<void> _enqueuePersistState({required String reason}) {
    _persistQueue = _persistQueue.then((_) async {
      try {
        await _persistState();
        if (kDebugMode &&
            reason != 'draft_changed' &&
            reason != 'meals_changed') {
          debugPrint('[persistence] Persisted: $reason');
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[persistence] Persist failed ($reason): $error');
        }
      }
    });
    return _persistQueue;
  }

  Future<void> _handleOnboardingCompleted(
    OnboardingResult result, {
    bool isProfileEdit = false,
  }) async {
    setState(() {
      _onboardingResult = result;
      _onboardingDraft = null;
    });
    await _enqueuePersistState(reason: 'onboarding_completed');
    if (!isProfileEdit) {
      _analytics.track(AnalyticsEvent(AnalyticsEvents.onboardingCompleted));
    }
  }

  Future<void> _openProfileEditor(BuildContext context) async {
    final initialDraft = _buildProfileEditDraft();
    final updatedResult = await Navigator.of(context).push<OnboardingResult>(
      MaterialPageRoute(
        builder: (routeContext) => OnboardingFlow(
          initialDraft: initialDraft,
          popOnBackAtEntryStep: true,
          onDraftChanged: _handleOnboardingDraftChanged,
          onCompleted: (result) async => Navigator.of(routeContext).pop(result),
        ),
      ),
    );
    if (!mounted || updatedResult == null) return;
    await _handleOnboardingCompleted(updatedResult, isProfileEdit: true);
  }

  OnboardingDraft _buildProfileEditDraft() {
    final result = _onboardingResult;
    if (result != null) {
      return OnboardingDraft(
        step: 2,
        goalType: result.goalType,
        sexType: result.sex == SexType.male ? SexType.male : SexType.female,
        activityLevel: result.activityLevel,
        targetPace: result.targetPace,
        macroProfile: result.macroProfile,
        heightUnit: HeightUnit.cm,
        weightUnit: WeightUnit.kg,
        ageText: result.age.toString(),
        heightText: _formatEditableNumber(result.heightCm),
        feetText: '',
        inchesText: '',
        weightText: _formatEditableNumber(result.weightKg),
      );
    }
    return _onboardingDraft ??
        const OnboardingDraft(
          step: 2,
          goalType: null,
          sexType: null,
          activityLevel: null,
          targetPace: null,
          macroProfile: MacroProfile.balanced,
          heightUnit: HeightUnit.cm,
          weightUnit: WeightUnit.kg,
          ageText: '',
          heightText: '',
          feetText: '',
          inchesText: '',
          weightText: '',
        );
  }

  String _formatEditableNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  void _handleOnboardingDraftChanged(OnboardingDraft draft) {
    _onboardingDraft = draft;
    _enqueuePersistState(reason: 'draft_changed');
  }

  void _setDebugMealDetails(bool enabled) {
    if (_showDebugMealDetails == enabled) return;
    setState(() => _showDebugMealDetails = enabled);
    _enqueuePersistState(reason: 'debug_meal_details_changed');
  }

  void _handleMealsChanged(List<_MealEntry> meals) {
    final previousMeals = _persistedMeals;
    final previousIds = previousMeals.map((meal) => meal.requestId).toSet();
    final addedMeals =
        meals.where((meal) => !previousIds.contains(meal.requestId)).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final knownMealIds = Set<String>.from(previousIds);

    _persistedMeals = List<_MealEntry>.from(meals);
    _enqueuePersistState(reason: 'meals_changed');

    for (var index = 0; index < addedMeals.length; index++) {
      final meal = addedMeals[index];
      final now = widget.nowProvider?.call() ?? DateTime.now();
      final dayOffset = _dateOnly(meal.day).difference(_dateOnly(now)).inDays;
      final createsNewSession = !meals.any(
        (existingMeal) =>
            existingMeal.sessionId == meal.sessionId &&
            knownMealIds.contains(existingMeal.requestId),
      );
      final properties = <String, Object?>{
        'source': meal.origin.name,
        'day_offset': dayOffset,
        'creates_new_session': createsNewSession,
      };
      _analytics.track(
        AnalyticsEvent(AnalyticsEvents.mealLogged, properties: properties),
      );
      if (!createsNewSession) {
        _analytics.track(
          AnalyticsEvent(
            AnalyticsEvents.mealLoggedInExistingSession,
            properties: {'source': meal.origin.name, 'day_offset': dayOffset},
          ),
        );
      }
      knownMealIds.add(meal.requestId);
      if (previousMeals.isEmpty && index == 0) {
        _analytics.track(AnalyticsEvent(AnalyticsEvents.firstMealLogged));
      }
    }
  }

  void _resetOnboardingForTesting() {
    setState(() {
      _onboardingResult = null;
      _onboardingDraft = null;
    });
    _enqueuePersistState(reason: 'onboarding_reset');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _analytics.track(AnalyticsEvent(AnalyticsEvents.appOpened));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calories',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B66F6)),
      ),
      home: !_isHydrated
          ? const _BootstrapLoadingScreen()
          : widget.skipOnboarding || _onboardingResult != null
          ? _AppShell(
              controller: _controller,
              onboardingResult: _onboardingResult,
              initialMeals: _persistedMeals,
              onMealsChanged: _handleMealsChanged,
              analytics: _analytics,
              onResetOnboarding: _resetOnboardingForTesting,
              onEditProfile: _openProfileEditor,
              nowProvider: widget.nowProvider,
              photoAnalysisAvailable: _photoAnalysisAvailable,
              showDebugMealDetails: _showDebugMealDetails,
              onDebugMealDetailsChanged: _setDebugMealDetails,
            )
          : OnboardingFlow(
              initialDraft: _onboardingDraft,
              onDraftChanged: _handleOnboardingDraftChanged,
              onStarted: () => _analytics.track(
                AnalyticsEvent(AnalyticsEvents.onboardingStarted),
              ),
              onStepViewed: (step) => _analytics.track(
                AnalyticsEvent(
                  AnalyticsEvents.onboardingStepViewed,
                  properties: {'step': step},
                ),
              ),
              onCompleted: _handleOnboardingCompleted,
            ),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(key: Key('bootstrap-loading')),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  final PhotoFoodController controller;
  final OnboardingResult? onboardingResult;
  final List<_MealEntry> initialMeals;
  final ValueChanged<List<_MealEntry>> onMealsChanged;
  final VoidCallback onResetOnboarding;
  final Future<void> Function(BuildContext context) onEditProfile;
  final DateTime Function()? nowProvider;
  final Analytics analytics;
  final bool photoAnalysisAvailable;
  final bool showDebugMealDetails;
  final ValueChanged<bool> onDebugMealDetailsChanged;

  const _AppShell({
    required this.controller,
    this.onboardingResult,
    required this.initialMeals,
    required this.onMealsChanged,
    required this.onResetOnboarding,
    required this.onEditProfile,
    required this.analytics,
    this.nowProvider,
    required this.photoAnalysisAvailable,
    required this.showDebugMealDetails,
    required this.onDebugMealDetailsChanged,
  });

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int selectedTab = 0;
  final GlobalKey<_CaloriesHomePageState> _homeKey =
      GlobalKey<_CaloriesHomePageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          _CaloriesHomePage(
            key: _homeKey,
            controller: widget.controller,
            onboardingResult: widget.onboardingResult,
            initialMeals: widget.initialMeals,
            onMealsChanged: widget.onMealsChanged,
            nowProvider: widget.nowProvider,
            analytics: widget.analytics,
            photoAnalysisAvailable: widget.photoAnalysisAvailable,
            showDebugMealDetails: widget.showDebugMealDetails,
          ),
          ProfilePage(
            onboardingResult: widget.onboardingResult,
            onResetOnboarding: widget.onResetOnboarding,
            onEditProfile: () => widget.onEditProfile(context),
            showDebugMealDetails: widget.showDebugMealDetails,
            onDebugMealDetailsChanged: widget.onDebugMealDetailsChanged,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        key: const Key('fab-add'),
        backgroundColor: const Color(0xFF2B66F6),
        foregroundColor: Colors.white,
        onPressed: selectedTab == 0
            ? () => _homeKey.currentState?._onPlusTap()
            : null,
        child: const Icon(Icons.add, size: 32),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 20,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: selectedTab == 0,
                onTap: () => setState(() => selectedTab = 0),
              ),
              const SizedBox(width: 48),
              _NavButton(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: selectedTab == 1,
                onTap: () => setState(() => selectedTab = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaloriesHomePage extends StatefulWidget {
  final PhotoFoodController controller;
  final OnboardingResult? onboardingResult;
  final List<_MealEntry> initialMeals;
  final ValueChanged<List<_MealEntry>> onMealsChanged;
  final DateTime Function()? nowProvider;
  final Analytics analytics;
  final bool photoAnalysisAvailable;
  final bool showDebugMealDetails;

  const _CaloriesHomePage({
    super.key,
    required this.controller,
    this.onboardingResult,
    this.initialMeals = const [],
    required this.onMealsChanged,
    this.nowProvider,
    required this.analytics,
    required this.photoAnalysisAvailable,
    required this.showDebugMealDetails,
  });

  @override
  State<_CaloriesHomePage> createState() => _CaloriesHomePageState();
}

class _CaloriesHomePageState extends State<_CaloriesHomePage> {
  int selectedDay = 5;
  String? _lastErrorKey;
  final MealSessionService _mealSessionService = const MealSessionService();
  final HomeCoachEvaluator _coachEvaluator = const HomeCoachEvaluator();
  final List<_MealEntry> meals = [];
  final Map<String, MealSession> _sessionsByEntryId = {};
  final Set<MealType> _expandedCategories = <MealType>{};
  DateTime get _now => widget.nowProvider?.call() ?? DateTime.now();

  List<_DayItem> get days {
    final today = _dateOnly(_now);
    final start = today.subtract(const Duration(days: 5));
    return List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      return _DayItem(
        weekDay: _weekdayLabel(day.weekday),
        dayNum: day.day.toString(),
        date: _dateOnly(day),
      );
    });
  }

  DateTime get _selectedDate => days[selectedDay].date;
  List<_MealEntry> get _selectedMeals => meals
      .where((m) => _isSameDate(m.day, _selectedDate))
      .toList(growable: false);
  List<MealSession> get _selectedSessions {
    final deduplicated = <String, MealSession>{};
    for (final meal in _selectedMeals) {
      final session = _sessionsByEntryId[meal.requestId];
      if (session != null) {
        deduplicated[session.id] = session;
      }
    }
    final sessions = deduplicated.values.toList(growable: false)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  double get _sumKcal =>
      _selectedSessions.fold(0.0, (sum, session) => sum + session.totalKcal);
  double get _sumProtein =>
      _selectedSessions.fold(0.0, (sum, session) => sum + session.totalProtein);
  double get _sumCarbs =>
      _selectedSessions.fold(0.0, (sum, session) => sum + session.totalCarbs);
  double get _sumFats =>
      _selectedSessions.fold(0.0, (sum, session) => sum + session.totalFat);
  double _proteinForDay(DateTime day) => meals
      .where((m) => _isSameDate(m.day, day))
      .fold(0.0, (sum, meal) => sum + meal.proteinG);
  _MealEntry? get _latestAddedMealForSelectedDay {
    if (_selectedMeals.isEmpty) return null;
    final ordered = List<_MealEntry>.from(_selectedMeals)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return ordered.first;
  }

  @override
  void initState() {
    super.initState();
    meals.addAll(widget.initialMeals);
    _rebuildAllSessions();
    widget.controller.addListener(_onControllerUpdated);
  }

  void _notifyMealsChanged() {
    widget.onMealsChanged(List<_MealEntry>.from(meals));
  }

  void _trackClarificationEvent(
    String event, [
    Map<String, Object?> details = const {},
  ]) {
    if (!kDebugMode) return;
    debugPrint('[clarification] $event ${jsonEncode(details)}');
  }

  void _trackMealEditEvent(
    String event, [
    Map<String, Object?> details = const {},
  ]) {
    if (!kDebugMode) return;
    debugPrint('[meal_edit] $event ${jsonEncode(details)}');
  }

  double get _dailyCalorieTarget =>
      widget.onboardingResult?.plan.calorieTarget.toDouble() ?? 2000.0;

  void _rebuildAllSessions() {
    _sessionsByEntryId.clear();
    final days = meals.map((e) => _dateOnly(e.day)).toSet();
    for (final day in days) {
      _rebuildSessionsForDay(day, notify: false);
    }
  }

  void _rebuildSessionsForDay(DateTime day, {bool notify = true}) {
    final dayOnly = _dateOnly(day);
    final dayMeals = meals
        .where((m) => _isSameDate(m.day, dayOnly))
        .toList(growable: false);
    final dayEntries = dayMeals
        .map(
          (meal) => MealSessionEntry(
            id: meal.requestId,
            timestamp: meal.timestamp,
            name: meal.name,
            kcal: meal.kcal,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            carbsG: meal.carbsG,
            userSelectedSessionType: meal.userSelectedType,
          ),
        )
        .toList(growable: false);

    final sessions = _mealSessionService.buildSessionsForDay(
      day: dayOnly,
      entries: dayEntries,
      dailyCalorieTarget: _dailyCalorieTarget,
    );

    _sessionsByEntryId.removeWhere(
      (_, session) => _isSameDate(session.date, dayOnly),
    );
    for (final session in sessions) {
      for (final entry in session.entries) {
        _sessionsByEntryId[entry.id] = session;
      }
    }

    for (var i = 0; i < meals.length; i++) {
      final meal = meals[i];
      if (!_isSameDate(meal.day, dayOnly)) {
        continue;
      }
      final session = _sessionsByEntryId[meal.requestId];
      if (session == null) {
        continue;
      }
      meals[i] = meal.copyWith(
        sessionId: session.id,
        autoDetectedType: session.autoDetectedType,
        autoDetectedTier: session.autoDetectedTier,
        finalType: session.overriddenByUser
            ? meal.userSelectedType ?? session.finalType
            : session.autoDetectedType,
        finalTier: session.finalTier,
      );
    }

    if (notify) {
      _notifyMealsChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdated);
    super.dispose();
  }

  void _onControllerUpdated() {
    final state = widget.controller.state;
    if (state.response != null &&
        (state.status == HomeStatus.awaitingPortion ||
            state.status == HomeStatus.loaded)) {
      _upsertMealFromResponse(state.response!);
    }

    final error = state.error;
    if (error == null || !mounted) return;

    final key = '${error.code}:${error.requestId ?? ''}';
    if (_lastErrorKey == key) return;
    _lastErrorKey = key;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(mapErrorCodeToMessage(error.code)),
          action: SnackBarAction(
            label: 'Add manually',
            onPressed: () async {
              widget.analytics.track(
                AnalyticsEvent(
                  AnalyticsEvents.manualFallbackUsed,
                  properties: {'error_code': error.code},
                ),
              );
              await _showManualMealSheet();
            },
          ),
        ),
      );
  }

  void _upsertMealFromResponse(PhotoFoodResponse response) {
    final totals = response.meta.estimatedTotals;
    final now = _now;
    final entryTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final meal = _MealEntry(
      requestId: response.requestId,
      origin: MealOrigin.ai,
      name: response.item.name,
      day: _selectedDate,
      timestamp: entryTimestamp,
      kcal: totals?.kcal ?? 0,
      proteinG: totals?.proteinG ?? 0,
      carbsG: totals?.carbsG ?? 0,
      fatG: totals?.fatG ?? 0,
      portionG: response.meta.estimatedPortionG,
      confidence: response.item.confidence,
      per100Kcal: response.item.nutritionPer100g.kcal,
      per100ProteinG: response.item.nutritionPer100g.proteinG,
      per100CarbsG: response.item.nutritionPer100g.carbsG,
      per100FatG: response.item.nutritionPer100g.fatG,
      userSelectedType: null,
      sessionId: '',
      autoDetectedType: MealType.snack,
      autoDetectedTier: MealSessionTier.extra,
      finalType: MealType.snack,
      finalTier: MealSessionTier.extra,
    );

    final idx = meals.indexWhere((e) => e.requestId == response.requestId);
    setState(() {
      if (idx >= 0) {
        meals[idx] = meal;
      } else {
        meals.insert(0, meal);
      }
      _rebuildSessionsForDay(_selectedDate, notify: false);
    });
    _notifyMealsChanged();
  }

  Future<void> _onPlusTap() async {
    final action = await _showAddActionSheet();
    if (action == null) return;

    if (action == _AddAction.manual) {
      await _showManualMealSheet();
      return;
    }

    final source = action == _AddAction.camera
        ? PickSource.camera
        : PickSource.gallery;
    final pickedFile = await widget.controller.pickImage(source);
    if (!mounted || pickedFile == null) return;

    final clarification = await _showClarificationBottomSheet();
    if (!mounted) return;

    await widget.controller.analyzePickedImage(clarification: clarification);
    if (!mounted) return;
    final photoState = widget.controller.state;
    final sourceName = source.name;
    if (photoState.status == HomeStatus.error) {
      widget.analytics.track(
        AnalyticsEvent(
          AnalyticsEvents.photoAnalysisFailed,
          properties: {
            'source': sourceName,
            'error_code': photoState.error?.code ?? 'INTERNAL_ERROR',
          },
        ),
      );
    } else {
      widget.analytics.track(
        AnalyticsEvent(
          AnalyticsEvents.photoAnalysisSucceeded,
          properties: {
            'source': sourceName,
            'requires_portion_confirmation':
                photoState.status == HomeStatus.awaitingPortion,
          },
        ),
      );
    }
    await _handlePhotoFlowContinuation();
  }

  Future<void> _handlePhotoFlowContinuation() async {
    if (!mounted) return;
    if (widget.controller.state.status == HomeStatus.awaitingPortion) {
      await _showPortionBottomSheet();
    }
  }

  Future<_AddAction?> _showAddActionSheet() {
    return showModalBottomSheet<_AddAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.photoAnalysisAvailable) ...[
                ListTile(
                  key: const Key('pick-camera'),
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.of(context).pop(_AddAction.camera),
                ),
                ListTile(
                  key: const Key('pick-gallery'),
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(context).pop(_AddAction.gallery),
                ),
              ] else
                const ListTile(
                  key: Key('photo-analysis-unavailable'),
                  leading: Icon(Icons.info_outline),
                  title: Text('Photo analysis is unavailable'),
                  subtitle: Text(
                    'This build is not configured for it. You can still add meals manually.',
                  ),
                ),
              ListTile(
                key: const Key('add-manual'),
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Add manually'),
                onTap: () => Navigator.of(context).pop(_AddAction.manual),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showManualMealSheet({_MealEntry? editingMeal}) async {
    final nameCtrl = TextEditingController(text: editingMeal?.name ?? '');
    final kcalCtrl = TextEditingController(
      text: editingMeal == null ? '' : editingMeal.kcal.toStringAsFixed(1),
    );
    final gramsCtrl = TextEditingController(
      text: editingMeal?.portionG == null
          ? ''
          : editingMeal!.portionG!.toStringAsFixed(1),
    );
    final proteinCtrl = TextEditingController(
      text: editingMeal == null ? '' : editingMeal.proteinG.toStringAsFixed(1),
    );
    final fatCtrl = TextEditingController(
      text: editingMeal == null ? '' : editingMeal.fatG.toStringAsFixed(1),
    );
    final carbsCtrl = TextEditingController(
      text: editingMeal == null ? '' : editingMeal.carbsG.toStringAsFixed(1),
    );
    var selectedMealType =
        editingMeal?.userSelectedType ??
        editingMeal?.finalType ??
        classifyMealTypeByTime(DateTime.now());
    var formDraft = _MealFormDraft.fromMeal(editingMeal);
    final initialFormDraft = formDraft;
    final initialMealType = selectedMealType;
    final initialMealName = nameCtrl.text;
    String? formMessage = formDraft.inlineMessage;
    var isApplyingDraft = false;
    final mealEditSource = editingMeal == null ? 'add' : 'edit';

    String numericHint(double? originalValue, String fallback) {
      if (editingMeal == null || originalValue == null) return fallback;
      return _formatMealSheetNumber(originalValue);
    }

    void updateControllerText(TextEditingController controller, String text) {
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }

    void clearNewMealZeroValue(TextEditingController controller) {
      if (editingMeal == null && controller.text == '0.0') {
        updateControllerText(controller, '');
      }
    }

    void syncControllersFromDraft({_MealEditField? preserveField}) {
      if (isApplyingDraft) return;
      isApplyingDraft = true;
      if (preserveField != _MealEditField.calories) {
        updateControllerText(kcalCtrl, formDraft.kcal.toStringAsFixed(1));
      }
      if (preserveField != _MealEditField.weight) {
        updateControllerText(gramsCtrl, formDraft.grams.toStringAsFixed(1));
      }
      if (preserveField != _MealEditField.protein) {
        updateControllerText(
          proteinCtrl,
          formDraft.proteinG.toStringAsFixed(1),
        );
      }
      if (preserveField != _MealEditField.fat) {
        updateControllerText(fatCtrl, formDraft.fatG.toStringAsFixed(1));
      }
      if (preserveField != _MealEditField.carbs) {
        updateControllerText(carbsCtrl, formDraft.carbsG.toStringAsFixed(1));
      }
      isApplyingDraft = false;
    }

    void handleFieldChanged(
      _MealEditField field,
      String rawValue,
      StateSetter setSheetState,
    ) {
      if (isApplyingDraft) return;
      final parsedValue = _parseNonNegative(rawValue);
      if (parsedValue == null) {
        setSheetState(() {
          if (formDraft.inlineMessage == null) {
            formMessage = null;
          }
        });
        return;
      }

      formDraft = formDraft.applyUserEdit(field, parsedValue);
      syncControllersFromDraft(preserveField: field);
      setSheetState(() {
        formMessage = formDraft.inlineMessage;
      });
    }

    void unlockField(_MealEditField field, StateSetter setSheetState) {
      formDraft = formDraft.unlockField(field);
      syncControllersFromDraft();
      _trackMealEditEvent('meal_edit_unlock_field', {
        'source': mealEditSource,
        'field': field.name,
        'locked_fields_count': formDraft.lockedFields.length,
        'manually_edited_macro_count':
            formDraft.manuallyEditedMacroFields.length,
        'has_conflict': formDraft.errorMessage != null,
      });
      setSheetState(() {
        formMessage = formDraft.inlineMessage;
      });
    }

    void lockField(_MealEditField field, StateSetter setSheetState) {
      if (formDraft.isLocked(field)) return;
      formDraft = formDraft.lockField(field);
      syncControllersFromDraft();
      _trackMealEditEvent('meal_edit_lock_field', {
        'source': mealEditSource,
        'field': field.name,
        'locked_fields_count': formDraft.lockedFields.length,
        'manually_edited_macro_count':
            formDraft.manuallyEditedMacroFields.length,
        'has_conflict': formDraft.errorMessage != null,
      });
      setSheetState(() {
        formMessage = formDraft.inlineMessage;
      });
    }

    void resetAutoCalc(StateSetter setSheetState) {
      formDraft = formDraft.resetAutoCalc();
      syncControllersFromDraft();
      _trackMealEditEvent('meal_edit_reset_auto_calc', {
        'source': mealEditSource,
        'locked_fields_count': formDraft.lockedFields.length,
        'manually_edited_macro_count':
            formDraft.manuallyEditedMacroFields.length,
        'has_conflict': formDraft.errorMessage != null,
      });
      setSheetState(() {
        formMessage = formDraft.inlineMessage;
      });
    }

    bool hasSessionRestoreChanges() {
      return !formDraft.isSameSessionState(initialFormDraft) ||
          selectedMealType != initialMealType ||
          nameCtrl.text != initialMealName;
    }

    void restoreSessionStart(StateSetter setSheetState) {
      formDraft = initialFormDraft;
      selectedMealType = initialMealType;
      updateControllerText(nameCtrl, initialMealName);
      syncControllersFromDraft();
      _trackMealEditEvent('meal_edit_restore_session_start', {
        'source': mealEditSource,
        'locked_fields_count': formDraft.lockedFields.length,
        'manually_edited_macro_count':
            formDraft.manuallyEditedMacroFields.length,
        'has_conflict': formDraft.errorMessage != null,
      });
      setSheetState(() {
        formMessage = formDraft.inlineMessage;
      });
    }

    Future<String?> showLockedCaloriesConfirm(
      _MealLockedCaloriesAutoAdjustProposal proposal,
    ) async {
      final action = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomSafeArea = MediaQuery.paddingOf(sheetContext).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, bottomSafeArea + 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keep calories fixed?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We’ll keep calories fixed and rebalance the other macros.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Updated fields: ${proposal.adjustedFieldLabels.join(', ')}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('locked-calories-save-as-entered'),
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop('save_as_entered'),
                            child: const Text('Save as entered'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            key: const Key('locked-calories-auto-save'),
                            onPressed: () =>
                                Navigator.of(sheetContext).pop('auto_adjust'),
                            child: const Text('Auto-adjust & save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      return action;
    }

    void persistMealDraft(
      _MealFormDraft draftToSave,
      StateSetter setSheetState,
    ) {
      final meal = _buildManualMeal(
        original: editingMeal,
        name: nameCtrl.text,
        draft: draftToSave,
        mealType: selectedMealType,
      );
      if (meal == null) {
        setSheetState(
          () => formMessage =
              'Check fields: name is required and numbers must be >= 0.',
        );
        return;
      }

      setState(() {
        final idx = meals.indexWhere((m) => m.requestId == meal.requestId);
        if (idx >= 0) {
          meals[idx] = meal;
        } else {
          meals.insert(0, meal);
        }
        _rebuildSessionsForDay(meal.day, notify: false);
      });
      _notifyMealsChanged();
      if (editingMeal != null) {
        widget.analytics.track(
          AnalyticsEvent(
            AnalyticsEvents.mealEdited,
            properties: {'source': editingMeal.origin.name},
          ),
        );
      }
      Navigator.of(context).pop();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottomInset = max(
          media.viewInsets.bottom,
          media.padding.bottom + 16,
        );

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height: min(
                    media.size.height * 0.9,
                    media.size.height - bottomInset - 8,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                        child: Row(
                          children: [
                            Text(
                              editingMeal == null ? 'Add Meal' : 'Edit Meal',
                              style: const TextStyle(
                                fontSize: 34 / 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sheetInput(
                                controller: nameCtrl,
                                label: 'Meal Name',
                                hint: 'e.g. Caesar Salad',
                              ),
                              const SizedBox(height: 12),
                              _sheetInput(
                                controller: kcalCtrl,
                                fieldKeySuffix: 'calories',
                                label: 'Calories',
                                hint: numericHint(editingMeal?.kcal, '0'),
                                numeric: true,
                                onTapDown: () =>
                                    clearNewMealZeroValue(kcalCtrl),
                                isLocked: formDraft.isLocked(
                                  _MealEditField.calories,
                                ),
                                onDoubleTapLock: () => lockField(
                                  _MealEditField.calories,
                                  setSheetState,
                                ),
                                onUnlock: () => unlockField(
                                  _MealEditField.calories,
                                  setSheetState,
                                ),
                                onChanged: (value) => handleFieldChanged(
                                  _MealEditField.calories,
                                  value,
                                  setSheetState,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _sheetInput(
                                      controller: gramsCtrl,
                                      fieldKeySuffix: 'weight',
                                      label: 'Weight (g)',
                                      hint: numericHint(
                                        editingMeal?.portionG,
                                        '250',
                                      ),
                                      numeric: true,
                                      onTapDown: () =>
                                          clearNewMealZeroValue(gramsCtrl),
                                      isLocked: formDraft.isLocked(
                                        _MealEditField.weight,
                                      ),
                                      onDoubleTapLock: () => lockField(
                                        _MealEditField.weight,
                                        setSheetState,
                                      ),
                                      onUnlock: () => unlockField(
                                        _MealEditField.weight,
                                        setSheetState,
                                      ),
                                      onChanged: (value) => handleFieldChanged(
                                        _MealEditField.weight,
                                        value,
                                        setSheetState,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _sheetInput(
                                      controller: proteinCtrl,
                                      fieldKeySuffix: 'protein',
                                      label: 'Protein (g)',
                                      hint: numericHint(
                                        editingMeal?.proteinG,
                                        '20',
                                      ),
                                      numeric: true,
                                      onTapDown: () =>
                                          clearNewMealZeroValue(proteinCtrl),
                                      isLocked: formDraft.isLocked(
                                        _MealEditField.protein,
                                      ),
                                      onDoubleTapLock: () => lockField(
                                        _MealEditField.protein,
                                        setSheetState,
                                      ),
                                      onUnlock: () => unlockField(
                                        _MealEditField.protein,
                                        setSheetState,
                                      ),
                                      onChanged: (value) => handleFieldChanged(
                                        _MealEditField.protein,
                                        value,
                                        setSheetState,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _sheetInput(
                                      controller: fatCtrl,
                                      fieldKeySuffix: 'fat',
                                      label: 'Fat (g)',
                                      hint: numericHint(editingMeal?.fatG, '8'),
                                      numeric: true,
                                      onTapDown: () =>
                                          clearNewMealZeroValue(fatCtrl),
                                      isLocked: formDraft.isLocked(
                                        _MealEditField.fat,
                                      ),
                                      onDoubleTapLock: () => lockField(
                                        _MealEditField.fat,
                                        setSheetState,
                                      ),
                                      onUnlock: () => unlockField(
                                        _MealEditField.fat,
                                        setSheetState,
                                      ),
                                      onChanged: (value) => handleFieldChanged(
                                        _MealEditField.fat,
                                        value,
                                        setSheetState,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _sheetInput(
                                      controller: carbsCtrl,
                                      fieldKeySuffix: 'carbs',
                                      label: 'Carbs (g)',
                                      hint: numericHint(
                                        editingMeal?.carbsG,
                                        '30',
                                      ),
                                      numeric: true,
                                      onTapDown: () =>
                                          clearNewMealZeroValue(carbsCtrl),
                                      isLocked: formDraft.isLocked(
                                        _MealEditField.carbs,
                                      ),
                                      onDoubleTapLock: () => lockField(
                                        _MealEditField.carbs,
                                        setSheetState,
                                      ),
                                      onUnlock: () => unlockField(
                                        _MealEditField.carbs,
                                        setSheetState,
                                      ),
                                      onChanged: (value) => handleFieldChanged(
                                        _MealEditField.carbs,
                                        value,
                                        setSheetState,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Meal Type',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _mealTypeTile(
                                      key: const Key('meal-type-breakfast'),
                                      mealType: MealType.breakfast,
                                      selected:
                                          selectedMealType ==
                                          MealType.breakfast,
                                      onTap: () => setSheetState(
                                        () => selectedMealType =
                                            MealType.breakfast,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _mealTypeTile(
                                      key: const Key('meal-type-lunch'),
                                      mealType: MealType.lunch,
                                      selected:
                                          selectedMealType == MealType.lunch,
                                      onTap: () => setSheetState(
                                        () => selectedMealType = MealType.lunch,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _mealTypeTile(
                                      key: const Key('meal-type-dinner'),
                                      mealType: MealType.dinner,
                                      selected:
                                          selectedMealType == MealType.dinner,
                                      onTap: () => setSheetState(
                                        () =>
                                            selectedMealType = MealType.dinner,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _mealTypeTile(
                                      key: const Key('meal-type-snack'),
                                      mealType: MealType.snack,
                                      selected:
                                          selectedMealType == MealType.snack,
                                      onTap: () => setSheetState(
                                        () => selectedMealType = MealType.snack,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (formDraft.shouldShowResetAutoCalc ||
                                  hasSessionRestoreChanges()) ...[
                                const SizedBox(height: 12),
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (formDraft.shouldShowResetAutoCalc)
                                        Expanded(
                                          child: TextButton.icon(
                                            key: const Key('reset-auto-calc'),
                                            onPressed: () =>
                                                resetAutoCalc(setSheetState),
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Reset auto‑calc',
                                              textAlign: TextAlign.center,
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFFB45309,
                                              ),
                                              backgroundColor: const Color(
                                                0xFFFFF7D6,
                                              ),
                                              minimumSize: const Size(0, 60),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (formDraft.shouldShowResetAutoCalc &&
                                          hasSessionRestoreChanges())
                                        const SizedBox(width: 10),
                                      if (hasSessionRestoreChanges())
                                        Expanded(
                                          child: TextButton.icon(
                                            key: const Key(
                                              'restore-session-start',
                                            ),
                                            onPressed: () =>
                                                restoreSessionStart(
                                                  setSheetState,
                                                ),
                                            icon: const Icon(
                                              Icons.undo_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Restore previous values',
                                              textAlign: TextAlign.center,
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFF7C3AED,
                                              ),
                                              backgroundColor: const Color(
                                                0xFFF5F3FF,
                                              ),
                                              minimumSize: const Size(0, 60),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (formMessage != null) ...[
                              Container(
                                key: const Key('meal-form-message'),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7D6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFACC15),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Text(
                                  formMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              key: const Key('manual-meal-submit'),
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7E9EF1),
                                  minimumSize: const Size.fromHeight(58),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () async {
                                  final kcalValue = _parseNonNegative(
                                    kcalCtrl.text,
                                  );
                                  final gramsValue = _parseNonNegative(
                                    gramsCtrl.text,
                                  );
                                  final proteinValue = _parseNonNegative(
                                    proteinCtrl.text,
                                  );
                                  final fatValue = _parseNonNegative(
                                    fatCtrl.text,
                                  );
                                  final carbsValue = _parseNonNegative(
                                    carbsCtrl.text,
                                  );
                                  if (nameCtrl.text.trim().isEmpty ||
                                      kcalValue == null ||
                                      gramsValue == null ||
                                      proteinValue == null ||
                                      fatValue == null ||
                                      carbsValue == null ||
                                      gramsValue <= 0) {
                                    setSheetState(
                                      () => formMessage =
                                          'Check fields: name is required and numbers must be >= 0.',
                                    );
                                    return;
                                  }

                                  final autoAdjustProposal = formDraft
                                      .buildAutoAdjustedDraftRespectingAllManualMacroChanges();
                                  if (autoAdjustProposal != null) {
                                    _trackMealEditEvent(
                                      'meal_edit_locked_conflict_prompt_shown',
                                      {
                                        'source': mealEditSource,
                                        'locked_fields_count':
                                            formDraft.lockedFields.length,
                                        'manually_edited_macro_count': formDraft
                                            .manuallyEditedMacroFields
                                            .length,
                                        'adjusted_fields': autoAdjustProposal
                                            .adjustedFields
                                            .map((field) => field.name)
                                            .toList(growable: false),
                                        'has_conflict':
                                            formDraft.errorMessage != null,
                                      },
                                    );
                                    final confirmAction =
                                        await showLockedCaloriesConfirm(
                                          autoAdjustProposal,
                                        );
                                    if (confirmAction == 'save_as_entered') {
                                      _trackMealEditEvent(
                                        'meal_edit_locked_conflict_save_as_entered',
                                        {
                                          'source': mealEditSource,
                                          'locked_fields_count':
                                              formDraft.lockedFields.length,
                                          'manually_edited_macro_count':
                                              formDraft
                                                  .manuallyEditedMacroFields
                                                  .length,
                                          'adjusted_fields': autoAdjustProposal
                                              .adjustedFields
                                              .map((field) => field.name)
                                              .toList(growable: false),
                                          'has_conflict':
                                              formDraft.errorMessage != null,
                                        },
                                      );
                                    } else if (confirmAction != 'auto_adjust') {
                                      return;
                                    } else {
                                      formDraft =
                                          autoAdjustProposal.adjustedDraft;
                                      syncControllersFromDraft();
                                      _trackMealEditEvent(
                                        'meal_edit_locked_conflict_auto_adjust_saved',
                                        {
                                          'source': mealEditSource,
                                          'locked_fields_count':
                                              formDraft.lockedFields.length,
                                          'manually_edited_macro_count':
                                              formDraft
                                                  .manuallyEditedMacroFields
                                                  .length,
                                          'adjusted_fields': autoAdjustProposal
                                              .adjustedFields
                                              .map((field) => field.name)
                                              .toList(growable: false),
                                          'has_conflict':
                                              formDraft.errorMessage != null,
                                        },
                                      );
                                      setSheetState(() {
                                        formMessage = formDraft.inlineMessage;
                                      });
                                    }
                                  } else if (formDraft
                                      .hasCaloriesLockedConflict) {
                                    _trackMealEditEvent(
                                      'meal_edit_locked_conflict_unresolvable',
                                      {
                                        'source': mealEditSource,
                                        'locked_fields_count':
                                            formDraft.lockedFields.length,
                                        'manually_edited_macro_count': formDraft
                                            .manuallyEditedMacroFields
                                            .length,
                                        'has_conflict':
                                            formDraft.errorMessage != null,
                                      },
                                    );
                                    setSheetState(() {
                                      formMessage = formDraft.inlineMessage;
                                    });
                                  }
                                  persistMealDraft(formDraft, setSheetState);
                                },
                                child: Text(
                                  editingMeal == null
                                      ? 'Add Meal'
                                      : 'Save Changes',
                                  style: const TextStyle(
                                    fontSize: 22 / 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _sheetInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? fieldKeySuffix,
    bool numeric = false,
    bool isLocked = false,
    VoidCallback? onDoubleTapLock,
    VoidCallback? onUnlock,
    ValueChanged<String>? onChanged,
    VoidCallback? onTapDown,
  }) {
    final borderColor = isLocked
        ? const Color(0xFFFACC15)
        : const Color(0x00000000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onDoubleTap: isLocked ? null : onDoubleTapLock,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Listener(
                onPointerDown: onTapDown == null ? null : (_) => onTapDown(),
                child: Container(
                  key: fieldKeySuffix == null
                      ? null
                      : Key('meal-input-$fieldKeySuffix'),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: isLocked ? 2 : 0,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    keyboardType: numeric
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(
                      hintText: hint,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.fromLTRB(
                        14,
                        14,
                        isLocked ? 40 : 14,
                        14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isLocked
                              ? const Color(0xFFFACC15)
                              : const Color(0xFF7E9EF1),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isLocked && onUnlock != null)
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('meal-lock-${fieldKeySuffix ?? label}'),
                      onTap: onUnlock,
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFACC15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Color(0xFF7C2D12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mealTypeTile({
    required Key key,
    required MealType mealType,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 88,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFD5DAE5),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mealTypeIcon(mealType),
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF8E97A8),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              mealTypeLabel(mealType),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MealEntry? _buildManualMeal({
    required _MealEntry? original,
    required String name,
    required _MealFormDraft draft,
    required MealType mealType,
  }) {
    final mealName = name.trim();
    if (mealName.isEmpty || draft.grams <= 0) {
      return null;
    }

    if (original != null) {
      final per100Factor = 100.0 / draft.grams;

      return _MealEntry(
        requestId: original.requestId,
        origin: original.origin,
        name: mealName,
        day: original.day,
        timestamp: original.timestamp,
        kcal: draft.kcal,
        proteinG: draft.proteinG,
        carbsG: draft.carbsG,
        fatG: draft.fatG,
        portionG: draft.grams,
        confidence: original.confidence,
        per100Kcal: draft.kcal * per100Factor,
        per100ProteinG: draft.proteinG * per100Factor,
        per100CarbsG: draft.carbsG * per100Factor,
        per100FatG: draft.fatG * per100Factor,
        userSelectedType: mealType,
        sessionId: original.sessionId,
        autoDetectedType: original.autoDetectedType,
        autoDetectedTier: original.autoDetectedTier,
        finalType: mealType,
        finalTier: original.finalTier,
      );
    }

    final factor = 100.0 / draft.grams;
    final now = DateTime.now();
    final entryTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    return _MealEntry(
      requestId: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      origin: MealOrigin.manual,
      name: mealName,
      day: _selectedDate,
      timestamp: entryTimestamp,
      kcal: draft.kcal,
      proteinG: draft.proteinG,
      carbsG: draft.carbsG,
      fatG: draft.fatG,
      portionG: draft.grams,
      confidence: 1.0,
      per100Kcal: draft.kcal * factor,
      per100ProteinG: draft.proteinG * factor,
      per100CarbsG: draft.carbsG * factor,
      per100FatG: draft.fatG * factor,
      userSelectedType: mealType,
      sessionId: '',
      autoDetectedType: MealType.snack,
      autoDetectedTier: MealSessionTier.extra,
      finalType: mealType,
      finalTier: MealSessionTier.extra,
    );
  }

  double? _parseNonNegative(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  String _formatMealSheetNumber(double value) {
    if ((value - value.roundToDouble()).abs() < 0.0001) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Future<void> _showPortionBottomSheet() async {
    final response = widget.controller.state.response;
    if (response == null) return;

    final aiEstimate = response.meta.estimatedPortionG;
    final inputController = TextEditingController(
      text: (aiEstimate ?? 250).toStringAsFixed(0),
    );
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottomInset = max(
          media.viewInsets.bottom,
          media.padding.bottom + 16,
        );

        return AnimatedPadding(
          key: const Key('portion-sheet'),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final isLoading =
                  widget.controller.state.status ==
                  HomeStatus.confirmingPortion;
              return Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirm portion',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter grams (1-2000) for accurate calories and macros.',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      aiEstimate == null
                          ? 'AI estimate is unavailable.'
                          : 'AI estimate: ${aiEstimate.toStringAsFixed(0)} g',
                      key: const Key('portion-ai-estimate'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('portion-input'),
                      controller: inputController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Grams',
                        errorText: localError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('portion-confirm'),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final validation =
                                    PhotoFoodController.validatePortionInput(
                                      inputController.text,
                                    );
                                if (validation != null) {
                                  setModalState(() => localError = validation);
                                  return;
                                }
                                final grams = double.parse(
                                  inputController.text.trim().replaceAll(
                                    ',',
                                    '.',
                                  ),
                                );
                                final ok = await widget.controller
                                    .confirmPortion(grams);
                                if (!context.mounted) return;
                                if (ok) Navigator.of(context).pop();
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirm portion'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const Key('portion-use-ai-estimate'),
                        onPressed: isLoading || aiEstimate == null
                            ? null
                            : () async {
                                final ok = await widget.controller
                                    .confirmPortionWithAiEstimate();
                                if (!context.mounted) return;
                                if (ok) Navigator.of(context).pop();
                              },
                        child: const Text('Not sure, use AI estimate'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<PhotoClarificationInput?> _showClarificationBottomSheet() async {
    PhotoClarificationInput? result;
    var skipTracked = false;
    DishCategory? selectedCategory;
    final selectedHints = <String>{};

    _trackClarificationEvent('prompt_shown', <String, Object?>{
      'categories': _clarificationOptions
          .map((option) => option.category.apiValue)
          .toList(growable: false),
    });

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final bottomInset = max(
          media.viewInsets.bottom,
          media.padding.bottom + 20,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            _ClarificationOption? activeOption;
            for (final option in _clarificationOptions) {
              if (option.category == selectedCategory) {
                activeOption = option;
                break;
              }
            }

            return SingleChildScrollView(
              key: const Key('clarification-sheet'),
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add a quick hint',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Best for soups, salads, pasta, and mixed dishes.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _clarificationOptions
                        .map(
                          (option) => ChoiceChip(
                            key: Key(
                              'clarification-category-${option.category.apiValue}',
                            ),
                            label: Text(option.label),
                            selected: selectedCategory == option.category,
                            onSelected: (selected) {
                              if (selected && option.hints.isEmpty) {
                                result = PhotoClarificationInput(
                                  dishCategory: option.category,
                                );
                                _trackClarificationEvent(
                                  'submitted',
                                  <String, Object?>{
                                    'category': option.category.apiValue,
                                    'hintCount': 0,
                                  },
                                );
                                Navigator.of(context).pop();
                                return;
                              }
                              setModalState(() {
                                selectedCategory = selected
                                    ? option.category
                                    : null;
                                selectedHints.clear();
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (activeOption != null &&
                      activeOption.hints.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Optional hints',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activeOption.hints
                          .map(
                            (hint) => FilterChip(
                              key: Key('clarification-hint-$hint'),
                              label: Text(_clarificationHintLabel(hint)),
                              selected: selectedHints.contains(hint),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    selectedHints.add(hint);
                                  } else {
                                    selectedHints.remove(hint);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('clarification-skip'),
                          onPressed: () {
                            skipTracked = true;
                            _trackClarificationEvent('prompt_skipped', {
                              'source': 'button',
                            });
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('clarification-continue'),
                          onPressed: selectedCategory == null
                              ? null
                              : () {
                                  result = PhotoClarificationInput(
                                    dishCategory: selectedCategory,
                                    ingredientHints: selectedHints.toList(
                                      growable: false,
                                    ),
                                  );
                                  _trackClarificationEvent(
                                    'submitted',
                                    <String, Object?>{
                                      'category': selectedCategory!.apiValue,
                                      'hintCount': selectedHints.length,
                                    },
                                  );
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null && !skipTracked) {
      _trackClarificationEvent('prompt_skipped', {'source': 'dismiss'});
    }
    return result;
  }

  void _showMealDetails(_MealEntry meal) {
    if (!widget.showDebugMealDetails) {
      _showManualMealSheet(editingMeal: meal);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Meal type: ${mealTypeLabel(meal.finalType)}'),
                Text(
                  'Confidence: ${(meal.confidence * 100).toStringAsFixed(0)}%',
                ),
                Text('Time: ${_timeLabelFromDateTime(meal.timestamp)}'),
                const SizedBox(height: 12),
                Text('Portion: ${meal.portionG?.toStringAsFixed(0) ?? '-'} g'),
                Text('Calories: ${meal.kcal.toStringAsFixed(1)} kcal'),
                Text('Protein: ${meal.proteinG.toStringAsFixed(1)} g'),
                Text('Fat: ${meal.fatG.toStringAsFixed(1)} g'),
                Text('Carbs: ${meal.carbsG.toStringAsFixed(1)} g'),
                const Divider(height: 24),
                const Text(
                  'Per 100g',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('Kcal: ${meal.per100Kcal.toStringAsFixed(1)}'),
                Text('P: ${meal.per100ProteinG.toStringAsFixed(1)} g'),
                Text('F: ${meal.per100FatG.toStringAsFixed(1)} g'),
                Text('C: ${meal.per100CarbsG.toStringAsFixed(1)} g'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _showManualMealSheet(editingMeal: meal);
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () {
                          setState(() {
                            meals.removeWhere(
                              (m) => m.requestId == meal.requestId,
                            );
                            _rebuildSessionsForDay(meal.day, notify: false);
                          });
                          _notifyMealsChanged();
                          widget.analytics.track(
                            AnalyticsEvent(
                              AnalyticsEvents.mealDeleted,
                              properties: {'source': meal.origin.name},
                            ),
                          );
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _MealEntry? _mealById(String mealId) {
    for (final meal in meals) {
      if (meal.requestId == mealId) {
        return meal;
      }
    }
    return null;
  }

  double _categoryGoalKcal(MealType type, double dailyTarget) {
    switch (type) {
      case MealType.breakfast:
        return dailyTarget * 0.30;
      case MealType.lunch:
        return dailyTarget * 0.40;
      case MealType.dinner:
        return dailyTarget * 0.25;
      case MealType.snack:
        return dailyTarget * 0.05;
    }
  }

  List<_CategorySectionModel> _buildCategorySections(
    List<MealSession> sessions,
    double dailyTarget,
  ) {
    const orderedTypes = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    final grouped = <MealType, List<MealSession>>{
      MealType.breakfast: <MealSession>[],
      MealType.lunch: <MealSession>[],
      MealType.dinner: <MealSession>[],
      MealType.snack: <MealSession>[],
    };

    for (final session in sessions) {
      grouped[session.finalType]!.add(session);
    }

    for (final type in orderedTypes) {
      grouped[type]!.sort((a, b) => b.startTime.compareTo(a.startTime));
    }

    return orderedTypes
        .map((type) {
          final categorySessions = grouped[type]!;
          final mainSessions = <MealSession>[];
          final extraSessions = <MealSession>[];
          final snackSessions = <MealSession>[];

          if (type == MealType.snack) {
            snackSessions.addAll(categorySessions);
          } else {
            for (final session in categorySessions) {
              if (session.finalTier == MealSessionTier.mainMeal) {
                mainSessions.add(session);
              } else {
                extraSessions.add(session);
              }
            }
          }

          return _CategorySectionModel(
            type: type,
            goalKcal: _categoryGoalKcal(type, dailyTarget),
            consumedKcal: categorySessions.fold(
              0.0,
              (sum, session) => sum + session.totalKcal,
            ),
            mainSessions: mainSessions,
            extraSessions: extraSessions,
            snackSessions: snackSessions,
          );
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final daySessions = _selectedSessions;
        final latestMeal = _latestAddedMealForSelectedDay;
        final hasMealsForSelectedDay = daySessions.isNotEmpty;
        final now = _now;

        final consumed = _sumKcal;
        final calorieTarget =
            widget.onboardingResult?.plan.calorieTarget.toDouble() ?? 2000.0;
        final remaining = max(0.0, calorieTarget - consumed);
        final progress = consumed <= 0
            ? 0.0
            : (consumed / calorieTarget).clamp(0.0, 1.0);
        final categorySections = _buildCategorySections(
          daySessions,
          calorieTarget,
        );

        final protein = _sumProtein;
        final carbs = _sumCarbs;
        final fat = _sumFats;
        final proteinTarget =
            widget.onboardingResult?.plan.proteinTargetG.toDouble() ?? 150.0;
        final yesterday = _selectedDate.subtract(const Duration(days: 1));
        final coachContent = _coachEvaluator.evaluate(
          selectedDate: _selectedDate,
          now: now,
          hasMealsForSelectedDay: hasMealsForSelectedDay,
          consumedKcal: consumed,
          consumedProtein: protein,
          calorieTarget: calorieTarget,
          proteinTarget: proteinTarget,
          yesterdayProtein: _proteinForDay(yesterday),
        );

        final isLoading =
            state.status == HomeStatus.pickingImage ||
            state.status == HomeStatus.uploading ||
            state.status == HomeStatus.confirmingPortion;

        return Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(fireCount: daySessions.length),
                    const SizedBox(height: 18),
                    _buildDaysRow(),
                    const SizedBox(height: 18),
                    _buildCaloriesCard(
                      consumed: consumed,
                      remaining: remaining,
                      progress: progress,
                    ),
                    const SizedBox(height: 14),
                    _CoachCard(content: coachContent),
                    const SizedBox(height: 14),
                    _buildMacros(protein: protein, carbs: carbs, fat: fat),
                    if (latestMeal != null) ...[
                      const SizedBox(height: 14),
                      _LatestAddedMealCard(
                        meal: latestMeal,
                        onTap: () => _showMealDetails(latestMeal),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!hasMealsForSelectedDay)
                      const _HistoryEmptyCard()
                    else
                      ...categorySections.map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CategorySectionCard(
                            model: section,
                            expanded: _expandedCategories.contains(
                              section.type,
                            ),
                            onToggle: () {
                              setState(() {
                                if (_expandedCategories.contains(
                                  section.type,
                                )) {
                                  _expandedCategories.remove(section.type);
                                } else {
                                  _expandedCategories.add(section.type);
                                }
                              });
                            },
                            onTapMeal: (mealId) {
                              final meal = _mealById(mealId);
                              if (meal != null) {
                                _showMealDetails(meal);
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x66000000),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader({required int fireCount}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Calories',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1DC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                color: Color(0xFFE38A1F),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                fireCount.toString(),
                style: const TextStyle(
                  color: Color(0xFFB47628),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDaysRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(days.length, (index) {
          final isSelected = index == selectedDay;
          return Padding(
            padding: EdgeInsets.only(right: index == days.length - 1 ? 0 : 10),
            child: GestureDetector(
              key: Key('day-chip-$index'),
              onTap: () => setState(() => selectedDay = index),
              child: Column(
                children: [
                  Text(
                    days[index].weekDay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF2B66F6)
                          : const Color(0xFF6F7282),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2B66F6)
                          : const Color(0xFFECEEF2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      days[index].dayNum,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF34374A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCaloriesCard({
    required double consumed,
    required double remaining,
    required double progress,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B77FF), Color(0xFF8D2EF4)],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberBlock(
                label: 'Consumed',
                main: consumed.toStringAsFixed(0),
                sub: 'kcal',
                alignEnd: false,
                light: true,
              ),
              _NumberBlock(
                label: 'Remaining',
                main: remaining.toStringAsFixed(0),
                sub: 'kcal',
                alignEnd: true,
                light: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0x80FFFFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF0E0F16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacros({
    required double protein,
    required double carbs,
    required double fat,
  }) {
    final targetProtein =
        widget.onboardingResult?.plan.proteinTargetG.toDouble() ?? 150;
    final targetCarbs =
        widget.onboardingResult?.plan.carbsTargetG.toDouble() ?? 200;
    final targetFat = widget.onboardingResult?.plan.fatTargetG.toDouble() ?? 60;

    return Row(
      children: [
        Expanded(
          child: _MacroCard(
            title: 'Protein',
            amount: '${protein.toStringAsFixed(0)}g',
            amountColor: const Color(0xFF2B66F6),
            goal: 'of ${targetProtein.toStringAsFixed(0)}g',
            left:
                '${max(0.0, targetProtein - protein).toStringAsFixed(0)}g left',
            value: (protein / targetProtein).clamp(0.0, 1.0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MacroCard(
            title: 'Carbs',
            amount: '${carbs.toStringAsFixed(0)}g',
            amountColor: const Color(0xFFE5793A),
            goal: 'of ${targetCarbs.toStringAsFixed(0)}g',
            left: '${max(0.0, targetCarbs - carbs).toStringAsFixed(0)}g left',
            value: (carbs / targetCarbs).clamp(0.0, 1.0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MacroCard(
            title: 'Fats',
            amount: '${fat.toStringAsFixed(0)}g',
            amountColor: const Color(0xFF25A55F),
            goal: 'of ${targetFat.toStringAsFixed(0)}g',
            left: '${max(0.0, targetFat - fat).toStringAsFixed(0)}g left',
            value: (fat / targetFat).clamp(0.0, 1.0),
          ),
        ),
      ],
    );
  }
}

enum _AddAction { camera, gallery, manual }

enum MealOrigin { ai, manual }

class _ClarificationOption {
  final DishCategory category;
  final String label;
  final List<String> hints;

  const _ClarificationOption({
    required this.category,
    required this.label,
    required this.hints,
  });
}

const List<_ClarificationOption> _clarificationOptions = [
  _ClarificationOption(
    category: DishCategory.soup,
    label: 'Soup',
    hints: ['chicken', 'meat', 'vegetables', 'beans', 'creamy'],
  ),
  _ClarificationOption(
    category: DishCategory.salad,
    label: 'Salad',
    hints: ['chicken', 'cheese', 'egg', 'dressing', 'avocado'],
  ),
  _ClarificationOption(
    category: DishCategory.bowl,
    label: 'Bowl / Rice dish',
    hints: [],
  ),
  _ClarificationOption(
    category: DishCategory.pasta,
    label: 'Pasta / Noodles',
    hints: ['meat', 'cream_sauce', 'tomato_sauce', 'seafood'],
  ),
  _ClarificationOption(
    category: DishCategory.mixedPlate,
    label: 'Mixed plate',
    hints: [],
  ),
];

String _clarificationHintLabel(String hint) {
  return switch (hint) {
    'meat' => 'Meat',
    'chicken' => 'Chicken',
    'vegetables' => 'Vegetables',
    'beans' => 'Beans',
    'creamy' => 'Creamy',
    'potato' => 'Potato',
    'cheese' => 'Cheese',
    'egg' => 'Egg',
    'avocado' => 'Avocado',
    'croutons' => 'Croutons',
    'dressing' => 'Dressing',
    'beef' => 'Beef',
    'tofu' => 'Tofu',
    'rice' => 'Rice',
    'sauce' => 'Sauce',
    'cream_sauce' => 'Cream sauce',
    'tomato_sauce' => 'Tomato sauce',
    'seafood' => 'Seafood',
    _ => hint,
  };
}

class _MealEntry {
  final String requestId;
  final MealOrigin origin;
  final String name;
  final DateTime day;
  final DateTime timestamp;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? portionG;
  final double confidence;
  final double per100Kcal;
  final double per100ProteinG;
  final double per100CarbsG;
  final double per100FatG;
  final MealType? userSelectedType;
  final MealType autoDetectedType;
  final MealType finalType;
  final MealSessionTier autoDetectedTier;
  final MealSessionTier finalTier;
  final String sessionId;

  const _MealEntry({
    required this.requestId,
    required this.origin,
    required this.name,
    required this.day,
    required this.timestamp,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.portionG,
    required this.confidence,
    required this.per100Kcal,
    required this.per100ProteinG,
    required this.per100CarbsG,
    required this.per100FatG,
    required this.userSelectedType,
    required this.autoDetectedType,
    required this.finalType,
    required this.autoDetectedTier,
    required this.finalTier,
    required this.sessionId,
  });

  String get time => _timeLabelFromDateTime(timestamp);
  MealType get mealType => finalType;
  String get title => mealTypeLabel(finalType);
  IconData get icon => mealTypeIcon(finalType);

  _MealEntry copyWith({
    String? requestId,
    MealOrigin? origin,
    String? name,
    DateTime? day,
    DateTime? timestamp,
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? portionG,
    bool clearPortionG = false,
    double? confidence,
    double? per100Kcal,
    double? per100ProteinG,
    double? per100CarbsG,
    double? per100FatG,
    MealType? userSelectedType,
    bool clearUserSelectedType = false,
    MealType? autoDetectedType,
    MealType? finalType,
    MealSessionTier? autoDetectedTier,
    MealSessionTier? finalTier,
    String? sessionId,
  }) {
    return _MealEntry(
      requestId: requestId ?? this.requestId,
      origin: origin ?? this.origin,
      name: name ?? this.name,
      day: day ?? this.day,
      timestamp: timestamp ?? this.timestamp,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      portionG: clearPortionG ? null : (portionG ?? this.portionG),
      confidence: confidence ?? this.confidence,
      per100Kcal: per100Kcal ?? this.per100Kcal,
      per100ProteinG: per100ProteinG ?? this.per100ProteinG,
      per100CarbsG: per100CarbsG ?? this.per100CarbsG,
      per100FatG: per100FatG ?? this.per100FatG,
      userSelectedType: clearUserSelectedType
          ? null
          : (userSelectedType ?? this.userSelectedType),
      autoDetectedType: autoDetectedType ?? this.autoDetectedType,
      finalType: finalType ?? this.finalType,
      autoDetectedTier: autoDetectedTier ?? this.autoDetectedTier,
      finalTier: finalTier ?? this.finalTier,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'origin': origin.name,
    'name': name,
    'day': day.toIso8601String(),
    'timestamp': timestamp.toIso8601String(),
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'portionG': portionG,
    'confidence': confidence,
    'per100Kcal': per100Kcal,
    'per100ProteinG': per100ProteinG,
    'per100CarbsG': per100CarbsG,
    'per100FatG': per100FatG,
    'userSelectedType': userSelectedType?.name,
    'autoDetectedType': autoDetectedType.name,
    'finalType': finalType.name,
    'autoDetectedTier': autoDetectedTier.name,
    'finalTier': finalTier.name,
    'sessionId': sessionId,
  };

  static _MealEntry? fromJson(Map<String, dynamic> json) {
    final origin = _enumByNameMain(
      MealOrigin.values,
      json['origin'] as String?,
    );
    if (origin == null) return null;

    final legacyMealType = _enumByNameMain(
      MealType.values,
      json['mealType'] as String?,
    );
    final userSelectedType = _enumByNameMain(
      MealType.values,
      json['userSelectedType'] as String?,
    );
    final autoDetectedType =
        _enumByNameMain(MealType.values, json['autoDetectedType'] as String?) ??
        legacyMealType ??
        MealType.snack;
    final finalType =
        _enumByNameMain(MealType.values, json['finalType'] as String?) ??
        legacyMealType ??
        autoDetectedType;
    final autoDetectedTier =
        _enumByNameMain(
          MealSessionTier.values,
          json['autoDetectedTier'] as String?,
        ) ??
        MealSessionTier.extra;
    final finalTier =
        _enumByNameMain(MealSessionTier.values, json['finalTier'] as String?) ??
        autoDetectedTier;
    final day =
        DateTime.tryParse((json['day'] as String?) ?? '') ?? DateTime.now();
    final parsedTimestamp = DateTime.tryParse(
      (json['timestamp'] as String?) ?? '',
    );
    final legacyTime = (json['time'] as String?) ?? '';
    final timestamp =
        parsedTimestamp ?? _timestampFromDayAndTime(day, legacyTime);

    return _MealEntry(
      requestId: (json['requestId'] as String?) ?? '',
      origin: origin,
      name: (json['name'] as String?) ?? '',
      day: _dateOnly(day),
      timestamp: timestamp,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
      portionG: (json['portionG'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      per100Kcal: (json['per100Kcal'] as num?)?.toDouble() ?? 0,
      per100ProteinG: (json['per100ProteinG'] as num?)?.toDouble() ?? 0,
      per100CarbsG: (json['per100CarbsG'] as num?)?.toDouble() ?? 0,
      per100FatG: (json['per100FatG'] as num?)?.toDouble() ?? 0,
      userSelectedType: userSelectedType,
      autoDetectedType: autoDetectedType,
      finalType: finalType,
      autoDetectedTier: autoDetectedTier,
      finalTier: finalTier,
      sessionId: (json['sessionId'] as String?) ?? '',
    );
  }
}

Map<String, dynamic> _encodeOnboardingResult(OnboardingResult result) {
  return {
    'goalType': result.goalType.name,
    'sex': result.sex.name,
    'age': result.age,
    'heightCm': result.heightCm,
    'weightKg': result.weightKg,
    'activityLevel': result.activityLevel.name,
    'targetPace': result.targetPace.name,
    'macroProfile': result.macroProfile.name,
    'plan': {
      'calorieTarget': result.plan.calorieTarget,
      'proteinTargetG': result.plan.proteinTargetG,
      'fatTargetG': result.plan.fatTargetG,
      'carbsTargetG': result.plan.carbsTargetG,
    },
  };
}

@visibleForTesting
OnboardingResult? decodeOnboardingResultForTest(String? raw) =>
    _decodeOnboardingResult(raw);

OnboardingResult? _decodeOnboardingResult(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    final goalType =
        _enumByNameMain(GoalType.values, json['goalType'] as String?) ??
        GoalType.maintain;
    final sex =
        _enumByNameMain(SexType.values, json['sex'] as String?) ?? SexType.male;
    final activityLevel =
        _enumByNameMain(
          ActivityLevel.values,
          json['activityLevel'] as String?,
        ) ??
        ActivityLevel.moderatelyActive;
    final fallbackPace = switch (goalType) {
      GoalType.loseWeight => TargetPace.balanced,
      GoalType.gainWeight => TargetPace.leanBulk,
      GoalType.maintain || GoalType.trackOnly => TargetPace.maintain,
    };
    final targetPace =
        _enumByNameMain(TargetPace.values, json['targetPace'] as String?) ??
        fallbackPace;
    final macroProfile =
        _enumByNameMain(MacroProfile.values, json['macroProfile'] as String?) ??
        MacroProfile.balanced;
    final age = (json['age'] as num?)?.toInt() ?? 30;
    final heightCm = (json['heightCm'] as num?)?.toDouble() ?? 170;
    final weightKg = (json['weightKg'] as num?)?.toDouble() ?? 70;
    final planJson = json['plan'] as Map<String, dynamic>?;
    final fallbackPlan = calculateNutritionPlan(
      goalType: goalType,
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      pace: targetPace,
      macroProfile: macroProfile,
    );
    final plan = planJson == null
        ? fallbackPlan
        : NutritionPlan(
            calorieTarget:
                (planJson['calorieTarget'] as num?)?.toInt() ??
                fallbackPlan.calorieTarget,
            proteinTargetG:
                (planJson['proteinTargetG'] as num?)?.toInt() ??
                fallbackPlan.proteinTargetG,
            fatTargetG:
                (planJson['fatTargetG'] as num?)?.toInt() ??
                fallbackPlan.fatTargetG,
            carbsTargetG:
                (planJson['carbsTargetG'] as num?)?.toInt() ??
                fallbackPlan.carbsTargetG,
          );
    return OnboardingResult(
      goalType: goalType,
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      targetPace: targetPace,
      macroProfile: macroProfile,
      plan: plan,
    );
  } catch (_) {
    return null;
  }
}

OnboardingDraft? _decodeOnboardingDraft(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    return OnboardingDraft.fromJson(json);
  } catch (_) {
    return null;
  }
}

List<_MealEntry> _decodeMeals(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final json = jsonDecode(raw);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(_MealEntry.fromJson)
        .whereType<_MealEntry>()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

T? _enumByNameMain<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

class _DayItem {
  final String weekDay;
  final String dayNum;
  final DateTime date;

  const _DayItem({
    required this.weekDay,
    required this.dayNum,
    required this.date,
  });
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'MON';
    case DateTime.tuesday:
      return 'TUE';
    case DateTime.wednesday:
      return 'WED';
    case DateTime.thursday:
      return 'THU';
    case DateTime.friday:
      return 'FRI';
    case DateTime.saturday:
      return 'SAT';
    default:
      return 'SUN';
  }
}

String _timeLabelFromDateTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

DateTime _timestampFromDayAndTime(DateTime day, String timeLabel) {
  final parts = timeLabel.split(':');
  if (parts.length == 2) {
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours != null &&
        minutes != null &&
        hours >= 0 &&
        hours < 24 &&
        minutes >= 0 &&
        minutes < 60) {
      return DateTime(day.year, day.month, day.day, hours, minutes);
    }
  }
  return day;
}

class _NumberBlock extends StatelessWidget {
  final String label;
  final String main;
  final String sub;
  final bool alignEnd;
  final bool light;

  const _NumberBlock({
    required this.label,
    required this.main,
    required this.sub,
    required this.alignEnd,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : const Color(0xFF111322);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          main,
          style: TextStyle(
            color: color,
            fontSize: 42,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            color: color.withValues(alpha: 0.95),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  final CoachCardContent content;

  const _CoachCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('coach-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  content.accentColor.withValues(alpha: 0.18),
                  content.accentColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: content.accentColor.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(content.icon, color: content.accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              key: Key('coach-card-${content.state.name}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: content.accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Today\'s tip',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: content.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content.primary,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content.secondary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color amountColor;
  final String goal;
  final String left;
  final double value;

  const _MacroCard({
    required this.title,
    required this.amount,
    required this.amountColor,
    required this.goal,
    required this.left,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          Text(
            goal,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: const Color(0xFFD7D9DE),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF111322),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            left,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
        ],
      ),
    );
  }
}

class _CategorySectionModel {
  final MealType type;
  final double goalKcal;
  final double consumedKcal;
  final List<MealSession> mainSessions;
  final List<MealSession> extraSessions;
  final List<MealSession> snackSessions;

  const _CategorySectionModel({
    required this.type,
    required this.goalKcal,
    required this.consumedKcal,
    required this.mainSessions,
    required this.extraSessions,
    required this.snackSessions,
  });
}

class _LatestAddedMealCard extends StatelessWidget {
  final _MealEntry? meal;
  final VoidCallback? onTap;

  const _LatestAddedMealCard({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = meal == null
        ? const Column(
            key: Key('latest-added-empty'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latest Added',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              SizedBox(height: 4),
              Text(
                'No meals for this day yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Add a meal to see it here.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            ],
          )
        : Column(
            key: const Key('latest-added-filled'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Latest Added',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 4),
              Text(
                meal!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    mealTypeLabel(meal!.finalType),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _timeLabelFromDateTime(meal!.timestamp),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${meal!.kcal.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          );

    return InkWell(
      key: const Key('latest-added-card'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D111827),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('history-empty-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F37), Color(0xFF1E2229)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4B5563), width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6B7280)),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing logged yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your meals for this day will appear here after the first added dish.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySectionCard extends StatelessWidget {
  final _CategorySectionModel model;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onTapMeal;

  const _CategorySectionCard({
    required this.model,
    required this.expanded,
    required this.onToggle,
    required this.onTapMeal,
  });

  String _typeKey(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snacks';
    }
  }

  Widget _buildSessionList(List<MealSession> sessions) {
    return Column(
      children: List.generate(sessions.length, (index) {
        final session = sessions[index];
        return Container(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : const Border(top: BorderSide(color: Color(0xFF4B5563))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_timeLabelFromDateTime(session.startTime)}-${_timeLabelFromDateTime(session.endTime)} • ${session.totalKcal.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ...session.entries.map(
                (entry) => InkWell(
                  key: Key('category-entry-${entry.id}'),
                  onTap: () => onTapMeal(entry.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeLabelFromDateTime(entry.timestamp),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.kcal.toStringAsFixed(0)} kcal',
                          style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keySuffix = _typeKey(model.type);
    return Container(
      key: Key('category-card-$keySuffix'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2F37), Color(0xFF1E2229)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4B5563), width: 1.1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF6B7280)),
                    ),
                    child: Icon(
                      mealTypeIcon(model.type),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              model.type == MealType.snack
                                  ? 'Snacks'
                                  : mealTypeLabel(model.type),
                              style: const TextStyle(
                                fontSize: 31 / 1.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              expanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.arrow_forward,
                              color: const Color(0xFFD1D5DB),
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${model.consumedKcal.toStringAsFixed(0)} / ${model.goalKcal.toStringAsFixed(0)} Cal',
                          key: Key('category-kcal-$keySuffix'),
                          style: const TextStyle(
                            fontSize: 17 / 1.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              key: Key('category-content-$keySuffix'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child:
                  (model.mainSessions.isEmpty &&
                      model.extraSessions.isEmpty &&
                      model.snackSessions.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'No sessions yet',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (model.type == MealType.snack) ...[
                          _buildSessionList(model.snackSessions),
                        ] else ...[
                          if (model.mainSessions.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(
                                'Main meal',
                                key: Key('main-meal-section-title'),
                                style: TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _buildSessionList(model.mainSessions),
                          ],
                          if (model.extraSessions.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 6, bottom: 4),
                              child: Text(
                                'Extras',
                                key: Key('extras-section-title'),
                                style: TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _buildSessionList(model.extraSessions),
                          ],
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2B66F6) : const Color(0xFF8E92A3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
