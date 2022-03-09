import 'dart:collection';
import 'dart:convert' show jsonEncode, jsonDecode;
import 'dart:io';

import 'package:firebase_dart/firebase_dart.dart';

import '../../configurations.dart';
import '../models/question_model.dart';
import '../models/user_model.dart';

abstract class IDatabase {
  Future init();
  Future save(String key, dynamic seg);
  Future<List> getAll(String query);
  Future<Map<String, dynamic>> get(String query, String id);
  Future<dynamic> getProprety(String query, String id, String proprety);
}

class Database implements IDatabase {
  late DatabaseReference ref;

  Database();

  @override
  Future init() async {
    late FirebaseApp app;

    try {
      app = Firebase.app();
    } catch (e) {
      app = await Firebase.initializeApp(
          options: FirebaseOptions.fromMap(Configuration.firebaseConfig));
    }

    final db =
        FirebaseDatabase(app: app, databaseURL: Configuration.databaseUrl);
    ref = db.reference();
  }

  @override
  Future<List> getAll(String query) async {
    final db = ref.child(query);
    List<Map> value = [];
    await db.once().then((v) {
      (v.value as Map).values.toList().forEach(
        (element) {
          switch (query) {
            case "users":
              // print(UserModel.fromMap(element).toJson());
              value.add(jsonDecode(UserModel.fromMap(element).toJson()));
              break;
            case "questions":
              value.add(jsonDecode(QuestionModel.fromMap(element).toJson()));
              break;
          }
        },
      );
    });
    return value;
  }

  @override
  Future<Map<String, dynamic>> get(String query, String id) async {
    var db = await getAll(query);
    return db.firstWhere((element) => element['id'].toString() == id);
  }

  @override
  Future<dynamic> getProprety(String query, String id, String proprety) async {
    var db = await getAll(query);
    return db.firstWhere((element) => element['id'].toString() == id)[proprety];
  }

  @override
  Future save(String key, dynamic seg) async {
    final db = ref.child(key);
    db.set(seg);
    await db.set(seg);
  }

  @override
  String toString() => ref.toString();
}
