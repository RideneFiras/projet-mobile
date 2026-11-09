/// Tarification dynamique commune à la location et à l'hébergement.
/// Chaque unité facturée (jour de location ou nuit d'hôtel) part du prix de base,
/// majoré le week-end (samedi, dimanche) et en haute saison (juillet, août) ;
/// une remise s'applique au total quand la durée atteint [seuilLongueDuree] unités.
class ReglesTarif {
  /// Pourcentages : 10 = +10 % ; la remise se soustrait.
  final double majorationWeekend;
  final double majorationSaison;
  final double remiseLongueDuree;
  final int seuilLongueDuree;

  /// Mois de haute saison (1 = janvier).
  static const Set<int> moisHauteSaison = {7, 8};

  const ReglesTarif({
    this.majorationWeekend = 0,
    this.majorationSaison = 0,
    this.remiseLongueDuree = 0,
    this.seuilLongueDuree = 7,
  });

  bool get estFixe => majorationWeekend == 0 && majorationSaison == 0 && remiseLongueDuree == 0;

  static bool estWeekend(DateTime jour) =>
      jour.weekday == DateTime.saturday || jour.weekday == DateTime.sunday;

  static bool estHauteSaison(DateTime jour) => moisHauteSaison.contains(jour.month);

  /// Pourcentages valides : majorations 0 à 200 %, remise 0 à 90 %.
  String? verifier() {
    if (majorationWeekend < 0 || majorationWeekend > 200 ||
        majorationSaison < 0 || majorationSaison > 200) {
      return 'Majorations entre 0 et 200 %';
    }
    if (remiseLongueDuree < 0 || remiseLongueDuree > 90) return 'Remise entre 0 et 90 %';
    return null;
  }

  /// Détail du prix pour les unités [jours] (une date par jour ou par nuit facturé).
  DetailTarif calculer(double prixBase, List<DateTime> jours) {
    var base = 0.0;
    var weekend = 0.0;
    var saison = 0.0;
    var nbWeekend = 0;
    var nbSaison = 0;
    for (final j in jours) {
      base += prixBase;
      if (estWeekend(j)) {
        weekend += prixBase * majorationWeekend / 100;
        nbWeekend++;
      }
      if (estHauteSaison(j)) {
        saison += prixBase * majorationSaison / 100;
        nbSaison++;
      }
    }
    final avantRemise = base + weekend + saison;
    final remise = jours.length >= seuilLongueDuree ? avantRemise * remiseLongueDuree / 100 : 0.0;
    return DetailTarif(
      unites: jours.length,
      base: _arrondi(base),
      majorationWeekend: _arrondi(weekend),
      majorationSaison: _arrondi(saison),
      remise: _arrondi(remise),
      joursWeekend: nbWeekend,
      joursSaison: nbSaison,
    );
  }

  static double _arrondi(double v) => (v * 100).round() / 100;
}

/// Résultat de [ReglesTarif.calculer], affiché ligne par ligne dans les aperçus.
class DetailTarif {
  final int unites;
  final double base;
  final double majorationWeekend;
  final double majorationSaison;
  final double remise;
  final int joursWeekend;
  final int joursSaison;

  const DetailTarif({
    required this.unites,
    required this.base,
    this.majorationWeekend = 0,
    this.majorationSaison = 0,
    this.remise = 0,
    this.joursWeekend = 0,
    this.joursSaison = 0,
  });

  double get total =>
      ((base + majorationWeekend + majorationSaison - remise) * 100).round() / 100;
}

/// Liste des jours de [debut] à [fin] inclus (constructeur DateTime : sûr aux changements d'heure).
List<DateTime> joursEntre(DateTime debut, DateTime fin, {bool finIncluse = true}) {
  final jours = <DateTime>[];
  var j = DateTime(debut.year, debut.month, debut.day);
  final f = DateTime(fin.year, fin.month, fin.day);
  while (j.isBefore(f) || (finIncluse && j == f)) {
    jours.add(j);
    j = DateTime(j.year, j.month, j.day + 1);
  }
  return jours;
}
