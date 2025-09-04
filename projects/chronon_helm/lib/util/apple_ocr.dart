import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chronon_helm/util/config.dart';
import 'package:fast_log/fast_log.dart';
import 'package:json_events/json_events.dart';
import 'package:universal_io/io.dart';

class AppleOCR {
  static String get _portableDir => '${helmConfig.chronon}/data/portable_ocr';
  static String get _appleOcrPath => '$_portableDir/envs/ocr_env/bin/apple-ocr';

  static Future<bool> isInstalled() async {
    return File(_appleOcrPath).existsSync();
  }

  static Future<void> installPortableOcr() async {
    info('Installing portable OCR setup...');
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
    verbose('Pull $installerUrl as $installerName');

    String installerPath = '${Directory.current.path}/$installerName';
    if (!File(installerPath).existsSync()) {
      verbose('Downloading Miniconda installer...');
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

      verbose('Downloaded Installer to $installerPath');
    }

    verbose('Installing to $_portableDir...');
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

    verbose('Accepting Conda ToS for main channel...');
    ProcessResult tosMain = await runWithConda(
      'conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main',
    );
    if (tosMain.exitCode != 0) {
      throw Exception(
        'ToS accept failed for main: stdout=${tosMain.stdout}, stderr=${tosMain.stderr}',
      );
    }

    verbose('Accepting Conda ToS for r channel...');
    ProcessResult tosR = await runWithConda(
      'conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r',
    );
    if (tosR.exitCode != 0) {
      throw Exception(
        'ToS accept failed for r: stdout=${tosR.stdout}, stderr=${tosR.stderr}',
      );
    }

    verbose('Creating ocr_env...');
    ProcessResult createEnvResult = await runWithConda(
      'conda create -n ocr_env python=3.11 -y',
    );
    if (createEnvResult.exitCode != 0) {
      throw Exception(
        'Env creation failed: stdout=${createEnvResult.stdout}, stderr=${createEnvResult.stderr}',
      );
    }

    verbose('Installing poppler...');
    ProcessResult popplerResult = await runWithConda(
      'conda install -c conda-forge poppler -y',
      activate: true,
    );
    if (popplerResult.exitCode != 0) {
      throw Exception(
        'Poppler install failed: stdout=${popplerResult.stdout}, stderr=${popplerResult.stderr}',
      );
    }

    verbose('Installing apple-vision-utils...');
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

    verbose('Portable installation complete.');
  }

  static Future<void> ensureInstalled() async {
    verbose("Checking miniconda installation...");
    if (!await isInstalled()) {
      warn('Portable OCR not found, installing... (~2gb)');
      await installPortableOcr();
      success('Portable OCR installation complete.');
    }
  }

  static Future<void> performOcr(String pdfPath, String destPath) async {
    if (!File(pdfPath).existsSync()) {
      throw Exception('PDF file not found at $pdfPath');
    }

    final ocrProcess = await Process.start(_appleOcrPath, [
      '-p',
      '-j',
      '--lang',
      'en-US',
      // '--recognition-level',
      // 'accurate',
      // '--language-correction',
      // 'true',
      pdfPath,
    ]);

    StreamSubscription<String> stderrSubscription = ocrProcess.stderr
        .transform(utf8.decoder)
        .listen((data) {
          error('OCR stderr: $data');
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
  }
}
