import 'dart:convert';
import 'dart:io';

import 'package:chronon_helm/main.dart';
import 'package:http/http.dart' as http;
import 'package:json_events/json_events.dart';

class UnstructuredProcessor {
  static Future<void> callUnstructuredApi(
    String inputPath,
    String outputPath,
  ) async {
    var apiUrl = Uri.parse('${helmConfig.unstructured}/general/v0/general');

    var request = http.MultipartRequest('POST', apiUrl);
    request.headers['accept'] = 'application/json';
    request.headers['Content-Type'] = 'multipart/form-data';
    request.files.add(await http.MultipartFile.fromPath('files', inputPath));
    request.fields['strategy'] = 'hi_res';

    var streamedResponse = await request.send();
    if (streamedResponse.statusCode != 200) {
      var errorBody = await streamedResponse.stream.bytesToString();
      throw Exception(
        'API call failed: ${streamedResponse.statusCode} - $errorBody',
      );
    }

    File o = File(outputPath);
    IOSink s = o.openWrite();
    JsonEvent? le;

    await for (JsonEvent event
        in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(JsonEventDecoder())
            .flatten()) {
      if (le != null &&
          le.type == JsonEventType.propertyName &&
          le.value == "text" &&
          event.type == JsonEventType.propertyValue) {
        s.writeln(event.value ?? "");
      }

      le = event;
    }

    await s.flush();
    await s.close();
    print('Output written to $outputPath');
  }
}
