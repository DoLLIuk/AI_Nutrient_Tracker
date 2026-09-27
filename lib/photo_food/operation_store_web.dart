import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pending_operation.dart';

class DurablePhotoOperationStore implements PhotoOperationStore {
  static const _key = 'photo_food.pending_operation.v1';
  @override
  Future<PendingPhotoOperation?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null
        ? null
        : PendingPhotoOperation.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          );
  }

  @override
  Future<void> write(PendingPhotoOperation operation) async {
    final stored = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(await operation.toJson()),
    );
    if (!stored) throw StateError('Could not save scan');
  }

  @override
  Future<void> clear() async {
    if (!await (await SharedPreferences.getInstance()).remove(_key)) {
      throw StateError('Could not clear saved scan');
    }
  }
}
