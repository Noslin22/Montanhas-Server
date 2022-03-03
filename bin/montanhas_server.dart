import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'package:uuid/uuid.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'src/config/database.dart';
import 'src/server/auth_service.dart';

// For Google Cloud Run, set _hostname to '0.0.0.0'.
const _hostname = '0.0.0.0';
late Database db;
late AuthService auth;

void main(List<String> args) async {
  var parser = ArgParser()..addOption('port', abbr: 'p');
  var result = parser.parse(args);

  // For Google Cloud Run, we respect the PORT environment variable
  var portStr = result['port'] ?? Platform.environment['PORT'] ?? '8081';
  var port = int.tryParse(portStr);

  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }
  db = Database("bin/src/server/db.json");
  auth = AuthService(key: "ghasjdklgfsdgkljWEDFSD", exp: 3600);
  db.init();

  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(handleRequest);

  var server = await io.serve(handler, _hostname, port);
  print('Serving at http://${server.address.host}:${server.port}');
}

FutureOr<shelf.Response> handleRequest(shelf.Request request) {
  try {
    var mimeType = request.mimeType;
    final method = request.method.toUpperCase();

    if (method == 'GET') {
      if (request.url.pathSegments.last == 'auth') {
        return handleAuth(request);
      } else {
        return handleGet(request);
      }
    } else if (method == 'DELETE') {
      return handleDelete(request);
    } else if (method == 'POST' && mimeType == 'application/json') {
      return handlePost(request);
    } else if (method == 'PUT' && mimeType == 'application/json') {
      return handlePut(request);
    } else if (method == 'PATCH' && mimeType == 'application/json') {
      return handlePut(request);
    } else {
      final body = jsonEncode({
        'error': 'Unsupported request: ${request.method}.',
      });
      return shelf.Response(HttpStatus.methodNotAllowed, body: body);
    }
  } catch (e) {
    final body = jsonEncode({
      'error': 'Exception: $e.',
    });
    return shelf.Response(HttpStatus.internalServerError, body: body);
  }
}

String get getSlash => Platform.isWindows ? '\\' : '/';

Future<shelf.Response> handleAuth(shelf.Request request) async {
  var token = request.headers[HttpHeaders.authorizationHeader];
  if (token == null) {
    return shelf.Response.forbidden(jsonEncode({
      'error': 'Not found token Basic',
    }));
  }

  try {
    var credentials =
        String.fromCharCodes(base64Decode(token.replaceFirst('Basic ', '')))
            .split(':');
    var users = await db.getAll('users');
    Map user = users.firstWhere((element) =>
        element['email'] == credentials[0] &&
        element['password'] == credentials[1]);

    int index = user.keys.toList().indexOf("password");

    List keys = user.keys.toList();
    keys.removeAt(index);
    List values = user.values.toList();
    values.removeAt(index);
    Map newUser = Map.fromIterables(keys, values);

    return shelf.Response.ok(
      jsonEncode({
        'user': newUser,
        'token': auth.generateToken(user['id'].toString()),
        'exp': auth.exp
      }),
      headers: {'content-type': 'application/json'},
    );
  } catch (e) {
    return shelf.Response.forbidden(jsonEncode({'error': 'Forbidden Access'}));
  }
}

bool middlewareJwt(shelf.Request request) {
  if (request.url.pathSegments.isEmpty ||
      auth.scape?.contains(request.url.pathSegments[0]) == true) {
    return true;
  }

  var header = request.headers[HttpHeaders.authorizationHeader];
  if (header == null) {
    return false;
  }

  var token = header.replaceFirst('Bearer ', '');

  var valid = auth.isValid(token, request.url.pathSegments[0]);

  if (valid != null) {
    return false;
  }

  return true;
}

Future<dynamic> getSegment(shelf.Request request) async {
  List segments = request.url.pathSegments;
  if (segments.length == 2) {
    return db.get(segments.first, segments[1].toString());
  } else if (segments.length == 1) {
    return db.getAll(segments[0]);
  } else {
    return db.getProprety(
      segments.first,
      segments[1].toString(),
      segments[2].toString(),
    );
  }
}

Future<shelf.Response> handleGet(shelf.Request request) async {
  if (!middlewareJwt(request)) {
    return shelf.Response.forbidden(jsonEncode({'error': 'middlewareJwt'}));
  }

  try {
    dynamic seg = await getSegment(request);

    if (seg == null) {
      return shelf.Response.notFound(jsonEncode({'error': 'Not found'}));
    } else {
      return shelf.Response.ok(jsonEncode(seg),
          headers: {'content-type': 'application/json'});
    }
  } catch (e) {
    return shelf.Response.notFound(jsonEncode({'error': 'Internal Error. $e'}));
  }
}

Future<shelf.Response> handleSegment(shelf.Request request) async {
  List segments = request.url.pathSegments;

  final key = segments[0];
  if (segments.length == 1) {
    var content = await request.readAsString();
    var data = jsonDecode(content) as Map;
    List<dynamic> seg = await db.getAll(segments[0]);

    if (seg.isEmpty) {
      return shelf.Response.notFound(jsonEncode({'error': 'Not found'}));
    } else {
      data['id'] = Uuid().v1();
      seg.add(data);
      await db.save(key, seg);
      return shelf.Response.ok(jsonEncode(data),
          headers: {'content-type': 'application/json'});
    }
  } else if (segments.length == 3) {
    var content = await request.readAsString();
    var data = jsonDecode(content) as Map;
    List<dynamic> seg = await db.getAll(segments[0]);
    Map prop = seg.firstWhere(
      (element) => element["id"].toString() == segments[1],
    ) as Map;

    if (seg.isEmpty) {
      return shelf.Response.notFound(jsonEncode({'error': 'Not found'}));
    } else {
      data['id'] = Uuid().v1();
      prop.containsKey(segments[2]) ?
      prop[segments[2]].add(data) : prop[segments[2]] = [data];
      var position = seg.indexWhere((element) => element['id'] == prop["id"]);

      prop.forEach((key, value) {
        seg[position][key] = value;
      });
      await db.save(key, seg);
      return shelf.Response.ok(jsonEncode(prop),
          headers: {'content-type': 'application/json'});
    }
  } else {
    return shelf.Response.notFound(
        jsonEncode({'error': 'Provide a collection'}));
  }
}

Future<shelf.Response> handlePost(shelf.Request request) async {
  final key = request.url.pathSegments[0];

  if (request.headers[HttpHeaders.authorizationHeader] != null) {
    if (!middlewareJwt(request)) {
      return shelf.Response.forbidden(jsonEncode({'error': 'Invalid Token'}));
    } else {
      return handleSegment(request);
    }
  } else {
    if (key == "users") {
      try {
        return handleSegment(request);
      } catch (e) {
        return shelf.Response.notFound(
            jsonEncode({'error': 'Internal Error. $e'}));
      }
    } else {
      return shelf.Response.forbidden(jsonEncode({'error': 'Not logged'}));
    }
  }
}

Future<shelf.Response> handleDelete(shelf.Request request) async {
  if (!middlewareJwt(request)) {
    return shelf.Response.forbidden(jsonEncode({'error': 'middlewareJwt'}));
  }
  try {
    final key = request.url.pathSegments[0];
    dynamic seg = await db.getAll(key);

    if (seg == null) {
      return shelf.Response.notFound(jsonEncode({'error': 'Not found'}));
    } else {
      (seg as List).removeWhere(
        (element) => element['id'] == request.url.pathSegments[1],
      );
      await db.save(key, seg);
      return shelf.Response.ok(jsonEncode({'data': 'ok!'}),
          headers: {'content-type': 'application/json'});
    }
  } catch (e) {
    return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Internal Error'}));
  }
}

Future<shelf.Response> handlePut(shelf.Request request) async {
  if (!middlewareJwt(request)) {
    return shelf.Response.forbidden(jsonEncode({'error': 'middlewareJwt'}));
  }

  try {
    var content = await request.readAsString();
    var data = jsonDecode(content) as Map;
    final key = request.url.pathSegments[0];

    dynamic seg = await db.getAll(key);

    if (seg == null) {
      return shelf.Response.notFound(jsonEncode({'error': 'Not found'}));
    } else {
      data['id'] = int.tryParse(request.url.pathSegments[1]) ??
          request.url.pathSegments[1];
      var position =
          (seg as List).indexWhere((element) => element['id'] == data["id"]);

      data.forEach((key, value) {
        seg[position][key] = value;
      });

      await db.save(key, seg);
      return shelf.Response.ok(jsonEncode(data),
          headers: {'content-type': 'application/json'});
    }
  } catch (e) {
    return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Internal Error'}));
  }
}
