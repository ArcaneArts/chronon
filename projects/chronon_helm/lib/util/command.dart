import 'dart:convert';
import 'dart:io';

import 'package:fast_log/fast_log.dart';

Future<String> shell(String command, {String? startIn}) async {
  String shell;
  List<String> args;

  if (Platform.isWindows) {
    shell = 'cmd';
    args = ['/C', '$command 2>&1'];
  } else {
    shell = '/bin/sh';
    args = ['-c', '$command 2>&1'];
  }

  try {
    Process process = await Process.start(
      shell,
      args,
      workingDirectory: startIn,
    );
    StringBuffer outputBuffer = StringBuffer();
    await Future.wait([
      process.stdout.transform(utf8.decoder).forEach(outputBuffer.write),
      process.stderr.transform(utf8.decoder).forEach(outputBuffer.write),
    ]);
    int exitCode = await process.exitCode;
    verbose("CMD $command -> $exitCode");
    String responseBody = outputBuffer.toString();
    if (exitCode != 0) {
      throw Exception('Command failed with exit code $exitCode\n$responseBody');
    }

    return responseBody;
  } catch (e) {
    throw Exception('Command failed with exit code $exitCode $e');
  }
}
