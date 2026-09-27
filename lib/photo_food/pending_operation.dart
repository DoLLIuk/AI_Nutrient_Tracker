import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class PendingPhotoOperation {
  final String id;
  final DateTime diaryDate;
  final DateTime capturedAt;
  final XFile? image;
  final PhotoClarificationInput? clarification;
  final PhotoFoodResponse? response;
  final bool draft;
  final bool awaitingPicker;
  final bool confirmationPending;
  final double? confirmationGrams;
  final bool useAiEstimate;
  final int? baseRevision;

  const PendingPhotoOperation({
    required this.id,
    required this.diaryDate,
    required this.capturedAt,
    this.image,
    this.clarification,
    this.response,
    this.draft = false,
    this.awaitingPicker = false,
    this.confirmationPending = false,
    this.confirmationGrams,
    this.useAiEstimate = false,
    this.baseRevision,
  });

  PendingPhotoOperation completed(PhotoFoodResponse value) =>
      PendingPhotoOperation(
        id: id,
        diaryDate: diaryDate,
        capturedAt: capturedAt,
        clarification: clarification,
        response: value,
        baseRevision: baseRevision,
      );

  PendingPhotoOperation confirming({
    double? grams,
    required bool useEstimate,
    required int revision,
  }) => PendingPhotoOperation(
    id: id,
    diaryDate: diaryDate,
    capturedAt: capturedAt,
    response: response,
    confirmationPending: true,
    confirmationGrams: grams,
    useAiEstimate: useEstimate,
    baseRevision: revision,
  );

  PendingPhotoOperation withImage(XFile file) => PendingPhotoOperation(
    id: id,
    diaryDate: diaryDate,
    capturedAt: capturedAt,
    image: file,
    draft: true,
  );

  PendingPhotoOperation ready({
    PhotoClarificationInput? hints,
    DateTime? date,
    DateTime? time,
  }) => PendingPhotoOperation(
    id: id,
    diaryDate: date ?? diaryDate,
    capturedAt: time ?? capturedAt,
    image: image,
    clarification: hints,
  );

  Future<Map<String, dynamic>> toJson({bool includeImage = true}) async => {
    'version': 1,
    'id': id,
    'diaryDate': diaryDate.toIso8601String(),
    'capturedAt': capturedAt.toIso8601String(),
    'filename': image?.name,
    'image': !includeImage || image == null
        ? null
        : base64Encode(await image!.readAsBytes()),
    'draft': draft,
    'awaitingPicker': awaitingPicker,
    'confirmationPending': confirmationPending,
    'confirmationGrams': confirmationGrams,
    'useAiEstimate': useAiEstimate,
    'baseRevision': baseRevision,
    'category': clarification?.dishCategory?.apiValue,
    'hints': clarification?.ingredientHints,
    'response': response?.toJson(),
  };

  factory PendingPhotoOperation.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown scan version');
    }
    return PendingPhotoOperation(
      id: json['id'] as String,
      diaryDate: DateTime.parse(json['diaryDate'] as String),
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      image: json['imagePath'] != null
          ? XFile(
              json['imagePath'] as String,
              name: json['filename'] as String?,
            )
          : json['image'] == null
          ? null
          : XFile.fromData(
              base64Decode(json['image'] as String),
              name: json['filename'] as String,
            ),
      clarification: json['hints'] == null
          ? null
          : PhotoClarificationInput(
              dishCategory: DishCategory.fromApiValue(
                json['category'] as String?,
              ),
              ingredientHints: (json['hints'] as List).cast<String>(),
            ),
      response: json['response'] == null
          ? null
          : PhotoFoodResponse.fromJson(
              Map<String, dynamic>.from(json['response'] as Map),
            ),
      draft: json['draft'] as bool? ?? false,
      awaitingPicker: json['awaitingPicker'] as bool? ?? false,
      confirmationPending: json['confirmationPending'] as bool? ?? false,
      confirmationGrams: (json['confirmationGrams'] as num?)?.toDouble(),
      useAiEstimate: json['useAiEstimate'] as bool? ?? false,
      baseRevision: json['baseRevision'] as int?,
    );
  }
}

abstract class PhotoOperationStore {
  Future<PendingPhotoOperation?> read();
  Future<void> write(PendingPhotoOperation operation);
  Future<void> clear();
}

/// In-memory store for injected controllers and unit tests.
class MemoryPhotoOperationStore implements PhotoOperationStore {
  PendingPhotoOperation? value;
  @override
  Future<PendingPhotoOperation?> read() async => value;
  @override
  Future<void> write(PendingPhotoOperation operation) async {
    value = operation;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
