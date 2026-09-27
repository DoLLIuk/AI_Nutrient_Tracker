import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api_error.dart';
import 'models.dart';
import 'photo_picker.dart';
import 'repository.dart';
import 'pending_operation.dart';

enum HomeStatus {
  idle,
  pickingImage,
  draftReady,
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
  final PhotoOperationStore operationStore;
  PendingPhotoOperation? _pending;
  PendingPhotoOperation? _lastOperation;
  bool _busy = false;
  Future<void> _storageQueue = Future<void>.value();
  Future<void> _store(Future<void> Function() action) {
    final next = _storageQueue.then((_) => action());
    _storageQueue = next.catchError((Object _) {});
    return next;
  }

  bool _restored = false;
  bool _disposed = false;
  final Set<String> deletedRequestIds = {};
  int? get resultBaseRevision => _lastOperation?.baseRevision;
  bool get hasDraft => _pending?.draft == true && _pending?.image != null;
  Object? get pendingReceipt =>
      _pending?.confirmationPending != true &&
          identical(_pending?.response, _state.response)
      ? _pending
      : null;
  bool get hasPendingScan => _pending != null;
  DateTime? get scanDate => _lastOperation?.diaryDate;
  DateTime? get scanCapturedAt => _lastOperation?.capturedAt;

  HomeState _state = const HomeState.initial();
  XFile? _lastPickedFile;

  HomeState get state => _state;

  PhotoFoodController({
    required this.repository,
    required this.photoPicker,
    PhotoOperationStore? operationStore,
  }) : operationStore = operationStore ?? MemoryPhotoOperationStore();

  Future<void> restorePending() async {
    if (_restored || _busy) return;
    _restored = true;
    _busy = true;
    try {
      _pending = await operationStore.read();
      if (_pending?.awaitingPicker == true) {
        final picker = photoPicker;
        final recovered = picker is RecoverablePhotoPicker
            ? await picker.recoverLostImage()
            : null;
        if (recovered == null) {
          await _store(() => operationStore.clear());
          _pending = null;
        } else {
          _pending = _pending!.withImage(recovered);
          await _store(() => operationStore.write(_pending!));
        }
      }
      _lastOperation = _pending;
      _busy = false;
      if (_pending != null) await retryLastAnalysis();
    } catch (_) {
      _storageError();
    } finally {
      _busy = false;
    }
  }

  Future<void> acknowledgeSaved(Set<String> requestIds, Object? receipt) =>
      _store(() async {
        if (receipt == null || !identical(receipt, _pending)) return;
        final pending = _pending;
        if (pending?.response == null ||
            !requestIds.contains(pending!.response!.requestId)) {
          return;
        }
        await operationStore.clear();
        if (identical(_pending, pending)) _pending = null;
      });

  Future<void> discardPending() async {
    if (_busy) return;
    _busy = true;
    try {
      await _store(() => operationStore.clear());
      _pending = null;
      _lastPickedFile = null;
      _setState(const HomeState.initial());
    } catch (_) {
      _storageError();
    } finally {
      _busy = false;
    }
  }

  void _storageError() => _setState(
    const HomeState(
      status: HomeStatus.error,
      error: ApiError(
        code: 'SCAN_STORAGE_FAILED',
        message: 'Could not save scan on this device',
      ),
    ),
  );

  bool _canPick() {
    if (_busy) return false;
    if (_pending != null) {
      _setState(
        const HomeState(
          status: HomeStatus.error,
          error: ApiError(
            code: 'SCAN_PENDING',
            message: 'Finish or discard the saved scan first',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  PendingPhotoOperation _newDraft({DateTime? diaryDate, DateTime? capturedAt}) {
    final now = capturedAt ?? DateTime.now();
    final random = Random.secure();
    return PendingPhotoOperation(
      id: List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      diaryDate: diaryDate ?? DateTime(now.year, now.month, now.day),
      capturedAt: now,
      draft: true,
      awaitingPicker: true,
    );
  }

  Future<XFile?> pickImage(
    PickSource source, {
    DateTime? diaryDate,
    DateTime? capturedAt,
  }) async {
    if (!_canPick()) return null;
    _busy = true;
    _setState(const HomeState(status: HomeStatus.pickingImage));
    try {
      _pending = _newDraft(diaryDate: diaryDate, capturedAt: capturedAt);
      await _store(() => operationStore.write(_pending!));
      final pickedFile = await photoPicker.pick(source);
      if (pickedFile == null) {
        await _store(() => operationStore.clear());
        _pending = null;
        _setState(const HomeState.initial());
        return null;
      }
      await _savePickedDraft(pickedFile);
      return pickedFile;
    } on PlatformException {
      _setState(
        const HomeState(
          status: HomeStatus.error,
          error: ApiError(
            code: 'PHOTO_PICK_FAILED',
            message: 'Could not open camera or photos',
          ),
        ),
      );
      return null;
    } on ApiException catch (e) {
      _setState(HomeState(status: HomeStatus.error, error: e.error));
      return null;
    } catch (_) {
      _storageError();
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> _savePickedDraft(XFile file) async {
    if (await file.length() > 8 * 1024 * 1024) {
      throw const ApiException(
        ApiError(code: 'IMAGE_TOO_LARGE', message: 'Image too large'),
      );
    }
    _pending = _pending!.withImage(file);
    _lastOperation = _pending;
    _lastPickedFile = file;
    await _store(() => operationStore.write(_pending!));
    _setState(const HomeState(status: HomeStatus.draftReady));
  }

  Future<XFile?> pickSampleImage(
    String assetPath, {
    DateTime? diaryDate,
    DateTime? capturedAt,
  }) async {
    if (!_canPick()) return null;
    _busy = true;
    try {
      final data = await rootBundle.load(assetPath);
      final file = XFile.fromData(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        name: assetPath.split('/').last,
        mimeType: 'image/jpeg',
      );
      _pending = _newDraft(diaryDate: diaryDate, capturedAt: capturedAt);
      await _savePickedDraft(file);
      return file;
    } catch (_) {
      _storageError();
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> analyzePickedImage({
    PhotoClarificationInput? clarification,
    DateTime? diaryDate,
    DateTime? capturedAt,
  }) async {
    if (_busy) return;
    if (_pending != null && !_pending!.draft) return retryLastAnalysis();
    if (_pending?.image == null && _lastPickedFile == null) return;
    _pending =
        (_pending ??
                _newDraft(
                  diaryDate: diaryDate,
                  capturedAt: capturedAt,
                ).withImage(_lastPickedFile!))
            .ready(hints: clarification, date: diaryDate, time: capturedAt);
    _lastOperation = _pending;
    await _runPending();
  }

  Future<void> _runPending() async {
    final operation = _pending;
    if (_busy || operation == null) return;
    if (operation.draft) {
      _setState(
        HomeState(
          status: operation.image == null
              ? HomeStatus.error
              : HomeStatus.draftReady,
          error: operation.image == null
              ? const ApiError(
                  code: 'PHOTO_PICK_FAILED',
                  message: 'Choose a photo again',
                )
              : null,
        ),
      );
      return;
    }
    _busy = true;
    _setState(
      HomeState(
        status: operation.confirmationPending
            ? HomeStatus.confirmingPortion
            : HomeStatus.uploading,
      ),
    );
    try {
      // A durable local write must succeed BEFORE a potentially paid request.
      await _store(() => operationStore.write(operation));
      if (operation.confirmationPending) {
        await _sendConfirmation(operation);
        return;
      }
      if (operation.response != null) {
        _setState(
          HomeState(
            status: _resolvedStatus(operation.response!),
            response: operation.response,
          ),
        );
        return;
      }
      final response = await repository.analyzePhoto(
        operation.image!,
        locale: 'en-US',
        clarification: operation.clarification,
        operationId: operation.id,
      );
      final completed = operation.completed(response);
      _pending = completed;
      _lastOperation = completed;
      // Remove stored photo bytes once the response is safely journalled.
      await _store(() => operationStore.write(completed));
      _setState(
        HomeState(status: _resolvedStatus(response), response: response),
      );
    } on ApiException catch (e) {
      _setState(HomeState(status: HomeStatus.error, error: e.error));
    } catch (error) {
      if (kDebugMode) debugPrint('Scan recovery failed: ${error.runtimeType}');
      _storageError();
    } finally {
      _busy = false;
    }
  }

  Future<void> retryLastAnalysis() async {
    if (_pending == null) return;
    await _runPending();
  }

  HomeStatus _resolvedStatus(PhotoFoodResponse response) {
    if (response.uiFlags.requiresUserConfirmation) {
      return HomeStatus.awaitingPortion;
    }
    return HomeStatus.loaded;
  }

  Future<bool> confirmPortion(double portionG, {int baseRevision = 0}) async {
    return _confirmPortion(portionG: portionG, baseRevision: baseRevision);
  }

  Future<bool> confirmPortionWithAiEstimate({int baseRevision = 0}) async {
    return _confirmPortion(useAiEstimate: true, baseRevision: baseRevision);
  }

  Future<bool> _confirmPortion({
    double? portionG,
    bool useAiEstimate = false,
    required int baseRevision,
  }) async {
    final response = _state.response;
    if (_busy || response == null) {
      return false;
    }

    _busy = true;
    _setState(
      _state.copyWith(status: HomeStatus.confirmingPortion, clearError: true),
    );
    try {
      final source = _lastOperation ?? _newDraft().completed(response);
      final intent = source
          .completed(response)
          .confirming(
            grams: portionG,
            useEstimate: useAiEstimate,
            revision: baseRevision,
          );
      _pending = intent;
      _lastOperation = intent;
      await _store(() => operationStore.write(intent));
      await _sendConfirmation(intent);
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
    } finally {
      _busy = false;
    }
  }

  Future<void> _sendConfirmation(PendingPhotoOperation intent) async {
    final confirmed = await repository.confirmPortion(
      requestId: intent.response!.requestId,
      portionG: intent.confirmationGrams,
      useAiEstimate: intent.useAiEstimate,
    );
    final completed = intent.completed(confirmed);
    _pending = completed;
    _lastOperation = completed;
    await _store(() => operationStore.write(completed));
    _setState(HomeState(status: HomeStatus.loaded, response: confirmed));
  }

  static String? validatePortionInput(String value) {
    final grams = double.tryParse(value.trim().replaceAll(',', '.'));
    if (grams == null || !grams.isFinite) {
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _setState(HomeState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
