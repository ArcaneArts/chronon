import 'package:fast_log/fast_log.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';
import 'package:yaml/yaml.dart';

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

Future<void> loadHelmConfig() async {
  File file = File("config.yaml");
  info("Loading config from ${file.absolute.path}");

  if (!file.existsSync()) {
    verbose("Config file not found, creating default config.yaml");
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

    verbose("Default config.yaml created.");
  }

  String content = await file.readAsString();
  dynamic yamlMap = loadYaml(content);
  helmConfig = HelmConfig(
    port: yamlMap['port'] ?? 7097,
    unstructured: yamlMap['unstructured'] ?? 'http://localhost:8001',
    chronon: yamlMap['chronon'] ?? '../../',
  ).sanitized;

  verbose("Unstructured API: ${helmConfig.unstructured}");
  verbose("Chronon Directory: ${Directory(helmConfig.chronon).absolute.path}");
  verbose(
    "Documents Directory: ${Directory(helmConfig.documentsDir).absolute.path}",
  );
}
