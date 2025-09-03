import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:json_events/json_events.dart';
import 'package:universal_io/io.dart';

String _portableDir = '${Platform.environment['HOME']!}/.chronon/portable_ocr';
String _appleOcrPath = '$_portableDir/envs/ocr_env/bin/apple-ocr';

class AppleOCR {
  static Future<bool> isInstalled() async {
    return File(_appleOcrPath).existsSync();
  }

  static Future<void> _installPortableOcr() async {
    print('Installing portable OCR setup...');
    ProcessResult archResult = await Process.run('uname', ['-m']);
    if (archResult.exitCode != 0) {
      throw Exception('Failed to detect architecture: ${archResult.stderr}');
    }
    String arch = archResult.stdout.trim();
    String installerUrl;
    String installerName;

    if (arch == 'arm64') {
      installerUrl =
          'https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh';
      installerName = 'Miniconda3-latest-MacOSX-arm64.sh';
    } else if (arch == 'x86_64') {
      installerUrl =
          'https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh';
      installerName = 'Miniconda3-latest-MacOSX-x86_64.sh';
    } else {
      throw Exception('Unsupported architecture: $arch');
    }

    String installerPath = Directory.current.path + '/' + installerName;
    if (!File(installerPath).existsSync()) {
      print('Downloading Miniconda installer...');
      ProcessResult downloadResult = await Process.run('curl', [
        '-L',
        '-o',
        installerName,
        installerUrl,
      ]);
      if (downloadResult.exitCode != 0) {
        throw Exception(
          'Download failed: stdout=${downloadResult.stdout}, stderr=${downloadResult.stderr}',
        );
      }
    }

    print('Installing to $_portableDir...');
    ProcessResult installResult = await Process.run('bash', [
      installerName,
      '-b',
      '-p',
      _portableDir,
    ]);
    if (installResult.exitCode != 0) {
      throw Exception(
        'Installation failed: stdout=${installResult.stdout}, stderr=${installResult.stderr}',
      );
    }

    Future<ProcessResult> runWithConda(
      String command, {
      bool activate = false,
    }) async {
      String fullCommand = 'source $_portableDir/etc/profile.d/conda.sh';
      if (activate) {
        fullCommand += ' && conda activate ocr_env';
      }
      fullCommand += ' && $command';
      return await Process.run('bash', ['-c', fullCommand]);
    }

    print('Accepting ToS for main channel...');
    ProcessResult tosMain = await runWithConda(
      'conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main',
    );
    if (tosMain.exitCode != 0) {
      throw Exception(
        'ToS accept failed for main: stdout=${tosMain.stdout}, stderr=${tosMain.stderr}',
      );
    }

    print('Accepting ToS for r channel...');
    ProcessResult tosR = await runWithConda(
      'conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r',
    );
    if (tosR.exitCode != 0) {
      throw Exception(
        'ToS accept failed for r: stdout=${tosR.stdout}, stderr=${tosR.stderr}',
      );
    }

    print('Creating ocr_env...');
    ProcessResult createEnvResult = await runWithConda(
      'conda create -n ocr_env python=3.11 -y',
    );
    if (createEnvResult.exitCode != 0) {
      throw Exception(
        'Env creation failed: stdout=${createEnvResult.stdout}, stderr=${createEnvResult.stderr}',
      );
    }

    print('Installing poppler...');
    ProcessResult popplerResult = await runWithConda(
      'conda install -c conda-forge poppler -y',
      activate: true,
    );
    if (popplerResult.exitCode != 0) {
      throw Exception(
        'Poppler install failed: stdout=${popplerResult.stdout}, stderr=${popplerResult.stderr}',
      );
    }

    print('Installing apple-vision-utils...');
    ProcessResult pipResult = await runWithConda(
      'pip install apple-vision-utils',
      activate: true,
    );
    if (pipResult.exitCode != 0) {
      throw Exception(
        'Pip install failed: stdout=${pipResult.stdout}, stderr=${pipResult.stderr}',
      );
    }

    if (!File(_appleOcrPath).existsSync()) {
      throw Exception(
        'Installation completed but apple-ocr not found at $_appleOcrPath',
      );
    }

    print('Portable installation complete.');
  }

  static Future<void> performOcr(String pdfPath, String destPath) async {
    if (!File(pdfPath).existsSync()) {
      throw Exception('PDF file not found at $pdfPath');
    }

    if (!await isInstalled()) {
      await _installPortableOcr();
    }

    print('Running OCR on $pdfPath...');
    final ocrProcess = await Process.start(_appleOcrPath, [
      '-p',
      '-j',
      '--lang',
      'en-US',
      pdfPath,
    ]);

    StreamSubscription<String> stderrSubscription = ocrProcess.stderr
        .transform(utf8.decoder)
        .listen((data) {
          print('OCR stderr: $data');
        });

    IOSink sink = File(destPath).openWrite();
    JsonEvent? le;

    await for (JsonEvent event
        in ocrProcess.stdout
            .transform(utf8.decoder)
            .transform(const JsonEventDecoder())
            .flatten()) {
      if (le != null &&
          le.type == JsonEventType.propertyName &&
          le.value == "text" &&
          event.type == JsonEventType.propertyValue) {
        sink.writeln(event.value ?? "");
      }

      le = event;
    }

    await sink.flush();
    await sink.close();
    await stderrSubscription.cancel();

    final exitCode = await ocrProcess.exitCode;
    if (exitCode != 0) {
      throw Exception('OCR failed with exit code $exitCode');
    }

    print('OCR complete. Output saved to $destPath');
  }
}
