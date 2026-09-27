enum DishCategory {
  soup('soup'),
  salad('salad'),
  bowl('bowl'),
  pasta('pasta'),
  mixedPlate('mixed_plate');

  const DishCategory(this.apiValue);

  final String apiValue;

  static DishCategory? fromApiValue(String? value) {
    if (value == null) return null;
    for (final category in DishCategory.values) {
      if (category.apiValue == value) {
        return category;
      }
    }
    return null;
  }
}

class PhotoClarificationInput {
  final DishCategory? dishCategory;
  final List<String> ingredientHints;

  const PhotoClarificationInput({
    this.dishCategory,
    this.ingredientHints = const [],
  });
}

class NutritionPer100g {
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;

  const NutritionPer100g({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  factory NutritionPer100g.fromJson(Map<String, dynamic> json) {
    return NutritionPer100g(
      kcal: (json['kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
    );
  }
}

class EstimatedTotals {
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;

  const EstimatedTotals({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  factory EstimatedTotals.fromJson(Map<String, dynamic> json) {
    return EstimatedTotals(
      kcal: (json['kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
    );
  }
}

class Item {
  final String name;
  final String? category;
  final String? foodType;
  final double confidence;
  final NutritionPer100g nutritionPer100g;
  final List<String> warnings;

  const Item({
    required this.name,
    required this.category,
    required this.foodType,
    required this.confidence,
    required this.nutritionPer100g,
    required this.warnings,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      name: json['name'] as String,
      category: json['category'] as String?,
      foodType: json['food_type'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      nutritionPer100g: NutritionPer100g.fromJson(
        json['nutrition_per_100g'] as Map<String, dynamic>,
      ),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class UiFlags {
  final bool requiresUserConfirmation;
  final String highlightLevel;
  final bool clarificationAvailable;
  final bool shouldPromptClarification;

  const UiFlags({
    required this.requiresUserConfirmation,
    required this.highlightLevel,
    this.clarificationAvailable = false,
    this.shouldPromptClarification = false,
  });

  factory UiFlags.fromJson(Map<String, dynamic> json) {
    return UiFlags(
      requiresUserConfirmation: json['requires_user_confirmation'] as bool,
      highlightLevel: json['highlight_level'] as String,
      clarificationAvailable: json['clarification_available'] as bool? ?? false,
      shouldPromptClarification:
          json['should_prompt_clarification'] as bool? ?? false,
    );
  }
}

class Meta {
  final bool needsConfirmation;
  final double? estimatedPortionG;
  final String? portionBasis;
  final String? confirmationSource;
  final bool totalsAreEstimate;
  final EstimatedTotals? estimatedTotals;
  final String? ambiguityReason;
  final List<DishCategory> clarificationCategories;

  const Meta({
    required this.needsConfirmation,
    required this.estimatedPortionG,
    required this.portionBasis,
    required this.confirmationSource,
    required this.totalsAreEstimate,
    required this.estimatedTotals,
    this.ambiguityReason,
    this.clarificationCategories = const [],
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    final totalsJson = json['estimated_totals'];
    final clarificationCategories =
        ((json['clarification_categories'] as List?) ?? const [])
            .map((value) => DishCategory.fromApiValue(value?.toString()))
            .whereType<DishCategory>()
            .toList(growable: false);
    return Meta(
      needsConfirmation: json['needs_confirmation'] as bool,
      estimatedPortionG: (json['estimated_portion_g'] as num?)?.toDouble(),
      portionBasis: json['portion_basis'] as String?,
      confirmationSource: json['confirmation_source'] as String?,
      totalsAreEstimate: json['totals_are_estimate'] as bool,
      estimatedTotals: totalsJson is Map<String, dynamic>
          ? EstimatedTotals.fromJson(totalsJson)
          : null,
      ambiguityReason: json['ambiguity_reason'] as String?,
      clarificationCategories: clarificationCategories,
    );
  }
}

class PhotoFoodResponse {
  final String requestId;
  final Item item;
  final UiFlags uiFlags;
  final Meta meta;

  const PhotoFoodResponse({
    required this.requestId,
    required this.item,
    required this.uiFlags,
    required this.meta,
  });

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'item': {
      'name': item.name,
      'category': item.category,
      'food_type': item.foodType,
      'confidence': item.confidence,
      'warnings': item.warnings,
      'nutrition_per_100g': {
        'kcal': item.nutritionPer100g.kcal,
        'protein_g': item.nutritionPer100g.proteinG,
        'fat_g': item.nutritionPer100g.fatG,
        'carbs_g': item.nutritionPer100g.carbsG,
      },
    },
    'ui_flags': {
      'requires_user_confirmation': uiFlags.requiresUserConfirmation,
      'highlight_level': uiFlags.highlightLevel,
      'clarification_available': uiFlags.clarificationAvailable,
      'should_prompt_clarification': uiFlags.shouldPromptClarification,
    },
    'meta': {
      'needs_confirmation': meta.needsConfirmation,
      'estimated_portion_g': meta.estimatedPortionG,
      'portion_basis': meta.portionBasis,
      'confirmation_source': meta.confirmationSource,
      'totals_are_estimate': meta.totalsAreEstimate,
      'ambiguity_reason': meta.ambiguityReason,
      'clarification_categories': meta.clarificationCategories
          .map((e) => e.apiValue)
          .toList(),
      'estimated_totals': meta.estimatedTotals == null
          ? null
          : {
              'kcal': meta.estimatedTotals!.kcal,
              'protein_g': meta.estimatedTotals!.proteinG,
              'fat_g': meta.estimatedTotals!.fatG,
              'carbs_g': meta.estimatedTotals!.carbsG,
            },
    },
  };

  factory PhotoFoodResponse.fromJson(Map<String, dynamic> json) {
    return PhotoFoodResponse(
      requestId: json['request_id'] as String,
      item: Item.fromJson(json['item'] as Map<String, dynamic>),
      uiFlags: UiFlags.fromJson(json['ui_flags'] as Map<String, dynamic>),
      meta: Meta.fromJson(json['meta'] as Map<String, dynamic>),
    );
  }
}
