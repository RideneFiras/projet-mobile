/// Niveau de séjour sur place (hors billet) : budget journalier FIXE, calculé en code.
enum Confort {
  economie('economie', 'Économe', 80),
  confortable('confortable', 'Confortable', 150),
  premium('premium', 'Premium', 300);

  const Confort(this.valeur, this.libelle, this.parJour);

  final String valeur;
  final String libelle;

  /// Dinars par jour (valeurs indicatives de démonstration).
  final double parJour;

  static Confort depuis(String valeur) => Confort.values
      .firstWhere((c) => c.valeur == valeur, orElse: () => Confort.confortable);
}

/// Répartition du budget de séjour (part du total). Calculée en code, jamais par l'IA.
const List<(String, double)> repartitionSejour = [
  ('Hébergement', 0.45),
  ('Repas', 0.25),
  ('Activités', 0.20),
  ('Transport local', 0.10),
];

class JourPlan {
  final int jour;
  final String titre;
  final String matin;
  final String apresMidi;
  final String soir;

  const JourPlan({
    required this.jour,
    required this.titre,
    required this.matin,
    required this.apresMidi,
    required this.soir,
  });
}

/// Itinéraire jour par jour, produit par le modèle puis VALIDÉ ici avant tout affichage.
class Itineraire {
  final List<JourPlan> jours;
  final String conseil;

  const Itineraire({required this.jours, required this.conseil});

  /// Lance une FormatException si la réponse n'a pas la forme attendue.
  factory Itineraire.depuisJson(Object? brut) {
    if (brut is! Map) throw const FormatException('objet attendu');
    final liste = brut['jours'];
    if (liste is! List || liste.isEmpty) {
      throw const FormatException('liste de jours manquante');
    }
    final jours = <JourPlan>[];
    for (var i = 0; i < liste.length; i++) {
      final j = liste[i];
      if (j is! Map) throw const FormatException('jour invalide');
      String champ(String cle) {
        final x = j[cle];
        if (x is! String || x.trim().isEmpty) {
          throw FormatException('champ manquant : $cle');
        }
        return x.trim();
      }

      jours.add(JourPlan(
        jour: i + 1,
        titre: champ('titre'),
        matin: champ('matin'),
        apresMidi: champ('apres_midi'),
        soir: champ('soir'),
      ));
    }
    final c = brut['conseil'];
    return Itineraire(jours: jours, conseil: c is String ? c.trim() : '');
  }

  Map<String, Object?> toJson() => {
    'jours': [
      for (final j in jours)
        {
          'titre': j.titre,
          'matin': j.matin,
          'apres_midi': j.apresMidi,
          'soir': j.soir,
        },
    ],
    'conseil': conseil,
  };
}
