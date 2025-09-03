import 'package:shelf_router/shelf_router.dart';

abstract class Routing {
  Router get router;

  String get prefix;
}
