class ApiError {
  final String code;
  final String message;
  final String? requestId;
  final int? statusCode;

  const ApiError({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
  });

  factory ApiError.fromEnvelope(Map<String, dynamic> json, {int? statusCode}) {
    final envelope = json['error'];
    if (envelope is Map<String, dynamic>) {
      return ApiError(
        code: (envelope['code'] as String?) ?? 'INTERNAL_ERROR',
        message: (envelope['message'] as String?) ?? 'Internal server error',
        requestId: envelope['request_id'] as String?,
        statusCode: statusCode,
      );
    }
    return ApiError(
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
      statusCode: statusCode,
    );
  }
}

String mapErrorCodeToMessage(String code) {
  switch (code) {
    case 'UNAUTHORIZED':
      return 'Invalid API key.';
    case 'NO_FOOD_DETECTED':
      return 'No food detected in the photo.';
    case 'IMAGE_UNCLEAR':
      return 'Image is blurry. Please try another photo.';
    case 'UNSUPPORTED_IMAGE_TYPE':
      return 'Unsupported format. Use JPG, PNG, or WEBP.';
    case 'IMAGE_TOO_LARGE':
      return 'File is too large. Maximum size is 8MB.';
    case 'EMPTY_IMAGE_FILE':
      return 'Image file is empty.';
    case 'INVALID_IMAGE_FILE':
      return 'File is corrupted or not an image.';
    case 'IMAGE_FILE_REQUIRED':
      return 'Please select an image.';
    case 'PORTION_OUT_OF_RANGE':
      return 'Portion must be between 1 and 2000 g.';
    case 'RATE_LIMITED':
      return 'Too many requests. Please try again later.';
    case 'PROVIDER_TIMEOUT':
      return 'Analysis took too long. Please try again.';
    case 'PROVIDER_REQUEST_FAILED':
    case 'PROVIDER_ERROR':
    case 'MODEL_OUTPUT_INVALID':
      return 'Analysis is temporarily unavailable. Please try again.';
    case 'REQUEST_NOT_FOUND':
      return 'Request not found. Please upload the photo again.';
    case 'ESTIMATED_PORTION_UNAVAILABLE':
      return 'AI estimate is unavailable. Please enter grams manually.';
    case 'NETWORK_ERROR':
      return 'Network issue. Check your connection.';
    case 'CONNECTION_ERROR':
      return 'Cannot reach the analysis service. Check the connection and try again.';
    case 'SECURE_CONNECTION_ERROR':
      return 'Secure connection failed. Please try again later.';
    case 'INVALID_SERVER_RESPONSE':
      return 'Analysis service returned an invalid response. Please try again.';
    case 'INTERNAL_ERROR':
      return 'Something went wrong while processing the photo. Please try again.';
    default:
      return 'Could not process request. Please try again.';
  }
}

class ApiException implements Exception {
  final ApiError error;

  const ApiException(this.error);

  @override
  String toString() => 'ApiException(${error.code})';
}
