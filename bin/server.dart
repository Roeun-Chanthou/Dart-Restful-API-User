import 'dart:io';

import 'package:restful_api_user/connections/connection_postgres.dart';
import 'package:restful_api_user/controller/user_controller_pg.dart';
import 'package:restful_api_user/utils/global.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_hotreload/shelf_hotreload.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

final _router =
    Router()
      ..get('/api/user', UserControllerPostgres.select)
      ..get('/api/user/<id>', UserControllerPostgres.selectUserById)
      ..get(
        '/api/user/profile/<fileName|.*>',
        UserControllerPostgres.selectUserImage,
      )
      ..delete('/api/user/delete/<id>', UserControllerPostgres.delete)
      ..put('/api/user/update/<id>', UserControllerPostgres.update)
      ..post('/api/user/create', UserControllerPostgres.create);

void main(List<String> args) async {
  await ConnectionPostgres.init();

  final ip = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final webHandler = createStaticHandler(
    'web/views',
    defaultDocument: 'index.html',
  );

  final publicHandler = createStaticHandler(
    'public',
    defaultDocument: 'index.html',
  );

  final handler = Pipeline().addMiddleware(logRequests()).addHandler((
    request,
  ) async {
    Global.request = request;

    if (request.url.path.startsWith('api/')) {
      return _router(request);
    }

    if (request.url.path.startsWith('public/')) {
      return publicHandler(request);
    }

    return webHandler(request);
  });

  final imageDir = Directory('public/images/users');
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  withHotreload(() async {
    final server = await serve(handler, ip, port);
    print('✅ Server running at http://localhost:8080');
    print('📁 Serving static files from:');
    print('   - web/');
    print('   - public/');
    return server;
  });
}
