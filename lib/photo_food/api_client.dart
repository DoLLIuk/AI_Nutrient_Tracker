import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _pendingDiagnosticsKey =
      'photo_food.pending_client_diagnostics';

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
    final clientTraceId = _newClientTraceId();
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _requestHeaders(clientTraceId))
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
      await _clearPendingDiagnostics();
      return _parseResponseOrThrow(
        statusCode: streamed.statusCode,
        body: body,
        requestId: streamed.headers['x-request-id'],
        clientTraceId: clientTraceId,
      );
    } on http.ClientException {
      throw await _transportError(
        code: 'CONNECTION_ERROR',
        message: 'Could not connect to the analysis service',
        clientTraceId: clientTraceId,
      );
    } on SocketException {
      throw await _transportError(
        code: 'NETWORK_ERROR',
        message: 'Network error',
        clientTraceId: clientTraceId,
      );
    } on HandshakeException {
      throw await _transportError(
        code: 'SECURE_CONNECTION_ERROR',
        message: 'Secure connection to the analysis service failed',
        clientTraceId: clientTraceId,
      );
    } on TimeoutException {
      throw await _transportError(
        code: 'REQUEST_TIMEOUT',
        message: 'Request timeout',
        clientTraceId: clientTraceId,
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
    final clientTraceId = _newClientTraceId();
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
              ...await _requestHeaders(clientTraceId),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      await _clearPendingDiagnostics();
      return _parseResponseOrThrow(
        statusCode: response.statusCode,
        body: response.body,
        requestId: response.headers['x-request-id'],
        clientTraceId: clientTraceId,
      );
    } on http.ClientException {
      throw await _transportError(
        code: 'CONNECTION_ERROR',
        message: 'Could not connect to the analysis service',
        clientTraceId: clientTraceId,
      );
    } on SocketException {
      throw await _transportError(
        code: 'NETWORK_ERROR',
        message: 'Network error',
        clientTraceId: clientTraceId,
      );
    } on HandshakeException {
      throw await _transportError(
        code: 'SECURE_CONNECTION_ERROR',
        message: 'Secure connection to the analysis service failed',
        clientTraceId: clientTraceId,
      );
    } on TimeoutException {
      throw await _transportError(
        code: 'REQUEST_TIMEOUT',
        message: 'Request timeout',
        clientTraceId: clientTraceId,
      );
    }
  }

  Future<ApiException> _transportError({
    required String code,
    required String message,
    required String clientTraceId,
  }) async {
    await _enqueueClientDiagnostic(clientTraceId, code);
    return ApiException(
      ApiError(code: code, message: message, clientTraceId: clientTraceId),
    );
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
    required String? requestId,
    required String clientTraceId,
  }) {
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      throw ApiException(
        ApiError(
          code: 'INVALID_SERVER_RESPONSE',
          message: 'Analysis service returned an invalid response',
          requestId: requestId,
          clientTraceId: clientTraceId,
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
            requestId: requestId,
            clientTraceId: clientTraceId,
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
            requestId: requestId,
            clientTraceId: clientTraceId,
            statusCode: statusCode,
          ),
        );
      } on TypeError {
        throw ApiException(
          ApiError(
            code: 'INVALID_SERVER_RESPONSE',
            message: 'Analysis service returned an invalid response',
            requestId: requestId,
            clientTraceId: clientTraceId,
            statusCode: statusCode,
          ),
        );
      }
    }

    if (decoded is Map<String, dynamic>) {
      throw ApiException(
        ApiError.fromEnvelope(
          decoded,
          statusCode: statusCode,
        ).withTrace(requestId: requestId, clientTraceId: clientTraceId),
      );
    }

    throw ApiException(
      ApiError(
        code: 'INTERNAL_ERROR',
        message: 'Internal server error',
        requestId: requestId,
        clientTraceId: clientTraceId,
        statusCode: statusCode,
      ),
    );
  }

  String _newClientTraceId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = Random.secure().nextInt(1 << 32).toRadixString(36);
    return 'cli_$timestamp$random';
  }

  Future<Map<String, String>> _requestHeaders(String clientTraceId) async {
    final pending = await _pendingDiagnosticHeader();
    final diagnosticHeader = pending == null
        ? const <String, String>{}
        : <String, String>{'X-Client-Diagnostics': pending};
    return {
      'X-API-Key': config.apiKey,
      'X-Client-Trace-ID': clientTraceId,
      ...diagnosticHeader,
    };
  }

  Future<void> _enqueueClientDiagnostic(
    String traceId,
    String errorCode,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_pendingDiagnosticsKey) ?? const [];
      final entry = '$traceId:$errorCode';
      final entries = <String>[
        entry,
        ...raw.where((item) => item != entry),
      ].take(3).toList(growable: false);
      await preferences.setStringList(_pendingDiagnosticsKey, entries);
    } catch (_) {
      // Diagnostics must never prevent the primary photo flow.
    }
  }

  Future<String?> _pendingDiagnosticHeader() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final entries =
          preferences.getStringList(_pendingDiagnosticsKey) ?? const [];
      return entries.isEmpty ? null : entries.take(3).join(',');
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPendingDiagnostics() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_pendingDiagnosticsKey);
    } catch (_) {
      // A duplicated diagnostic is preferable to impacting an analysis result.
    }
  }
}
