import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Mot de passe stocké sous forme SHA-256(sel + mot de passe),
/// avec un sel aléatoire propre à chaque compte.
class PasswordHasher {
  PasswordHasher._();

  static String genererSel() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hacher(String motDePasse, String sel) =>
      sha256.convert(utf8.encode('$sel$motDePasse')).toString();

  static bool verifier(String motDePasse, String sel, String hashAttendu) =>
      hacher(motDePasse, sel) == hashAttendu;
}
