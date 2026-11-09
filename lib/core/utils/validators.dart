/// Validateurs des formulaires (mêmes règles que le cahier des charges).
class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w.+\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  static String? requis(String? v, {String champ = 'Ce champ'}) =>
      (v == null || v.trim().isEmpty) ? '$champ est obligatoire' : null;

  static String? email(String? v) =>
      requis(v, champ: "L'e-mail") ??
      (_email.hasMatch(v!.trim()) ? null : 'Adresse e-mail invalide');

  /// 8 à 15 chiffres, "+" et espaces autorisés (ex : +216 20 123 456).
  static String? telephone(String? v) {
    final r = requis(v, champ: 'Le téléphone');
    if (r != null) return r;
    final chiffres = v!.replaceAll(RegExp(r'[\s+]'), '');
    if (!RegExp(r'^\d{8,15}$').hasMatch(chiffres)) {
      return 'Numéro invalide (8 à 15 chiffres)';
    }
    return null;
  }

  /// 8 caractères minimum, avec au moins une lettre et un chiffre.
  static String? motDePasse(String? v) {
    final r = requis(v, champ: 'Le mot de passe');
    if (r != null) return r;
    if (v!.length < 8) return '8 caractères minimum';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Au moins une lettre et un chiffre';
    }
    return null;
  }
}
