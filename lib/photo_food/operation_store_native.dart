import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'pending_operation.dart';

class DurablePhotoOperationStore implements PhotoOperationStore {
  final Future<Directory> Function() supportDirectory;
  DurablePhotoOperationStore({Future<Directory> Function()? supportDirectory})
    : supportDirectory = supportDirectory ?? getApplicationSupportDirectory;
  Future<File> _file() async =>
      File('${(await supportDirectory()).path}/pending_photo.json');
  @override
  Future<PendingPhotoOperation?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return PendingPhotoOperation.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(PendingPhotoOperation operation) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Keep image bytes outside JSON: small journal updates never re-encode a photo.
    final photo = File('${file.parent.path}/pending_${operation.id}.image');
    if (operation.image != null && !await photo.exists()) {
      final photoTemp = File('${photo.path}.tmp');
      await operation.image!.saveTo(photoTemp.path);
      await photoTemp.rename(photo.path);
    }
    final json = await operation.toJson(includeImage: false);
    if (operation.image != null) json['imagePath'] = photo.path;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
    // The result is durable before removing the recoverable image.
    if (operation.image == null && await photo.exists()) await photo.delete();
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await file.delete();
      final id = json['id'] as String;
      if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
        final photo = File('${file.parent.path}/pending_$id.image');
        if (await photo.exists()) await photo.delete();
      }
    }
  }
}
