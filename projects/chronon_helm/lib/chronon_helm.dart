import 'dart:convert';

import 'package:chat_color/chat_color.dart';
import 'package:chronon_helm/util/apple_ocr.dart';
import 'package:chronon_helm/util/command.dart';
import 'package:chronon_helm/util/config.dart';
import 'package:chronon_helm/util/file_processor.dart';
import 'package:chronon_helm/util/routing.dart';
import 'package:fast_log/fast_log.dart';
import 'package:precision_stopwatch/precision_stopwatch.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:universal_io/io.dart';

bool _shuttingDown = false;

class ChrononHelmServer implements Routing {
  late final HttpServer server;
  Future<void> start() async {
    PrecisionStopwatch p = PrecisionStopwatch.start();
    _addShutdownHooks();
    await loadHelmConfig();
    server = await serve(_pipeline, InternetAddress.anyIPv4, helmConfig.port);
    verbose("Listening on port ${helmConfig.port}");
    if (Platform.isMacOS) {
      await AppleOCR.ensureInstalled();
    }
    await bootDocker();
    print("");
    print(
      "&aChronon Helm started in ${p.getMilliseconds().round()}ms!".chatColor,
    );
    print("");
    print("@2&f&ln8n&r&7 ........ &9&nhttp://localhost:5678/".chatColor);
    print(
      "@2&f&lqDrant&r&7 ..... &9&nhttp://localhost:6333/dashboard".chatColor,
    );
    print(
      "@2&f&lpostgres&r&7 ... &9&nhttp://localhost:8081&r &7db=&6n8n &7usr=&6postgres &7pass=&6postgres &7server=&6postgres"
          .chatColor,
    );

    print(
      "@2&f&lredis&r&7 ..... &9&nhttp://localhost:8082&r &7connection=&6redis://default@redis:6379"
          .chatColor,
    );
    print("");
  }

  Future<void> bootDocker([int tries = 10]) async {
    verbose("Starting Docker Cluster");

    while (tries-- > 0) {
      try {
        print("Start in ${helmConfig.chronon}");
        print("PWD is ${Directory.current}");
        await shell("docker compose up -d", startIn: helmConfig.chronon);
        success("Docker Cluster is up and running!");
        return;
      } catch (e) {
        try {
          await shell(
            Platform.isWindows
                ? 'start "C:\Program Files\Docker\Docker\Docker Desktop.exe"'
                : Platform.isMacOS
                ? "open -a Docker"
                : "systemctl start docker",
            startIn: helmConfig.chronon,
          );
        } catch (e) {
          error("Failed to launch docker daemon: $e");
        }

        int delay = (11 - tries);
        error(e);
        warn(
          "Docker not ready, retrying in $delay second(s)... ($tries tries left)",
        );
        await Future.delayed(Duration(seconds: delay));
      }
    }
  }

  Future<void> stop() async {
    info("Shutting down Chronon Helm...");
    verbose("Shutting down Docker Cluster");
    await shell("docker compose down", startIn: helmConfig.chronon);
  }

  Future<void> _tryShutdown() async {
    if (_shuttingDown) {
      warn("Shutdown already in progress...");
      return;
    }

    try {
      await stop();
      await server.close(force: true);
      success("Chronon Helm shut down gracefully.");
      exit(0);
    } catch (e) {
      error("Error during shutdown: $e");
      exit(1);
    }
  }

  Handler get _pipeline =>
      Pipeline().addMiddleware(_middleware).addHandler(router.call);

  Middleware get _middleware => createMiddleware(
    requestHandler: _onRequest,
    errorHandler: _onError,
    responseHandler: _onResponse,
  );

  Future<Response> _onError(Object err, StackTrace stackTrace) async {
    error('Request Error: $err');
    error('Stack Trace: $stackTrace');
    return Response.internalServerError();
  }

  Future<Response?> _onRequest(Request request) async => null;

  Future<Response> _onResponse(Response response) async {
    return response;
  }

  void _addShutdownHooks() {
    ProcessSignal.sigint.watch().listen((ProcessSignal signal) {
      warn('Received SIGINT. Shutting down gracefully...');
      _tryShutdown();
    });

    // Handle SIGTERM (e.g., from kill command)
    ProcessSignal.sigterm.watch().listen((ProcessSignal signal) {
      warn('Received SIGTERM. Shutting down gracefully...');
      _tryShutdown();
    });

    ProcessSignal.sighup.watch().listen((ProcessSignal signal) {
      warn('Received SIGHUP. Shutting down gracefully...');
      _tryShutdown();
    });
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
