import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Stores accident photos as files instead of base64 blobs in Hive.
/// Photo references in AccidentReport.photos can be:
///   - "data:image/jpeg;base64,..." (legacy inline base64)
///   - "file:<uuid>.jpg" (new file-based storage)
class PhotoStorage {
  PhotoStorage._();
  static final instance = PhotoStorage._();

  Directory? _photosDir;

  Future<Directory> _getDir() async {
    if (_photosDir != null) return _photosDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _photosDir = Directory('${appDir.path}/accident_photos');
    if (!await _photosDir!.exists()) {
      await _photosDir!.create(recursive: true);
    }
    return _photosDir!;
  }

  /// Save raw bytes to a file, return the "file:<name>" reference.
  Future<String> savePhoto(Uint8List bytes) async {
    final dir = await _getDir();
    final name = '${_uuid.v4()}.jpg';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return 'file:$name';
  }

  /// Save a legacy base64 data-URI to a file, return the new reference.
  Future<String> migrateBase64(String dataUri) async {
    final b64 = dataUri.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
    final bytes = base64Decode(b64);
    return savePhoto(Uint8List.fromList(bytes));
  }

  /// Load photo bytes from a reference (supports both formats).
  Future<Uint8List?> loadPhoto(String ref) async {
    if (ref.startsWith('file:')) {
      final dir = await _getDir();
      final file = File('${dir.path}/${ref.substring(5)}');
      if (await file.exists()) return file.readAsBytes();
      return null;
    }
    // Legacy base64
    if (ref.startsWith('data:')) {
      final b64 = ref.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
      return Uint8List.fromList(base64Decode(b64));
    }
    return null;
  }

  /// Delete a photo file (no-op for base64 refs).
  Future<void> deletePhoto(String ref) async {
    if (!ref.startsWith('file:')) return;
    final dir = await _getDir();
    final file = File('${dir.path}/${ref.substring(5)}');
    if (await file.exists()) await file.delete();
  }

  /// Returns true if the reference is a legacy base64 data-URI.
  static bool isBase64(String ref) => ref.startsWith('data:');
}
