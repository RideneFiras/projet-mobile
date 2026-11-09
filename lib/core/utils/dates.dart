/// Format court du UI Kit : « 15 OCT. 2026 ».
String dateCourte(DateTime d) {
  const mois = [
    'JANV.', 'FÉVR.', 'MARS', 'AVR.', 'MAI', 'JUIN',
    'JUIL.', 'AOÛT', 'SEPT.', 'OCT.', 'NOV.', 'DÉC.',
  ];
  final l = d.toLocal();
  return '${l.day} ${mois[l.month - 1]} ${l.year}';
}

/// Date stockée en base : « 2026-10-28 ».
String dateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Minuit du jour donné (sans l'heure).
DateTime dateJour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Nombre de jours entre deux dates (sans tenir compte de l'heure).
int nombreDeJours(DateTime debut, DateTime fin) =>
    dateJour(fin).difference(dateJour(debut)).inDays;

/// Relit une date ISO venant de la base ; null si vide ou invalide.
DateTime? dateDepuisIso(String? texte) {
  if (texte == null || texte.isEmpty) return null;
  final d = DateTime.tryParse(texte);
  return d == null ? null : dateJour(d);
}

/// « 15 OCT. 2026 → 20 OCT. 2026 ».
String periode(DateTime debut, DateTime fin) =>
    '${dateCourte(debut)} → ${dateCourte(fin)}';
