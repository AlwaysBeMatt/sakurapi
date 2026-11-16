import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/errors.dart';

/// Menyimpan dan membuka file teks. Dipisah supaya test bisa memakai versi palsu.
abstract class FileService {
  /// true jika pemilih file mengembalikan lokasi simpan, false jika dibatalkan.
  Future<bool> saveText({
    required String fileName,
    required String content,
    String dialogTitle = 'Simpan file',
  });

  /// Isi teks file yang dipilih, atau null jika dibatalkan.
  Future<String?> pickText();
}

class PickerFileService implements FileService {
  const PickerFileService();

  static const _maxBytes = 20 * 1024 * 1024;

  @override
  Future<bool> saveText({
    required String fileName,
    required String content,
    String dialogTitle = 'Simpan file',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
    );
    return result != null;
  }

  @override
  Future<String?> pickText() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxBytes) {
      throw const ValidationException('File terlalu besar untuk backup SakuRapi.');
    }
    return utf8.decode(bytes);
  }
}

final fileServiceProvider = Provider<FileService>(
  (ref) => const PickerFileService(),
);