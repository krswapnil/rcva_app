import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadLocationImage({
    required String reportId,
    required String locationId,
    required int index, // 1..4
    required File file,
  }) async {
    final ref = _storage
        .ref()
        .child('reports/$reportId/locations/$locationId/image_$index.jpg');

    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  /// Optional: delete image by URL (if you later implement "remove photo")
  Future<void> deleteByUrl(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
