import 'dart:io';

import 'package:chronon_helm/util/apple_ocr.dart';
import 'package:chronon_helm/util/unstructured.dart';

class FileProcessor {
  static Future<void> processFile(
    String input,
    String output, {
    bool compat = false,
  }) async {
    try {
      return switch ((
        getExtension(input),
        Platform.isMacOS && !compat ? 'a' : 'x',
      )) {
        ('pdf', 'a') => AppleOCR.performOcr(input, output),
        _ => throw Exception(
          "No OCR method available for this platform or file type",
        ),
      };
    } catch (_) {
      return UnstructuredProcessor.callUnstructuredApi(input, output);
    }
  }

  static String getExtension(String path) {
    return path.split('.').last.toLowerCase();
  }
}
