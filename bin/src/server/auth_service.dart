import 'package:jaguar_jwt/jaguar_jwt.dart';

class AuthService {
  final String key;
  final int exp;
  final List<String>? aud;
  final List<String>? scape;

  AuthService({
    required this.key,
    required this.exp,
    this.aud,
    this.scape,
  });

  String generateToken(int id) {
    final claimSet = JwtClaim(subject: '$id', issuer: 'dartio', maxAge: Duration(seconds: exp));

    return issueJwtHS256(claimSet, key);
  }

  String? isValid(String token, String route) {
    try {
      if (scape?.contains(route) == true) {
        return null;
      }
      final decClaimSet = verifyJwtHS256Signature(token, key);
      decClaimSet.validate(issuer: 'dartio');
      return null;
    } on JwtException catch (e) {
      return e.message;
    }
  }
}
