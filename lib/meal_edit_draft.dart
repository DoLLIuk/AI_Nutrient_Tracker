part of 'main.dart';

enum _MealEditField { weight, calories, protein, fat, carbs }

class _MealLockedCaloriesAutoAdjustProposal {
  final _MealFormDraft adjustedDraft;
  final List<_MealEditField> adjustedFields;

  const _MealLockedCaloriesAutoAdjustProposal({
    required this.adjustedDraft,
    required this.adjustedFields,
  });

  List<String> get adjustedFieldLabels => adjustedFields
      .map(
        (field) => switch (field) {
          _MealEditField.protein => 'Protein',
          _MealEditField.fat => 'Fat',
          _MealEditField.carbs => 'Carbs',
          _MealEditField.weight => 'Weight',
          _MealEditField.calories => 'Calories',
        },
      )
      .toList(growable: false);
}

class _MealFormDraft {
  static const String conflictMessage =
      'This field can’t be auto-adjusted because other nutrition values were edited manually.';
  static const String existingInconsistencyMessage =
      'This meal has inconsistent nutrition values. Reset auto-calc to normalize it.';
  static const double _existingConsistencyToleranceRatio = 0.15;
  static const String allMacrosLockedMessage =
      'All macros are manually locked. Unlock one macro or reset auto-calc to continue.';
  static const String lockedCaloriesRebalanceMessage =
      'Calories are locked. Unlock another macro or reset auto-calc to rebalance this meal.';
  static const double _epsilon = 0.0001;
  static const Set<_MealEditField> _macroFields = {
    _MealEditField.protein,
    _MealEditField.fat,
    _MealEditField.carbs,
  };

  final double grams;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final Set<_MealEditField> lockedFields;
  final Set<_MealEditField> manuallyEditedMacroFields;
  final bool isManualCalorieOverride;
  final String? errorMessage;
  final _MealEditField? lastEditedField;

  const _MealFormDraft({
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.lockedFields,
    required this.manuallyEditedMacroFields,
    this.isManualCalorieOverride = false,
    this.errorMessage,
    this.lastEditedField,
  });

  factory _MealFormDraft.fromMeal(_MealEntry? meal) {
    return _MealFormDraft(
      grams: meal?.portionG ?? 0,
      kcal: meal?.kcal ?? 0,
      proteinG: meal?.proteinG ?? 0,
      fatG: meal?.fatG ?? 0,
      carbsG: meal?.carbsG ?? 0,
      lockedFields: const <_MealEditField>{},
      manuallyEditedMacroFields: const <_MealEditField>{},
      isManualCalorieOverride: false,
      lastEditedField: null,
    )._validateExistingConsistency();
  }

  _MealFormDraft copyWith({
    double? grams,
    double? kcal,
    double? proteinG,
    double? fatG,
    double? carbsG,
    Set<_MealEditField>? lockedFields,
    Set<_MealEditField>? manuallyEditedMacroFields,
    bool? isManualCalorieOverride,
    String? errorMessage,
    _MealEditField? lastEditedField,
    bool clearError = false,
    bool clearLastEditedField = false,
  }) {
    return _MealFormDraft(
      grams: grams ?? this.grams,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      carbsG: carbsG ?? this.carbsG,
      lockedFields: lockedFields ?? this.lockedFields,
      manuallyEditedMacroFields:
          manuallyEditedMacroFields ?? this.manuallyEditedMacroFields,
      isManualCalorieOverride:
          isManualCalorieOverride ?? this.isManualCalorieOverride,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastEditedField: clearLastEditedField
          ? null
          : (lastEditedField ?? this.lastEditedField),
    );
  }

  bool isLocked(_MealEditField field) => lockedFields.contains(field);

  bool isSameSessionState(_MealFormDraft other) {
    return grams == other.grams &&
        kcal == other.kcal &&
        proteinG == other.proteinG &&
        fatG == other.fatG &&
        carbsG == other.carbsG &&
        setEquals(lockedFields, other.lockedFields) &&
        setEquals(manuallyEditedMacroFields, other.manuallyEditedMacroFields) &&
        isManualCalorieOverride == other.isManualCalorieOverride &&
        errorMessage == other.errorMessage &&
        lastEditedField == other.lastEditedField;
  }

  bool get hasLockedFields => lockedFields.isNotEmpty;

  bool get shouldShowResetAutoCalc =>
      hasLockedFields || errorMessage == existingInconsistencyMessage;

  bool get hasCaloriesLockedConflict =>
      isLocked(_MealEditField.calories) && errorMessage == conflictMessage;

  bool get allMacrosManuallyEdited =>
      manuallyEditedMacroFields.length == _macroFields.length;

  String? get inlineMessage {
    if (errorMessage == null) return null;
    if (errorMessage != conflictMessage) return errorMessage;
    if (!hasCaloriesLockedConflict) return conflictMessage;
    if (buildAutoAdjustedDraftRespectingAllManualMacroChanges() != null) {
      return null;
    }
    if (allMacrosManuallyEdited) {
      return allMacrosLockedMessage;
    }
    return lockedCaloriesRebalanceMessage;
  }

  _MealFormDraft applyUserEdit(_MealEditField field, double value) {
    final nextLockedFields = Set<_MealEditField>.from(lockedFields)..add(field);
    final nextManuallyEditedMacroFields = Set<_MealEditField>.from(
      manuallyEditedMacroFields,
    );
    if (_macroFields.contains(field)) {
      nextManuallyEditedMacroFields.add(field);
    }
    var next = copyWith(
      lockedFields: nextLockedFields,
      manuallyEditedMacroFields: nextManuallyEditedMacroFields,
      clearError: true,
      lastEditedField: field,
    )._withFieldValue(field, value);

    if (next.isManualCalorieOverride) {
      return next;
    }

    if (field == _MealEditField.weight) {
      next = next._applyWeightChange(previousWeight: grams);
    } else if (field == _MealEditField.calories) {
      next = next._rebalanceUnlockedMacrosToTargetCalories();
    } else {
      next = isLocked(_MealEditField.calories)
          ? next._validateLockedCaloriesConflict()
          : next._syncCaloriesToMacros();
    }

    return next;
  }

  _MealFormDraft enableManualCalorieOverride() {
    return copyWith(isManualCalorieOverride: true, clearError: true);
  }

  _MealFormDraft applyManualCalorieOverride(double value) {
    final nextLockedFields = Set<_MealEditField>.from(lockedFields)
      ..add(_MealEditField.calories);
    return copyWith(
      kcal: value,
      lockedFields: nextLockedFields,
      isManualCalorieOverride: true,
      clearError: true,
      lastEditedField: _MealEditField.calories,
    );
  }

  _MealFormDraft lockField(_MealEditField field) {
    final nextLockedFields = Set<_MealEditField>.from(lockedFields)..add(field);
    final next = copyWith(lockedFields: nextLockedFields, clearError: true);
    if (!next.isLocked(_MealEditField.calories)) {
      return next._syncCaloriesToMacros();
    }
    return next._validateLockedCaloriesConflict();
  }

  _MealFormDraft unlockField(_MealEditField field) {
    final nextLockedFields = Set<_MealEditField>.from(lockedFields)
      ..remove(field);
    final nextManuallyEditedMacroFields = Set<_MealEditField>.from(
      manuallyEditedMacroFields,
    )..remove(field);
    var next = copyWith(
      lockedFields: nextLockedFields,
      manuallyEditedMacroFields: nextManuallyEditedMacroFields,
      clearError: true,
      clearLastEditedField: lastEditedField == field,
    );
    if (!next.isLocked(_MealEditField.calories)) {
      return next._syncCaloriesToMacros();
    }
    return next._rebalanceUnlockedMacrosToTargetCalories();
  }

  _MealFormDraft resetAutoCalc() {
    return copyWith(
      lockedFields: <_MealEditField>{},
      manuallyEditedMacroFields: <_MealEditField>{},
      isManualCalorieOverride: false,
      clearError: true,
      clearLastEditedField: true,
    )._syncCaloriesToMacros();
  }

  _MealLockedCaloriesAutoAdjustProposal?
  buildAutoAdjustedDraftRespectingAllManualMacroChanges() {
    if (errorMessage != conflictMessage ||
        !isLocked(_MealEditField.calories) ||
        manuallyEditedMacroFields.isEmpty) {
      return null;
    }

    final adjustedFields = _macroFields
        .where(
          (field) =>
              !isLocked(field) && !manuallyEditedMacroFields.contains(field),
        )
        .toList(growable: false);
    if (adjustedFields.isEmpty) {
      return null;
    }

    final fixedMacroFields = _macroFields
        .where(
          (field) =>
              isLocked(field) || manuallyEditedMacroFields.contains(field),
        )
        .toList(growable: false);
    final fixedCalories = fixedMacroFields.fold(
      0.0,
      (sum, field) => sum + _caloriesForField(field),
    );
    final adjustableCalories = adjustedFields.fold(
      0.0,
      (sum, field) => sum + _caloriesForField(field),
    );
    final remainingCalories = kcal - fixedCalories;

    if (remainingCalories < -_epsilon || adjustableCalories.abs() < _epsilon) {
      return null;
    }

    final ratio = remainingCalories / adjustableCalories;
    if (ratio < -_epsilon) {
      return null;
    }

    var adjustedDraft = copyWith(clearError: true);
    for (final field in adjustedFields) {
      adjustedDraft = adjustedDraft._withFieldValue(
        field,
        adjustedDraft._valueForField(field) * ratio,
      );
    }

    return _MealLockedCaloriesAutoAdjustProposal(
      adjustedDraft: adjustedDraft.copyWith(
        clearError: true,
        lastEditedField: lastEditedField,
      ),
      adjustedFields: adjustedFields,
    );
  }

  _MealFormDraft _withFieldValue(_MealEditField field, double value) {
    switch (field) {
      case _MealEditField.weight:
        return copyWith(grams: value);
      case _MealEditField.calories:
        return copyWith(kcal: value);
      case _MealEditField.protein:
        return copyWith(proteinG: value);
      case _MealEditField.fat:
        return copyWith(fatG: value);
      case _MealEditField.carbs:
        return copyWith(carbsG: value);
    }
  }

  _MealFormDraft _applyWeightChange({required double previousWeight}) {
    if (previousWeight <= 0 || grams <= 0) {
      return isLocked(_MealEditField.calories)
          ? copyWith(clearError: true)
          : _syncCaloriesToMacros();
    }

    final ratio = grams / previousWeight;
    var next = this;
    if (!isLocked(_MealEditField.calories)) {
      next = next.copyWith(kcal: kcal * ratio);
    }
    if (!isLocked(_MealEditField.protein)) {
      next = next.copyWith(proteinG: proteinG * ratio);
    }
    if (!isLocked(_MealEditField.fat)) {
      next = next.copyWith(fatG: fatG * ratio);
    }
    if (!isLocked(_MealEditField.carbs)) {
      next = next.copyWith(carbsG: carbsG * ratio);
    }

    return next.isLocked(_MealEditField.calories)
        ? next._rebalanceUnlockedMacrosToTargetCalories()
        : next._syncCaloriesToMacros();
  }

  _MealFormDraft _syncCaloriesToMacros() {
    return copyWith(
      kcal: _mealCaloriesFromMacros(
        proteinG: proteinG,
        fatG: fatG,
        carbsG: carbsG,
      ),
      clearError: true,
    );
  }

  _MealFormDraft _validateExistingConsistency() {
    final computedCalories = _mealCaloriesFromMacros(
      proteinG: proteinG,
      fatG: fatG,
      carbsG: carbsG,
    );
    final comparisonBase = kcal.abs() > _epsilon
        ? kcal.abs()
        : computedCalories.abs();
    if ((computedCalories - kcal).abs() < _epsilon) {
      return copyWith(clearError: true);
    }
    if (comparisonBase <= _epsilon) {
      return copyWith(clearError: true);
    }
    final relativeDifference = (computedCalories - kcal).abs() / comparisonBase;
    if (relativeDifference <= _existingConsistencyToleranceRatio) {
      return copyWith(clearError: true);
    }
    return copyWith(errorMessage: existingInconsistencyMessage);
  }

  _MealFormDraft _validateLockedCaloriesConflict() {
    final computedCalories = _mealCaloriesFromMacros(
      proteinG: proteinG,
      fatG: fatG,
      carbsG: carbsG,
    );
    if ((computedCalories - kcal).abs() < _epsilon) {
      return copyWith(clearError: true);
    }
    return copyWith(errorMessage: conflictMessage);
  }

  _MealFormDraft _rebalanceUnlockedMacrosToTargetCalories() {
    final lockedMacroCalories = _macroFields
        .where(isLocked)
        .fold(0.0, (sum, field) => sum + _caloriesForField(field));
    final adjustableFields = _macroFields.where((field) => !isLocked(field));
    final adjustableCalories = adjustableFields.fold(
      0.0,
      (sum, field) => sum + _caloriesForField(field),
    );
    final remainingCalories = kcal - lockedMacroCalories;

    if (remainingCalories < -_epsilon) {
      return copyWith(errorMessage: conflictMessage);
    }

    final adjustableFieldList = adjustableFields.toList(growable: false);
    if (adjustableFieldList.isEmpty) {
      return (_mealCaloriesFromMacros(
                        proteinG: proteinG,
                        fatG: fatG,
                        carbsG: carbsG,
                      ) -
                      kcal)
                  .abs() <
              _epsilon
          ? copyWith(clearError: true)
          : copyWith(errorMessage: conflictMessage);
    }

    if (adjustableCalories.abs() < _epsilon) {
      if (remainingCalories.abs() < _epsilon) {
        var zeroed = this;
        for (final field in adjustableFieldList) {
          zeroed = zeroed._withFieldValue(field, 0);
        }
        return zeroed.copyWith(clearError: true);
      }
      return copyWith(errorMessage: conflictMessage);
    }

    final ratio = remainingCalories / adjustableCalories;
    if (ratio < -_epsilon) {
      return copyWith(errorMessage: conflictMessage);
    }

    var next = this;
    for (final field in adjustableFieldList) {
      next = next._withFieldValue(field, _valueForField(field) * ratio);
    }

    return copyWith(
      proteinG: next.proteinG,
      fatG: next.fatG,
      carbsG: next.carbsG,
      clearError: true,
    );
  }

  double _valueForField(_MealEditField field) {
    switch (field) {
      case _MealEditField.weight:
        return grams;
      case _MealEditField.calories:
        return kcal;
      case _MealEditField.protein:
        return proteinG;
      case _MealEditField.fat:
        return fatG;
      case _MealEditField.carbs:
        return carbsG;
    }
  }

  double _caloriesForField(_MealEditField field) {
    switch (field) {
      case _MealEditField.protein:
        return proteinG * 4;
      case _MealEditField.fat:
        return fatG * 9;
      case _MealEditField.carbs:
        return carbsG * 4;
      case _MealEditField.weight:
      case _MealEditField.calories:
        return 0;
    }
  }
}

double _mealCaloriesFromMacros({
  required double proteinG,
  required double fatG,
  required double carbsG,
}) {
  return (proteinG * 4) + (fatG * 9) + (carbsG * 4);
}
