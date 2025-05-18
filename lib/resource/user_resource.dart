import 'package:shelf/shelf.dart';

class UserResource {
  UserResource._();

  static Map<String, dynamic> mapData(
    Map<String, dynamic> data,
    Request request,
  ) {
    var imageUrl = '';
    if (data['image'] != null && data['image'].toString().isNotEmpty) {
      final host = request.requestedUri.origin;
      var imageName = data['image'];
      if (imageName is List) {
        imageName = String.fromCharCodes(imageName.cast<int>());
      }
      imageUrl = '$host/user/profile/$imageName';
    }
    return {
      'id': data['id'],
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'image': imageUrl,
    };
  }

  static List<Map<String, dynamic>> fromCollection(
    List<Map<String, dynamic>> data,
    Request request,
  ) {
    return data.map((e) => mapData(e, request)).toList();
  }
}
