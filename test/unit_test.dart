import 'package:flutter_test/flutter_test.dart';
import 'package:projet_mobile/core/utils/password_hasher.dart';
import 'package:projet_mobile/core/utils/validators.dart';
import 'package:projet_mobile/modules/user/role.dart';

void main() {
  group('Validators', () {
    test('e-mail', () {
      expect(Validators.email('sarra@exemple.com'), isNull);
      expect(Validators.email('pas-un-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('mot de passe : 8 caractères, une lettre et un chiffre', () {
      expect(Validators.motDePasse('abc123'), isNotNull); // trop court
      expect(Validators.motDePasse('abcdefgh'), isNotNull); // pas de chiffre
      expect(Validators.motDePasse('12345678'), isNotNull); // pas de lettre
      expect(Validators.motDePasse('voyage2026'), isNull);
    });

    test('téléphone', () {
      expect(Validators.telephone('+216 20 123 456'), isNull);
      expect(Validators.telephone('123'), isNotNull);
      expect(Validators.telephone('abc'), isNotNull);
    });
  });

  test('Hash salé : même mot de passe, sels différents => hash différents', () {
    final s1 = PasswordHasher.genererSel();
    final s2 = PasswordHasher.genererSel();
    expect(s1, isNot(s2));
    final h1 = PasswordHasher.hacher('voyage2026', s1);
    expect(h1.length, 64);
    expect(PasswordHasher.hacher('voyage2026', s2), isNot(h1));
    expect(PasswordHasher.verifier('voyage2026', s1, h1), isTrue);
    expect(PasswordHasher.verifier('mauvais', s1, h1), isFalse);
  });

  test("L'admin n'est pas proposé à l'inscription", () {
    expect(Role.inscription.contains(Role.admin), isFalse);
    expect(Role.depuis('traveller'), Role.traveller);
  });
}
