import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

class Utils {
  Utils._();

  static Response response({
    required bool status,
    dynamic data,
    required String message,
  }) {
    if (data is Future) {
      throw Exception('data not support with Future');
    }
    return Response.ok(
      jsonEncode({'status': status, 'message': message, 'data': data}),
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    );
  }

  static String hostAddress(Request request, {List<String>? path}) {
    if (path != null && path.isNotEmpty) {
      /* var previousValue = request.requestedUri.origin;
      for (var element in path) {
        previousValue = '$previousValue$element';
      }
      return previousValue;*/
      return path.fold(request.requestedUri.origin,
          (previousValue, element) => '$previousValue$element');
    }
    return request.requestedUri.origin;
  }
}
