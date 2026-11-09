import '../../../core/utils/dates.dart';
import '../../../core/utils/json_listes.dart';
import '../../../core/utils/tarification.dart';
import 'hebergement.dart';

/// Statut stocké d'un séjour.
enum StatutSejour {
  enAttente('en_attente', 'En attente'),
  confirmee('confirmee', 'Confirmé'),
  enCours('en_cours', 'En cours'),
  checkIn('check_in', 'Arrivé'),
  checkOut('check_out', 'Parti'),
  terminee('terminee', 'Terminé'),
  annulee('annulee', 'Annulé');

  const StatutSejour(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static StatutSejour depuis(String? valeur) => StatutSejour.values
      .firstWhere((s) => s.valeur == valeur, orElse: () => StatutSejour.confirmee);
}

/// Type de chambre : coefficient appliqué au prix par nuit de l'établissement.
enum TypeChambre {
  single('single', 'Single', 0.8, 1),
  chambreDouble('double', 'Double', 1.0, 2),
  suite('suite', 'Suite', 1.6, 2),
  familiale('familiale', 'Familiale', 1.4, 4);

  const TypeChambre(this.valeur, this.libelle, this.coefficient, this.personnesConseillees);

  final String valeur;
  final String libelle;
  final double coefficient;
  final int personnesConseillees;

  /// Supplément affiché : « −20 % », « +60 % » ou « prix de base ».
  String get libelleTarif => coefficient == 1
      ? 'prix de base'
      : '${coefficient > 1 ? '+' : '−'}${((coefficient - 1).abs() * 100).round()} %';

  static TypeChambre depuis(String? valeur) => TypeChambre.values
      .firstWhere((t) => t.valeur == valeur, orElse: () => TypeChambre.chambreDouble);
}

/// Séjour réservé dans un hébergement pour un voyage (table "reservation_hebergement").
/// Règles : date_depart > date_arrivee ; prix_total = prix_par_nuit x nuits x chambres.
class ReservationHebergement {
  final int? id;
  final int hebergementId;
  final int voyageId;
  final DateTime dateArrivee;
  final DateTime dateDepart;
  final int nbPersonnes;
  final int nbChambres;
  final TypeChambre typeChambre;
  final double prixTotal;
  final StatutSejour statut;
  final String? demandes;

  /// Code d'arrivée à 6 chiffres, généré à la confirmation.
  final String? codeCheckin;
  final DateTime? creeLe;

  /// Champs d'affichage issus de la jointure.
  final String? nomHebergement;
  final TypeHebergement? typeHebergement;
  final String? photoHebergement;
  final String? titreVoyage;

  const ReservationHebergement({
    this.id,
    required this.hebergementId,
    required this.voyageId,
    required this.dateArrivee,
    required this.dateDepart,
    this.nbPersonnes = 1,
    this.nbChambres = 1,
    this.typeChambre = TypeChambre.chambreDouble,
    this.prixTotal = 0,
    this.statut = StatutSejour.confirmee,
    this.demandes,
    this.codeCheckin,
    this.creeLe,
    this.nomHebergement,
    this.typeHebergement,
    this.photoHebergement,
    this.titreVoyage,
  });

  /// Nombre de nuits : départ moins arrivée.
  int get nuits => nombreDeJours(dateArrivee, dateDepart);

  bool get annulee => statut == StatutSejour.annulee;

  /// Statut AFFICHÉ selon la date du jour ; le statut stocké n'est pas modifié.
  /// Le jour du départ, le séjour est terminé (la chambre est libérée).
  /// Arrivé / Parti (check-in, check-out) priment sur les dates.
  StatutSejour get statutEffectif {
    if (statut == StatutSejour.annulee ||
        statut == StatutSejour.enAttente ||
        statut == StatutSejour.checkIn ||
        statut == StatutSejour.checkOut) {
      return statut;
    }
    final auj = dateJour(DateTime.now());
    if (!auj.isBefore(dateJour(dateDepart))) return StatutSejour.terminee;
    if (!auj.isBefore(dateJour(dateArrivee))) return StatutSejour.enCours;
    return StatutSejour.confirmee;
  }

  /// Un séjour commencé ou passé ne s'annule plus.
  bool get annulable =>
      statut == StatutSejour.confirmee &&
      dateJour(DateTime.now()).isBefore(dateJour(dateArrivee));

  /// Check-in possible : séjour confirmé, du jour d'arrivée à la veille du départ.
  bool get peutCheckIn {
    final auj = dateJour(DateTime.now());
    return (statut == StatutSejour.confirmee || statut == StatutSejour.enCours) &&
        !auj.isBefore(dateJour(dateArrivee)) &&
        auj.isBefore(dateJour(dateDepart));
  }

  bool get peutCheckOut => statut == StatutSejour.checkIn;

  /// Prix : tarif dynamique de l'établissement (nuits) x coefficient de la chambre x chambres.
  static ({DetailTarif tarif, double total}) calculerPrix({
    required ReglesTarif regles,
    required double prixParNuit,
    required TypeChambre typeChambre,
    required int nbChambres,
    required DateTime arrivee,
    required DateTime depart,
  }) {
    final tarif = regles.calculer(
        prixParNuit * typeChambre.coefficient, joursEntre(arrivee, depart, finIncluse: false));
    return (tarif: tarif, total: ((tarif.total * nbChambres) * 100).round() / 100);
  }

  static String? verifierSejour(DateTime arrivee, DateTime depart) {
    if (!dateJour(depart).isAfter(dateJour(arrivee))) {
      return 'Le départ doit être au moins un jour après l\'arrivée';
    }
    return null;
  }

  factory ReservationHebergement.fromMap(Map<String, Object?> m) =>
      ReservationHebergement(
        id: m['id'] as int?,
        hebergementId: m['hebergement_id'] as int,
        voyageId: m['voyage_id'] as int,
        dateArrivee: DateTime.parse(m['date_arrivee'] as String),
        dateDepart: DateTime.parse(m['date_depart'] as String),
        nbPersonnes: m['nb_personnes'] as int,
        nbChambres: (m['nb_chambres'] as int?) ?? 1,
        typeChambre: TypeChambre.depuis(m['type_chambre'] as String?),
        codeCheckin: m['code_checkin'] as String?,
        prixTotal: (m['prix_total'] as num).toDouble(),
        statut: StatutSejour.depuis(m['statut'] as String?),
        demandes: m['demandes'] as String?,
        creeLe: DateTime.tryParse((m['cree_le'] as String?) ?? ''),
        nomHebergement: m['nom_hebergement'] as String?,
        typeHebergement: m['type_hebergement'] == null
            ? null
            : TypeHebergement.depuis(m['type_hebergement'] as String),
        photoHebergement: listeDepuisJson(m['photos_hebergement']).firstOrNull,
        titreVoyage: m['titre_voyage'] as String?,
      );

  /// Le prix est recalculé par le repository à l'enregistrement.
  Map<String, Object?> toMap() => {
        'hebergement_id': hebergementId,
        'voyage_id': voyageId,
        'date_arrivee': dateIso(dateArrivee),
        'date_depart': dateIso(dateDepart),
        'nb_personnes': nbPersonnes,
        'nb_chambres': nbChambres,
        'type_chambre': typeChambre.valeur,
        'prix_total': prixTotal,
        'statut': statut.valeur,
        'demandes': (demandes == null || demandes!.trim().isEmpty) ? null : demandes!.trim(),
        'cree_le': (creeLe ?? DateTime.now()).toUtc().toIso8601String(),
      };
}
