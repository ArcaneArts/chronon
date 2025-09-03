import 'dart:convert';

import 'package:chronon_helm/util/file_processor.dart';
import 'package:flutter/material.dart' as m;
import 'package:ostrich/ostrich.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yaml/yaml.dart';

class ChrononHelmServer implements Routing {
  late final HttpServer server;
  Future<void> start([int port = 7097]) async {
    server = await serve(_pipeline, InternetAddress.anyIPv4, port);
    print("Listening on port $port");
  }

  Handler get _pipeline =>
      Pipeline().addMiddleware(_middleware).addHandler(router.call);

  Middleware get _middleware => createMiddleware(
    requestHandler: _onRequest,
    errorHandler: _onError,
    responseHandler: _onResponse,
  );

  Future<Response> _onError(Object err, StackTrace stackTrace) async {
    print('Request Error: $err');
    print('Stack Trace: $stackTrace');
    return Response.internalServerError();
  }

  Future<Response?> _onRequest(Request request) async => null;

  Future<Response> _onResponse(Response response) async {
    return response;
  }

  @override
  String get prefix => "/";

  @override
  Router get router => Router()
    ..post("/process", process)
    ..post("/command", command);

  Future<Response> process(Request request) async {
    Map<String, dynamic> b = jsonDecode(await request.readAsString());
    String input = helmConfig.toAbs(b['input']);
    String output = helmConfig.toAbs(b['output']);
    File(output).parent.createSync(recursive: true);

    await FileProcessor.processFile(
      input,
      output,
      compat: b['compat'] == "true",
    );
    return Response.ok('Processed $input to $output');
  }

  Future<Response> command(Request request) async {
    String command;
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || contentType.isEmpty) {
        List<int> bytes = await request.read().fold<List<int>>(
          [],
          (prev, chunk) => prev..addAll(chunk),
        );
        command = utf8.decode(bytes, allowMalformed: true);
      } else {
        command = await request.readAsString();
      }
    } catch (e) {
      return Response(400, body: 'Invalid request body: $e');
    }
    if (command.trim().isEmpty) {
      return Response(400, body: 'Command cannot be empty');
    }

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
      Process process = await Process.start(shell, args);
      StringBuffer outputBuffer = StringBuffer();
      await Future.wait([
        process.stdout.transform(utf8.decoder).forEach(outputBuffer.write),
        process.stderr.transform(utf8.decoder).forEach(outputBuffer.write),
      ]);
      int exitCode = await process.exitCode;
      String responseBody = outputBuffer.toString();
      if (exitCode != 0) {
        return Response(
          500,
          body: 'Command failed with exit code $exitCode\n$responseBody',
        );
      }

      return Response.ok(responseBody);
    } catch (e) {
      return Response(500, body: 'Error executing command: $e');
    }
  }
}

abstract class Routing {
  Router get router;

  String get prefix;
}

extension XRequest on Request {
  String? param(String key) => url.queryParameters[key];
}

Future<void> main() async {
  m.WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      skipTaskbar: true,
      windowButtonVisibility: false,
      backgroundColor: m.Colors.red,
      titleBarStyle: TitleBarStyle.hidden,
      size: m.Size(100, 100),
      minimumSize: m.Size(100, 100),
      maximumSize: m.Size(100, 100),
    ),
    () async {
      await windowManager.setPreventClose(true);
    },
  );

  File file = File("config.yaml");
  print("Loading config from ${file.absolute.path}");

  if (!file.existsSync()) {
    print("Config file not found, creating default config.yaml");
    await file.writeAsString(
      """
# Chronon Helm Configuration

# Port for the Helm server to listen on
port: 7097

# Base URL for the Unstructured API
unstructured: 'http://localhost:8001'

# The base directory of chronon
chronon: '../../'
"""
          .trim(),
    );

    print("Default config.yaml created.");
  }

  String content = await file.readAsString();
  dynamic yamlMap = loadYaml(content);
  helmConfig = HelmConfig(
    port: yamlMap['port'] ?? 7097,
    unstructured: yamlMap['unstructured'] ?? 'http://localhost:8001',
    chronon: yamlMap['chronon'] ?? '../../',
  ).sanitized;

  print("Unstructured API: ${helmConfig.unstructured}");
  print("Chronon Directory: ${Directory(helmConfig.chronon).absolute.path}");
  print(
    "Documents Directory: ${Directory(helmConfig.documentsDir).absolute.path}",
  );

  await runFlutterServer((context) => ChrononHelmServer().start());
}

HelmConfig helmConfig = const HelmConfig();

class HelmConfig {
  final int port;
  final String unstructured;
  final String chronon;

  const HelmConfig({
    this.port = 7097,
    this.chronon = '../../',
    this.unstructured = 'http://localhost:8001',
  });

  String get documentsDir => p.join(chronon, 'documents');
  String toAbs(String relativeDocumentsPath) => File(
    p.join(
      chronon,
      relativeDocumentsPath.startsWith("/")
          ? relativeDocumentsPath.substring(1)
          : relativeDocumentsPath,
    ),
  ).absolute.path;

  HelmConfig get sanitized => HelmConfig(
    port: port,
    unstructured: unstructured,
    chronon: p.normalize(p.absolute(chronon)),
  );
}
