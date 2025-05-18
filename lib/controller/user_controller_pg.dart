import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:restful_api_user/connections/connection_postgres.dart';
import 'package:restful_api_user/resource/user_resource.dart';
import 'package:restful_api_user/utils/http_params.dart';
import 'package:restful_api_user/utils/validator.dart';
import 'package:shelf/shelf.dart';

class UserControllerPostgres {
  UserControllerPostgres._();
  static const String tableName = 'tbl_user';
  static const imagesDirectory = "public/images/users/";

  static Future<Response> select(Request request) async {
    try {
      var params = request.url.queryParameters;
      var page = int.parse(params['page'] ?? '0');
      var perPage = int.parse(params['per_page'] ?? '10');

      var offset = page * perPage;

      var result = await ConnectionPostgres.db.mappedResultsQuery(
        '''
    SELECT 
      id::integer,
      first_name, 
      last_name, 
      image 
    FROM $tableName 
    ORDER BY id ASC  -- Changed from DESC to ASC
    OFFSET @offset LIMIT @limit
    ''',
        substitutionValues: {'offset': offset, 'limit': perPage},
      );

      var users = result.map((row) => row[tableName]!).toList();

      return Response.ok(
        jsonEncode(
          UserResource.fromCollection(
            users.cast<Map<String, dynamic>>(),
            request,
          ),
        ),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stack) {
      print('Select users error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Failed to fetch users',
        }),
      );
    }
  }

  static Future<Response> update(Request request, String userId) async {
    final id = int.tryParse(userId);
    if (id == null) {
      return Response.badRequest(
        body: jsonEncode({
          'status': 'error',
          'message': 'Invalid user ID format',
        }),
      );
    }

    var httpParams = HttpParams();
    await httpParams.loadRequest(request);

    var error = httpParams.validate({
      'first_name': [RequiredRule(), StringRule()],
      'last_name': [RequiredRule(), StringRule()],
    });

    if (error.isNotEmpty) {
      return Response.badRequest(body: jsonEncode(error));
    }

    try {
      var result = await ConnectionPostgres.db.query(
        'SELECT * FROM $tableName WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (result.isEmpty) {
        return Response.ok(
          jsonEncode({'status': 'false', 'message': 'User Not Found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      var existingUser = {
        'id': result.first[0],
        'first_name': result.first[1],
        'last_name': result.first[2],
        'image': result.first[3],
      };

      String firstName = httpParams.getString('first_name');
      String lastName = httpParams.getString('last_name');
      String? imageName;

      if (httpParams.getFile('image') case HttpFile image) {
        imageName = image.generateFileName;
        final imagePath = '$imagesDirectory$imageName';

        await Directory(imagesDirectory).create(recursive: true);

        var oldImageName = existingUser['image'];
        if (oldImageName != null && oldImageName.toString().isNotEmpty) {
          var oldImageFile = File('$imagesDirectory$oldImageName');
          if (await oldImageFile.exists()) {
            await oldImageFile.delete();
          }
        }

        await File(imagePath).writeAsBytes(await image.content);
      }

      var updateResult = await ConnectionPostgres.db.execute(
        '''
      UPDATE $tableName 
      SET first_name = @firstName, last_name = @lastName
      ${imageName != null ? ', image = @image' : ''}
      WHERE id = @id
      ''',
        substitutionValues: {
          'id': id,
          'firstName': firstName,
          'lastName': lastName,
          if (imageName != null) 'image': imageName,
        },
      );

      if (updateResult == 0) {
        return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'Failed to update user',
          }),
        );
      }

      var updatedResult = await ConnectionPostgres.db.query(
        'SELECT * FROM $tableName WHERE id = @id',
        substitutionValues: {'id': id},
      );

      var updatedUser = {
        'id': updatedResult.first[0],
        'first_name': updatedResult.first[1],
        'last_name': updatedResult.first[2],
        'image': updatedResult.first[3],
      };

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'User updated successfully',
          'data': UserResource.mapData(updatedUser, request),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Update user error: $e$stack');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unexpected server error occurred',
          'details': e.toString(),
        }),
      );
    }
  }

  static Future<Response> delete(Request request, String userId) async {
    final id = int.tryParse(userId);
    if (id == null) {
      return Response.badRequest(
        body: jsonEncode({
          'status': 'error',
          'message': 'Invalid user ID format',
        }),
      );
    }

    try {
      var existingUser = await ConnectionPostgres.db.query(
        'SELECT * FROM $tableName WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (existingUser.isEmpty) {
        return Response.ok(
          jsonEncode({'status': 'error', 'message': 'User not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      var imageName = existingUser.first[3];
      if (imageName.toString().isNotEmpty) {
        final imageFile = File(imagesDirectory + imageName.toString());
        print('Attempting to delete image at: ${imageFile.path}');

        try {
          if (await imageFile.exists()) {
            await imageFile.delete();
            print('Image deleted successfully');
          } else {
            print('Image file does not exist at: ${imageFile.path}');
          }
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      var deleteResult = await ConnectionPostgres.db.query(
        'DELETE FROM $tableName WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (deleteResult == 0) {
        return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'Failed to delete user',
          }),
        );
      }

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'User deleted successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Delete user error: \$e\n\$stack');
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unexpected server error occurred',
        }),
      );
    }
  }

  static Future<Response> create(Request request) async {
    var httpParams = HttpParams();
    await httpParams.loadRequest(request);

    var error = httpParams.validate({
      'first_name': [RequiredRule(), StringRule()],
      'last_name': [RequiredRule(), StringRule()],
      'image': [
        RequiredRule(isFile: true),
        FileRule(allowedMimeTypes: ['.png', '.jpeg', '.jpg', '.webp']),
      ],
    });

    if (error.isNotEmpty) {
      return Response.badRequest(body: jsonEncode(error));
    }

    try {
      String firstName = httpParams.getString('first_name');
      String lastName = httpParams.getString('last_name');
      String imageName = '';

      if (httpParams.getFile('image') case HttpFile image) {
        imageName = image.generateFileName;
        final imagePath = '$imagesDirectory$imageName';
        await Directory(imagesDirectory).create(recursive: true);
        await File(imagePath).writeAsBytes(await image.content);
      }

      var existingUser = await ConnectionPostgres.db.query(
        'SELECT * FROM $tableName WHERE first_name = @firstName AND last_name = @lastName',
        substitutionValues: {'firstName': firstName, 'lastName': lastName},
      );

      if (existingUser.isNotEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'error': 'User already exists with same first and last name',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      var insertResult = await ConnectionPostgres.db.query(
        'INSERT INTO $tableName (first_name, last_name, image) VALUES (@firstName, @lastName, @image) RETURNING id',
        substitutionValues: {
          'firstName': firstName,
          'lastName': lastName,
          'image': imageName,
        },
      );

      if (insertResult.isEmpty) {
        return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'Failed to insert user',
          }),
        );
      }

      int insertedId = insertResult.first[0];

      var userData = await ConnectionPostgres.db.query(
        'SELECT * FROM $tableName WHERE id = @id',
        substitutionValues: {'id': insertedId},
      );

      if (userData.isEmpty) {
        return Response.internalServerError(
          body: jsonEncode({
            'status': 'error',
            'message': 'User created but not found',
          }),
        );
      }

      var mappedUser = {
        'id': userData.first[0],
        'first_name': userData.first[1],
        'last_name': userData.first[2],
        'image': userData.first[3],
      };

      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'User created successfully',
          'data': UserResource.mapData(mappedUser, request),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Create user error: $e');
      print(stack);
      return Response.internalServerError(
        body: jsonEncode({
          'status': 'error',
          'message': 'Unexpected server error occurred',
          'details': e.toString(),
        }),
      );
    }
  }

  static Future<Response> selectUserImage(
    Request request,
    String fileName,
  ) async {
    var file = File("public/images/users/$fileName");
    if (!file.existsSync()) {
      return Response.notFound('File not found');
    }

    return Response.ok(
      await file.readAsBytes(),
      headers: {
        'content-type': lookupMimeType(fileName) ?? 'application/octet-stream',
      },
    );
  }
}
