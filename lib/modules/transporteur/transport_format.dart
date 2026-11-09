/// Règles de saisie, de formatage et de dates du module transporteur.
class TransportFormat {
  TransportFormat._();

  /// Prix en centimes entiers pour éviter les erreurs d'arrondi des décimaux.
  static int enCentimes(double montant) => (montant * 100).round();

  static double depuisCentimes(int centimes) => centimes / 100;

  /// "12,5" ou "12.50" -> 1250 centimes. Null si la saisie est invalide.
  static int? parserMontant(String? saisie) {
    if (saisie == null) return null;
    final texte = saisie.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(texte)) return null;
    return (double.parse(texte) * 100).round();
  }

  /// Entier strictement positif (places, passagers, capacité). Null si invalide.
  static int? parserEntier(String? saisie) {
    final n = int.tryParse(saisie?.trim() ?? '');
    return n == null || n <= 0 ? null : n;
  }

  /// "09:30" ou "9:05" -> (9, 30). Null si invalide.
  static (int, int)? parserHeure(String? saisie) {
    final m = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$')
        .firstMatch(saisie?.trim() ?? '');
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  /// "12.5" -> "12.50 DT" (affichage).
  static String prix(double montant) => '${montant.toStringAsFixed(2)} DT';

  /// Heure d'un instant, au format "09:30".
  static String heure(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Date au format "yyyy-MM-dd" (comparaisons SQL).
  static String jourIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Date et heure locales, sans fuseau, à la minute : "2026-11-15T09:00:00.000".
  static String dateHeureIso(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, d.minute).toIso8601String();

  /// Combine un jour et une heure "HH:mm". Null si l'un des deux manque ou est invalide.
  static DateTime? combiner(DateTime? jour, String? heure) {
    final h = parserHeure(heure);
    if (jour == null || h == null) return null;
    return DateTime(jour.year, jour.month, jour.day, h.$1, h.$2);
  }

  static String? validerMontant(String? v, {bool obligatoire = true}) {
    if (v == null || v.trim().isEmpty) {
      return obligatoire ? 'Montant obligatoire' : null;
    }
    final c = parserMontant(v);
    if (c == null) return 'Montant invalide (ex : 12.50)';
    if (c < 0) return 'Le montant doit être positif';
    return null;
  }

  static String? validerEntier(String? v,
      {String champ = 'Ce nombre', int max = 999}) {
    if (v == null || v.trim().isEmpty) return '$champ est obligatoire';
    final n = parserEntier(v);
    if (n == null) return '$champ doit être un nombre entier positif';
    if (n > max) return '$champ ne peut pas dépasser $max';
    return null;
  }

  static String? validerHeure(String? v) {
    if (v == null || v.trim().isEmpty) return 'Heure obligatoire';
    return parserHeure(v) == null ? 'Heure invalide (ex : 09:30)' : null;
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

  /// Une date ne peut pas être antérieure à aujourd'hui.
  static String? validerDateFuture(DateTime? d) {
    if (d == null) return 'Date obligatoire';
    final aujourdhui = DateTime.now();
    final jour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    if (d.isBefore(jour)) return 'La date ne peut pas être passée';
    return null;
  }

  /// Compare deux villes sans tenir compte de la casse ni des espaces.
  /// Compare deux villes sans tenir compte de la casse, des espaces et des accents
  /// (« Médenine » = « medenine »).
  static bool memeVille(String a, String b) => _cleVille(a) == _cleVille(b);

  static const Map<String, String> _sansAccent = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
  };

  static String _cleVille(String v) => v
      .trim()
      .toLowerCase()
      .split('')
      .map((c) => _sansAccent[c] ?? c)
      .join()
      .replaceAll(RegExp(r'\s+'), ' ');
}
