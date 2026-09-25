import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api_error.dart';
import 'models.dart';
import 'photo_picker.dart';
import 'repository.dart';

enum HomeStatus {
  idle,
  pickingImage,
  uploading,
  awaitingPortion,
  confirmingPortion,
  loaded,
  error,
}

class HomeState {
  final HomeStatus status;
  final PhotoFoodResponse? response;
  final ApiError? error;

  const HomeState({required this.status, this.response, this.error});

  const HomeState.initial() : this(status: HomeStatus.idle);

  HomeState copyWith({
    HomeStatus? status,
    PhotoFoodResponse? response,
    ApiError? error,
    bool clearError = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      response: response ?? this.response,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PhotoFoodController extends ChangeNotifier {
  final PhotoFoodRepository repository;
  final PhotoPicker photoPicker;

  HomeState _state = const HomeState.initial();
  XFile? _lastPickedFile;
  PhotoClarificationInput? _lastClarification;

  HomeState get state => _state;

  PhotoFoodController({required this.repository, required this.photoPicker});

  Future<XFile?> pickImage(PickSource source) async {
    _setState(
      _state.copyWith(status: HomeStatus.pickingImage, clearError: true),
    );

    final pickedFile = await photoPicker.pick(source);
    if (pickedFile == null) {
      _setState(_state.copyWith(status: HomeStatus.idle));
      return null;
    }
    _lastPickedFile = pickedFile;
    _setState(_state.copyWith(status: HomeStatus.idle));
    return pickedFile;
  }

  Future<XFile> pickSampleImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final file = XFile.fromData(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      name: assetPath.split('/').last,
      mimeType: 'image/jpeg',
    );
    _lastPickedFile = file;
    _setState(_state.copyWith(status: HomeStatus.idle, clearError: true));
    return file;
  }

  Future<void> analyzePickedImage({
    PhotoClarificationInput? clarification,
  }) async {
    final pickedFile = _lastPickedFile;
    if (pickedFile == null) return;
    _lastClarification = clarification;
    _setState(_state.copyWith(status: HomeStatus.uploading));
    try {
      final response = await repository.analyzePhoto(
        pickedFile,
        locale: 'en-US',
        clarification: clarification,
      );
      _setState(
        HomeState(status: _resolvedStatus(response), response: response),
      );
    } on ApiException catch (e) {
      _setState(
        HomeState(
          status: HomeStatus.error,
          response: _state.response,
          error: e.error,
        ),
      );
    } catch (_) {
      _setState(
        const HomeState(
          status: HomeStatus.error,
          error: ApiError(
            code: 'INTERNAL_ERROR',
            message: 'Internal server error',
          ),
        ),
      );
    }
  }

  Future<void> retryLastAnalysis() {
    return analyzePickedImage(clarification: _lastClarification);
  }

  HomeStatus _resolvedStatus(PhotoFoodResponse response) {
    if (response.uiFlags.requiresUserConfirmation) {
      return HomeStatus.awaitingPortion;
    }
    return HomeStatus.loaded;
  }

  Future<bool> confirmPortion(double portionG) async {
    return _confirmPortion(portionG: portionG);
  }

  Future<bool> confirmPortionWithAiEstimate() async {
    return _confirmPortion(useAiEstimate: true);
  }

  Future<bool> _confirmPortion({
    double? portionG,
    bool useAiEstimate = false,
  }) async {
    final response = _state.response;
    if (response == null) {
      return false;
    }

    _setState(
      _state.copyWith(status: HomeStatus.confirmingPortion, clearError: true),
    );
    try {
      final confirmed = await repository.confirmPortion(
        requestId: response.requestId,
        portionG: portionG,
        useAiEstimate: useAiEstimate,
      );
      _setState(HomeState(status: HomeStatus.loaded, response: confirmed));
      return true;
    } on ApiException catch (e) {
      _setState(
        HomeState(status: HomeStatus.error, response: response, error: e.error),
      );
      return false;
    } catch (_) {
      _setState(
        HomeState(
          status: HomeStatus.error,
          response: response,
          error: const ApiError(
            code: 'INTERNAL_ERROR',
            message: 'Internal server error',
          ),
        ),
      );
      return false;
    }
  }

  static String? validatePortionInput(String value) {
    final grams = double.tryParse(value.trim().replaceAll(',', '.'));
    if (grams == null) {
      return 'Enter a number in grams.';
    }
    if (grams < 1 || grams > 2000) {
      return 'Portion must be between 1 and 2000 g.';
    }
    return null;
  }

  void clearError() {
    if (_state.error == null) {
      return;
    }
    _setState(_state.copyWith(clearError: true, status: HomeStatus.idle));
  }

  void _setState(HomeState next) {
    _state = next;
    notifyListeners();
  }
}
