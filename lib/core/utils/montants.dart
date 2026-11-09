/// Montants en dinars : saisie « 12,5 » ou « 12.50 », stockage en nombre à 2 décimales.
class Montants {
  Montants._();

  /// Renvoie le montant en centimes entiers (évite les erreurs d'arrondi),
  /// ou null si la saisie n'est pas un montant valide.
  static int? enCentimes(String? saisie) {
    if (saisie == null) return null;
    final texte = saisie.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texte)) return null;
    return (double.parse(texte) * 100).round();
  }

  /// Montant saisi -> nombre (2 décimales), ou null.
  static double? depuisSaisie(String? saisie) {
    final c = enCentimes(saisie);
    return c == null ? null : c / 100;
  }

  /// Affichage : « 135.00 DT ».
  static String affiche(double montant) => '${montant.toStringAsFixed(2)} DT';

  /// Message d'erreur pour un champ montant, ou null si valide.
  static String? valider(String? v, {bool obligatoire = true, bool positifSeul = true}) {
    if (v == null || v.trim().isEmpty) {
      return obligatoire ? 'Montant obligatoire' : null;
    }
    final c = enCentimes(v);
    if (c == null) return 'Montant invalide (ex : 12.50)';
    if (positifSeul && c < 0) return 'Le montant doit être positif';
    return null;
  }
}
