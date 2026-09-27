import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

enum PickSource { camera, gallery }

abstract class PhotoPicker {
  Future<XFile?> pick(PickSource source);
}

abstract class RecoverablePhotoPicker implements PhotoPicker {
  Future<XFile?> recoverLostImage();
}

class ImagePickerPhotoPicker implements RecoverablePhotoPicker {
  final ImagePicker _imagePicker;

  ImagePickerPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  @override
  Future<XFile?> recoverLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final lost = await _imagePicker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
    return lost.files?.firstOrNull;
  }

  @override
  Future<XFile?> pick(PickSource source) {
    switch (source) {
      case PickSource.camera:
        // Avoid extra recompression/resizing on capture path to reduce return lag.
        return _imagePicker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
        );
      case PickSource.gallery:
        return _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
    }
  }
}
