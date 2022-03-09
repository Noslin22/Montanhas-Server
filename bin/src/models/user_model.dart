import 'dart:convert';

class UserModel {
  final String name;
  final String email;
  final String password;
  final String? id;
  final bool? isAdm;
  final double percent;
  UserModel({
    required this.name,
    required this.email,
    required this.password,
    required this.percent,
    this.isAdm = false,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'id': id,
      'isAdm': isAdm,
      'percent': percent,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      id: map['id'],
      isAdm: map['isAdm'],
      percent: map['percent']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));
}
