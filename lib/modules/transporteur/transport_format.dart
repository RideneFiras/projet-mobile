/// Règles de saisie et de formatage du module transporteur.
class TransportFormat {
  TransportFormat._();

  /// Prix en "fixed-point" : on travaille en centimes entiers pour éviter
  /// les erreurs d'arrondi des nombres décimaux.
  static int enCentimes(double montant) => (montant * 100).round();

  static double depuisCentimes(int centimes) => centimes / 100;

  /// "12,5" ou "12.50" -> 1250 centimes. Null si la saisie est invalide.
  static int? parserMontant(String? saisie) {
    if (saisie == null) return null;
    final texte = saisie.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texte)) return null;
    return (double.parse(texte) * 100).round();
  }

  /// "12.5" -> "12.50 DT" (affichage).
  static String prix(double montant) => '${montant.toStringAsFixed(2)} DT';

  static String? validerMontant(String? v, {bool obligatoire = true}) {
    if ((v == null || v.trim().isEmpty)) {
      return obligatoire ? 'Montant obligatoire' : null;
    }
    final c = parserMontant(v);
    if (c == null) return 'Montant invalide (ex : 12.50)';
    if (c < 0) return 'Le montant doit être positif';
    return null;
  }

  static String? validerVille(String? v, {String champ = 'La ville'}) {
    if (v == null || v.trim().isEmpty) return '$champ est obligatoire';
    if (v.trim().length < 2) return '$champ est trop courte';
    return null;
  }

  /// Règle du cahier des charges : départ différent de l'arrivée.
  static String? validerTrajet(String? depart, String? arrivee) {
    final d = depart?.trim().toLowerCase() ?? '';
    final a = arrivee?.trim().toLowerCase() ?? '';
    if (d.isNotEmpty && d == a) {
      return 'Le départ et l\'arrivée doivent être différents';
    }
    return null;
  }

  /// Une date ne peut pas être antérieure à aujourd'hui (saisie d'une commande).
  static String? validerDateFuture(DateTime? d) {
    if (d == null) return 'Date obligatoire';
    final aujourdhui = DateTime.now();
    final jour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    if (d.isBefore(jour)) return 'La date ne peut pas être passée';
    return null;
  }

  /// Compare deux villes sans tenir compte de la casse ni des espaces.
  static bool memeVille(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
