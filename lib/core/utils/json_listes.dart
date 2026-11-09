import 'dart:convert';

/// Listes de textes stockées dans une colonne TEXT au format JSON
/// (ex : photos = '["https://…/1.jpg","assets/images/2.jpg"]').

/// Relit une liste depuis la base ; liste vide si la valeur est absente ou invalide.
List<String> listeDepuisJson(Object? valeur) {
  if (valeur is! String || valeur.trim().isEmpty) return const [];
  try {
    final decode = jsonDecode(valeur);
    if (decode is List) {
      return [
        for (final e in decode)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ];
    }
  } on FormatException catch (_) {
    // Valeur corrompue : on l'ignore plutôt que de bloquer l'écran.
  }
  return const [];
}

/// Encode une liste pour la base (éléments vides retirés, doublons supprimés).
String listeEnJson(Iterable<String> liste) => jsonEncode([
      ...{
        for (final e in liste)
          if (e.trim().isNotEmpty) e.trim(),
      },
    ]);
