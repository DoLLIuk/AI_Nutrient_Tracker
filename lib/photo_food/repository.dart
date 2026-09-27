import 'package:image_picker/image_picker.dart';

import 'api_error.dart';
import 'models.dart';

abstract class PhotoFoodRepository {
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale,
    String? mealTime,
    PhotoClarificationInput? clarification,
    String? operationId,
  });

  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  });
}

/// Used when a build has no photo-analysis backend configuration.
///
/// The UI keeps photo actions unavailable in this mode. This implementation
/// still makes an accidental call recoverable instead of crashing the app.
class UnavailablePhotoFoodRepository implements PhotoFoodRepository {
  const UnavailablePhotoFoodRepository();

  static const ApiException _unavailable = ApiException(
    ApiError(
      code: 'CONFIGURATION_ERROR',
      message: 'Photo analysis is not configured for this build.',
    ),
  );

  @override
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale = 'en-US',
    String? mealTime,
    PhotoClarificationInput? clarification,
    String? operationId,
  }) {
    return Future<PhotoFoodResponse>.error(_unavailable);
  }

  @override
  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  }) {
    return Future<PhotoFoodResponse>.error(_unavailable);
  }
}
