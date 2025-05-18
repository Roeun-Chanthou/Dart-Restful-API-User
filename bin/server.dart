import 'dart:io';

import 'package:restful_api_user/connections/connection_postgres.dart';
import 'package:restful_api_user/controller/user_controller_pg.dart';
import 'package:restful_api_user/utils/global.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_hotreload/shelf_hotreload.dart';
import 'package:shelf_router/shelf_router.dart';

final _router =
    Router()
      ..get('/user', UserControllerPostgres.select)
      ..get('/user/profile/<fileName>', UserControllerPostgres.selectUserImage)
      ..delete('/user/delete/<id>', UserControllerPostgres.delete)
      ..put('/user/update/<id>', UserControllerPostgres.update)
      ..post('/user/create', UserControllerPostgres.create);

void main(List<String> args) async {
  await ConnectionPostgres.init();
  final ip = InternetAddress.anyIPv4;

  final handler = Pipeline().addMiddleware(logRequests()).addHandler((request) {
    Global.request = request;
    return _router.call(request);
  });

  withHotreload(() async {
    final port = int.parse(Platform.environment['PORT'] ?? '8080');
    final server = await serve(handler, ip, port);
    print('Server listening on port ${server.port}');
    return server;
  });
}
