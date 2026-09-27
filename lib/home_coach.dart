import 'dart:math';

import 'package:flutter/material.dart';

import 'meal_type.dart';

enum CoachCardState {
  emptyDay,
  overTarget,
  lowCaloriesLeft,
  lowProteinToday,
  lowProteinYesterday,
  plentyCaloriesLeft,
  strongProteinProgress,
  onTrack,
}

class CoachCardContent {
  final CoachCardState state;
  final String primary;
  final String secondary;
  final IconData icon;
  final Color accentColor;

  const CoachCardContent({
    required this.state,
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.accentColor,
  });
}

class HomeCoachEvaluator {
  const HomeCoachEvaluator();

  CoachCardContent evaluate({
    required DateTime selectedDate,
    required DateTime now,
    required bool hasMealsForSelectedDay,
    required double consumedKcal,
    required double consumedProtein,
    required double calorieTarget,
    required double proteinTarget,
    required double yesterdayProtein,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isToday = selectedDay == today;
    final remainingCalories = max(0.0, calorieTarget - consumedKcal);
    final proteinDeficitYesterday = max(0.0, proteinTarget - yesterdayProtein);
    final mealType = _mealContext(now);
    final proteinProgressGap =
        _expectedProteinByNow(now, proteinTarget) - consumedProtein;

    if (!hasMealsForSelectedDay) {
      return isToday
          ? const CoachCardContent(
              state: CoachCardState.emptyDay,
              primary: 'Start your day',
              secondary: 'Log your first meal to shape the rest of today',
              icon: Icons.wb_sunny_outlined,
              accentColor: Color(0xFF2B66F6),
            )
          : const CoachCardContent(
              state: CoachCardState.emptyDay,
              primary: 'No meals logged',
              secondary: 'Add a meal to see how this day looked',
              icon: Icons.calendar_today_outlined,
              accentColor: Color(0xFF64748B),
            );
    }

    if (consumedKcal > calorieTarget) {
      return const CoachCardContent(
        state: CoachCardState.overTarget,
        primary: 'Keep the bigger picture in mind',
        secondary: 'One day is just part of your progress',
        icon: Icons.favorite_border_rounded,
        accentColor: Color(0xFF64748B),
      );
    }

    if (remainingCalories <= calorieTarget * 0.20) {
      return const CoachCardContent(
        state: CoachCardState.lowCaloriesLeft,
        primary: 'Not much room left today',
        secondary: 'Keep the next meal light',
        icon: Icons.local_fire_department_outlined,
        accentColor: Color(0xFFF97316),
      );
    }

    if (isToday && proteinProgressGap >= 15) {
      return CoachCardContent(
        state: CoachCardState.lowProteinToday,
        primary: 'Protein is running low today',
        secondary: _proteinHintForMealContext(mealType),
        icon: Icons.fitness_center_outlined,
        accentColor: const Color(0xFF16A34A),
      );
    }

    if (isToday && proteinDeficitYesterday >= 15) {
      return CoachCardContent(
        state: CoachCardState.lowProteinYesterday,
        primary: 'Yesterday was light on protein',
        secondary: _proteinRecoveryHintForMealContext(mealType),
        icon: Icons.history_outlined,
        accentColor: const Color(0xFF0891B2),
      );
    }

    if (!isToday) {
      return _historicalSummary(
        consumedKcal: consumedKcal,
        consumedProtein: consumedProtein,
        calorieTarget: calorieTarget,
        proteinTarget: proteinTarget,
      );
    }

    if (_shouldShowPlentyCaloriesLeft(
      mealType: mealType,
      consumedKcal: consumedKcal,
      calorieTarget: calorieTarget,
      remainingCalories: remainingCalories,
    )) {
      return CoachCardContent(
        state: CoachCardState.plentyCaloriesLeft,
        primary: 'You still have room for a full meal',
        secondary: _mainMealHintForMealContext(mealType),
        icon: Icons.lunch_dining_outlined,
        accentColor: const Color(0xFF7C3AED),
      );
    }

    if (_shouldShowStrongProteinProgress(
      now: now,
      consumedProtein: consumedProtein,
      proteinTarget: proteinTarget,
    )) {
      return const CoachCardContent(
        state: CoachCardState.strongProteinProgress,
        primary: 'Protein looks solid so far',
        secondary: 'The next meal can stay balanced instead of protein-heavy',
        icon: Icons.verified_outlined,
        accentColor: Color(0xFF0F766E),
      );
    }

    return CoachCardContent(
      state: CoachCardState.onTrack,
      primary: 'Steady so far',
      secondary: _nextMealKcalHint(mealType, remainingCalories),
      icon: Icons.check_circle_outline,
      accentColor: const Color(0xFF2B66F6),
    );
  }

  bool _shouldShowStrongProteinProgress({
    required DateTime now,
    required double consumedProtein,
    required double proteinTarget,
  }) {
    if (proteinTarget <= 0) {
      return false;
    }

    final expectedProtein = _expectedProteinByNow(now, proteinTarget);
    return consumedProtein >= max(proteinTarget * 0.5, expectedProtein + 10);
  }

  bool _shouldShowPlentyCaloriesLeft({
    required MealType mealType,
    required double consumedKcal,
    required double calorieTarget,
    required double remainingCalories,
  }) {
    if (mealType != MealType.lunch && mealType != MealType.dinner) {
      return false;
    }
    return consumedKcal >= calorieTarget * 0.20 &&
        consumedKcal <= calorieTarget * 0.45 &&
        remainingCalories >= calorieTarget * 0.55;
  }

  double _proteinProgressCheckpoint(DateTime now) {
    final minuteOfDay = (now.hour * 60) + now.minute;
    if (minuteOfDay < 630) {
      return 0.20;
    }
    if (minuteOfDay < 990) {
      return 0.45;
    }
    if (minuteOfDay < 1260) {
      return 0.75;
    }
    return 0.90;
  }

  double _expectedProteinByNow(DateTime now, double proteinTarget) {
    return proteinTarget * _proteinProgressCheckpoint(now);
  }

  MealType _mealContext(DateTime now) {
    return classifyMealTypeByTime(now);
  }

  String _proteinHintForMealContext(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'Try to make breakfast 25-35g protein';
      case MealType.lunch:
        return 'Try to make lunch 30-40g protein';
      case MealType.dinner:
        return 'Try to make dinner 30-40g protein';
      case MealType.snack:
        return 'Try to add a 15-20g protein snack';
    }
  }

  String _proteinRecoveryHintForMealContext(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'Today, try to get 25-35g protein at breakfast';
      case MealType.lunch:
        return 'Today, try to get 30-40g protein at lunch';
      case MealType.dinner:
        return 'Today, try to get 30-40g protein at dinner';
      case MealType.snack:
        return 'Today, try to add a 15-20g protein snack';
    }
  }

  String _mainMealHintForMealContext(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'There is still room to make lunch your main meal';
      case MealType.lunch:
        return 'Don\'t let lunch turn into just a snack';
      case MealType.dinner:
        return 'There is still room for a proper dinner';
      case MealType.snack:
        return 'There is still room for one solid meal';
    }
  }

  CoachCardContent _historicalSummary({
    required double consumedKcal,
    required double consumedProtein,
    required double calorieTarget,
    required double proteinTarget,
  }) {
    if (consumedKcal <= calorieTarget * 0.65) {
      return const CoachCardContent(
        state: CoachCardState.onTrack,
        primary: 'This day ran a bit light',
        secondary: 'You finished well under your calorie target',
        icon: Icons.wb_twilight_outlined,
        accentColor: Color(0xFF64748B),
      );
    }

    if (consumedProtein < proteinTarget * 0.65) {
      return CoachCardContent(
        state: CoachCardState.onTrack,
        primary: 'Protein was the weak spot',
        secondary:
            'You finished the day around $consumedProtein.round()g protein',
        icon: Icons.fitness_center_outlined,
        accentColor: const Color(0xFF16A34A),
      );
    }

    if ((consumedKcal - calorieTarget).abs() <= calorieTarget * 0.10) {
      return const CoachCardContent(
        state: CoachCardState.onTrack,
        primary: 'Calories stayed close to target',
        secondary: 'This day landed in a steady range overall',
        icon: Icons.track_changes_outlined,
        accentColor: Color(0xFF2B66F6),
      );
    }

    if (consumedProtein >= proteinTarget * 0.9) {
      return CoachCardContent(
        state: CoachCardState.onTrack,
        primary: 'Protein held up well',
        secondary:
            'You got in about ${consumedProtein.round()}g across the day',
        icon: Icons.verified_outlined,
        accentColor: const Color(0xFF0F766E),
      );
    }

    return const CoachCardContent(
      state: CoachCardState.onTrack,
      primary: 'This day stayed fairly balanced',
      secondary: 'Calories and protein both landed in a reasonable range',
      icon: Icons.event_note_outlined,
      accentColor: Color(0xFF64748B),
    );
  }

  String _nextMealKcalHint(MealType mealType, double remainingCalories) {
    final range = switch (mealType) {
      MealType.breakfast => (300, 400),
      MealType.lunch => (400, 500),
      MealType.dinner => (400, 500),
      MealType.snack => (150, 250),
    };

    final lowerBound = min(range.$1, remainingCalories.round());
    final upperBound = min(range.$2, remainingCalories.round());

    if (upperBound <= 0) {
      return 'Keep your next meal light';
    }

    if (lowerBound >= upperBound) {
      return 'Keep your next meal around $upperBound kcal';
    }

    return 'Keep your next meal around $lowerBound-$upperBound kcal';
  }
}
