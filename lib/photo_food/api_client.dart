import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../app_config.dart';
import 'api_error.dart';
import 'models.dart';
import 'repository.dart';

class PhotoFoodApiClient implements PhotoFoodRepository {
  static const int _maxFileSizeBytes = 8 * 1024 * 1024;
  static const Set<String> _allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };
  static const Duration _requestTimeout = Duration(seconds: 25);

  final AppConfig config;
  final http.Client _httpClient;

  PhotoFoodApiClient({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  @override
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale = 'en-US',
    String? mealTime,
    PhotoClarificationInput? clarification,
  }) async {
    final uri = _resolveUri('/v0/ai/photo-food');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-API-Key'] = config.apiKey
      ..fields['locale'] = locale;

    if (mealTime != null && mealTime.trim().isNotEmpty) {
      request.fields['meal_time'] = mealTime.trim();
    }
    if (clarification != null) {
      final dishCategory = clarification.dishCategory;
      if (dishCategory != null) {
        request.fields['dish_category'] = dishCategory.apiValue;
      }
      if (clarification.ingredientHints.isNotEmpty) {
        request.fields['ingredient_hints'] = jsonEncode(
          clarification.ingredientHints,
        );
      }
      request.fields['analysis_mode'] = 'clarified';
    } else {
      request.fields['analysis_mode'] = 'initial';
    }

    final imageBytes = await image.readAsBytes();
    if (imageBytes.isEmpty) {
      throw const ApiException(
        ApiError(code: 'EMPTY_IMAGE_FILE', message: 'Empty image file'),
      );
    }
    if (imageBytes.length > _maxFileSizeBytes) {
      throw const ApiException(
        ApiError(code: 'IMAGE_TOO_LARGE', message: 'Image file too large'),
      );
    }

    final detectedMimeType = lookupMimeType(
      image.path,
      headerBytes: imageBytes,
    );
    final mimeType = detectedMimeType == 'image/jpg'
        ? 'image/jpeg'
        : detectedMimeType;
    if (mimeType == null || !_allowedMimeTypes.contains(mimeType)) {
      throw const ApiException(
        ApiError(
          code: 'UNSUPPORTED_IMAGE_TYPE',
          message: 'Unsupported image type, use jpg/png/webp',
        ),
      );
    }

    final mimeParts = mimeType.split('/');
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: _fileNameFromPath(image.path),
        contentType: MediaType(mimeParts[0], mimeParts[1]),
      ),
    );

    try {
      final streamed = await _httpClient.send(request).timeout(_requestTimeout);
      final body = await streamed.stream.bytesToString().timeout(
        _requestTimeout,
      );
      return _parseResponseOrThrow(statusCode: streamed.statusCode, body: body);
    } on http.ClientException {
      throw const ApiException(
        ApiError(
          code: 'CONNECTION_ERROR',
          message: 'Could not connect to the analysis service',
        ),
      );
    } on SocketException {
      throw const ApiException(
        ApiError(code: 'NETWORK_ERROR', message: 'Network error'),
      );
    } on HandshakeException {
      throw const ApiException(
        ApiError(
          code: 'SECURE_CONNECTION_ERROR',
          message: 'Secure connection to the analysis service failed',
        ),
      );
    } on TimeoutException {
      throw const ApiException(
        ApiError(code: 'REQUEST_TIMEOUT', message: 'Request timeout'),
      );
    }
  }

  @override
  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  }) async {
    final uri = _resolveUri('/v0/ai/photo-food/confirm-portion');
    final body = <String, dynamic>{
      'request_id': requestId,
      'confirm_mode': useAiEstimate ? 'use_ai_estimate' : 'manual',
    };
    if (!useAiEstimate) {
      if (portionG == null) {
        throw const ApiException(
          ApiError(code: 'VALIDATION_ERROR', message: 'portion_g is required'),
        );
      }
      body['portion_g'] = portionG;
    }
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'X-API-Key': config.apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _parseResponseOrThrow(
        statusCode: response.statusCode,
        body: response.body,
      );
    } on http.ClientException {
      throw const ApiException(
        ApiError(
          code: 'CONNECTION_ERROR',
          message: 'Could not connect to the analysis service',
        ),
      );
    } on SocketException {
      throw const ApiException(
        ApiError(code: 'NETWORK_ERROR', message: 'Network error'),
      );
    } on HandshakeException {
      throw const ApiException(
        ApiError(
          code: 'SECURE_CONNECTION_ERROR',
          message: 'Secure connection to the analysis service failed',
        ),
      );
    } on TimeoutException {
      throw const ApiException(
        ApiError(code: 'REQUEST_TIMEOUT', message: 'Request timeout'),
      );
    }
  }

  Uri _resolveUri(String path) {
    final base = config.apiBaseUrl.endsWith('/')
        ? config.apiBaseUrl.substring(0, config.apiBaseUrl.length - 1)
        : config.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  String _fileNameFromPath(String path) {
    if (path.isEmpty) {
      return 'image.jpg';
    }
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index < 0 ? normalized : normalized.substring(index + 1);
  }

  PhotoFoodResponse _parseResponseOrThrow({
    required int statusCode,
    required String body,
  }) {
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      throw ApiException(
        ApiError(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'Analysis service returned an invalid response',
          statusCode: statusCode,
        ),
      );
    }

    if (statusCode >= 200 && statusCode < 300) {
      if (decoded is! Map<String, dynamic>) {
        throw ApiException(
          ApiError(
            code: 'INVALID_SERVER_RESPONSE',
            message: 'Analysis service returned an invalid response',
            statusCode: statusCode,
          ),
        );
      }
      try {
        return PhotoFoodResponse.fromJson(decoded);
      } on FormatException {
        throw ApiException(
          ApiError(
            code: 'INVALID_SERVER_RESPONSE',
            message: 'Analysis service returned an invalid response',
            statusCode: statusCode,
          ),
        );
      } on TypeError {
        throw ApiException(
          ApiError(
            code: 'INVALID_SERVER_RESPONSE',
            message: 'Analysis service returned an invalid response',
            statusCode: statusCode,
          ),
        );
      }
    }

    if (decoded is Map<String, dynamic>) {
      throw ApiException(
        ApiError.fromEnvelope(decoded, statusCode: statusCode),
      );
    }

    throw ApiException(
      ApiError(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
        statusCode: statusCode,
      ),
    );
  }
}
