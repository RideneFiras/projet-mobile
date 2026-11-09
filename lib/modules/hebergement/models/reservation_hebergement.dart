import '../../../core/utils/dates.dart';

/// Séjour réservé dans un hébergement pour un voyage (table "reservation_hebergement").
/// Règles : date_depart > date_arrivee ; prix_total = prix_par_nuit x nuits.
class ReservationHebergement {
  final int? id;
  final DateTime dateArrivee;
  final DateTime dateDepart;
  final int nbPersonnes;
  final double prixTotal;
  final int voyageId;
  final int hebergementId;

  /// Champs d'affichage issus de la jointure.
  final String? nomHebergement;
  final String? titreVoyage;

  const ReservationHebergement({
    this.id,
    required this.dateArrivee,
    required this.dateDepart,
    required this.voyageId,
    required this.hebergementId,
    this.nbPersonnes = 1,
    this.prixTotal = 0,
    this.nomHebergement,
    this.titreVoyage,
  });

  /// Nombre de nuits : départ moins arrivée.
  int get nuits => nombreDeJours(dateArrivee, dateDepart);

  static String? verifierSejour(DateTime arrivee, DateTime depart) {
    if (!dateJour(depart).isAfter(dateJour(arrivee))) {
      return 'Le départ doit être au moins un jour après l\'arrivée';
    }
    return null;
  }

  factory ReservationHebergement.fromMap(Map<String, Object?> m) =>
      ReservationHebergement(
        id: m['id'] as int?,
        dateArrivee: DateTime.parse(m['date_arrivee'] as String),
        dateDepart: DateTime.parse(m['date_depart'] as String),
        nbPersonnes: m['nb_personnes'] as int,
        prixTotal: (m['prix_total'] as num).toDouble(),
        voyageId: m['voyage_id'] as int,
        hebergementId: m['hebergement_id'] as int,
        nomHebergement: m['nom_hebergement'] as String?,
        titreVoyage: m['titre_voyage'] as String?,
      );

  /// Le prix est recalculé par le repository à l'enregistrement.
  Map<String, Object?> toMap() => {
        'date_arrivee': dateIso(dateArrivee),
        'date_depart': dateIso(dateDepart),
        'nb_personnes': nbPersonnes,
        'prix_total': prixTotal,
        'voyage_id': voyageId,
        'hebergement_id': hebergementId,
      };
}
