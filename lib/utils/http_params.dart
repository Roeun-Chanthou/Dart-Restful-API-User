// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as p;

import 'validator.dart';

/*
Require package:
- path: 

How to use HttpParams?

1. Create object and load request body
var httpParams = HttpParams();
await httpParams.loadRequest(request);

2. Create validation rule
var error = httpParams.validate(
  {
    'first_name': [RequiredRule(), StringRule()],
    'last_name': [RequiredRule(), StringRule()],
    'image': [
      RequiredRule(),
      FileRule(allowedMimeTypes: ['.png', '.jpeg', '.jpg', '.webp'])
    ]
  },
);

if (error.isNotEmpty) {
  return Response.ok(
    jsonEncode(error),
    headers: {'content-type': 'application/json'},
  );
}

3. Read data from HttpParams
var firstName = httpParams.getString('first_name');
var image = httpParams.getFile('image');
*/

class HttpParams {
  var jsonData = <String, dynamic>{};
  var fileData = <String, HttpFile>{};

  Future<void> loadRequest(Request request) async {
    var form = request.formData();

    if (form != null) {
      var formData = await form.formData.toList();
      for (var data in formData) {
        if (data.filename != null) {
          fileData[data.name] = HttpFile.fromFormData(data);
        } else {
          jsonData[data.name] = await data.part.readString();
        }
      }
    } else {
      var body = await request.readAsString();
      jsonData = jsonDecode(body.isEmpty ? '{}' : body);
    }
  }

  bool has(String key) {
    return jsonData.containsKey(key) || fileData.containsKey(key);
  }

  int getInt(String key, {int defaultValue = 0}) {
    var value = jsonData[key];
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return (jsonData[key] as int?) ?? defaultValue;
  }

  dynamic get(String key) {
    return jsonData[key];
  }

  List<dynamic> getList(String key) {
    var data = jsonData[key];
    if (data is List) {
      return data;
    }
    return jsonDecode(data);
  }

  String getString(String key, {String defaultValue = ''}) {
    return (jsonData[key] as String?) ?? defaultValue;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    var value = jsonData[key];
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return (jsonData[key] as double?) ?? defaultValue;
  }

  int? getIntNullable(String key) {
    return jsonData[key] as int?;
  }

  String? getStringNullable(String key) {
    return (jsonData[key] as String?);
  }

  double? getDoubleNullable(String key) {
    return (jsonData[key] as double?);
  }

  HttpFile? getFile(String key) {
    return fileData[key];
  }

  Map<String, String> validate(Map<String, List<ValidationRule>> rules) {
    //Filter data rules only
    var dataRule = Map<String, List<ValidationRule>>.from(rules);
    dataRule.removeWhere(
      (key, value) {
        var result = value.where((element) {
          if (element case RequiredRule rule) return rule.isFile;
          if (element is FileRule) return true;
          return false;
        }).toList();
        return result.isNotEmpty;
      },
    );

    //Filter file rules only
    var fileRule = Map<String, List<ValidationRule>>.from(rules);
    fileRule.removeWhere(
      (key, value) {
        var result = value.where((element) {
          if (element is FileRule) return false;
          if (element case RequiredRule rule) return rule.isFile;
          return true;
        }).toList();
        return result.isNotEmpty;
      },
    );

    var jsonDataClone = Map<String, dynamic>.from(jsonData);
    //Validate json data
    var errorData = JsonValidator.validate(jsonDataClone, dataRule);

    //Validate json file
    if (fileRule.isNotEmpty) {
      //Filter file data
      var fileRuleKeys = fileRule.keys;
      jsonDataClone.removeWhere((key, value) => !fileRuleKeys.contains(key));
      //Response validation
      var errorFile =
          JsonValidator.validate({...fileData, ...jsonDataClone}, fileRule);
      return {...errorData, ...errorFile};
    }

    return errorData;
  }
}

class HttpFile {
  final String fileName;
  final Future<Uint8List> content;
  final String extension;
  HttpFile({
    required this.fileName,
    required this.extension,
    required this.content,
  });

  HttpFile.fromFormData(FormData data)
      : fileName = data.filename ?? '',
        extension = p.extension(data.filename ?? ''),
        content = data.part.readBytes();

  String get generateFileName {
    return '${DateTime.now().microsecondsSinceEpoch}$extension';
  }
}
