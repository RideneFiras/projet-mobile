import '../../../core/utils/dates.dart';
import '../../../core/utils/json_listes.dart';
import '../../../core/utils/tarification.dart';
import 'option_location.dart';
import 'vehicule.dart';

/// Statut stocké d'une location.
enum StatutLocation {
  enAttente('en_attente', 'En attente'),
  confirmee('confirmee', 'Confirmée'),
  enCours('en_cours', 'En cours'),
  terminee('terminee', 'Terminée'),
  annulee('annulee', 'Annulée');

  const StatutLocation(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static StatutLocation depuis(String? valeur) => StatutLocation.values.firstWhere(
      (s) => s.valeur == valeur,
      orElse: () => StatutLocation.confirmee);
}

/// Location d'un véhicule pour un voyage (table "location_vehicule").
/// Règles : prix_total = (prix_par_jour + options par jour) x jours (bornes comprises) ;
/// deux locations non annulées du même véhicule ne se chevauchent jamais ;
/// clôture : pénalité = jours de retard x prix_par_jour x 1,5.
class LocationVehicule {
  /// Majoration appliquée à chaque jour de retard.
  static const double coefficientRetard = 1.5;

  final int? id;
  final int vehiculeId;
  final int voyageId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final double prixTotal;
  final double caution;
  final StatutLocation statut;
  final String? lieuPrise;
  final String? lieuRetour;
  final String? notes;
  final List<OptionLocation> options;

  /// Remplis à la clôture (retour du véhicule).
  final DateTime? dateRetourReelle;
  final int? kmDepart;
  final int? kmRetour;
  final double penalite;

  /// Numéro du permis de conduire (voiture, moto).
  final String? numeroPermis;

  /// Date de signature électronique du contrat (null = non signé).
  final DateTime? contratSigneLe;
  final DateTime? creeLe;

  /// Champs d'affichage issus des jointures (absents à la saisie).
  final String? nomVehicule;
  final TypeVehicule? typeVehicule;
  final String? photoVehicule;
  final String? titreVoyage;
  final String? nomClient;
  final String? emailClient;

  const LocationVehicule({
    this.id,
    required this.vehiculeId,
    required this.voyageId,
    required this.dateDebut,
    required this.dateFin,
    this.prixTotal = 0,
    this.caution = 0,
    this.statut = StatutLocation.confirmee,
    this.lieuPrise,
    this.lieuRetour,
    this.notes,
    this.options = const [],
    this.dateRetourReelle,
    this.kmDepart,
    this.kmRetour,
    this.penalite = 0,
    this.numeroPermis,
    this.contratSigneLe,
    this.creeLe,
    this.nomVehicule,
    this.typeVehicule,
    this.photoVehicule,
    this.titreVoyage,
    this.nomClient,
    this.emailClient,
  });

  /// Nombre de jours loués, bornes comprises (même jour = 1 jour).
  int get jours => ecartJours(dateDebut, dateFin) + 1;

  /// Écart en jours calendaires, calculé en UTC : insensible aux changements
  /// d'heure été/hiver (un jour de 23 h compte bien pour un jour).
  static int ecartJours(DateTime debut, DateTime fin) =>
      DateTime.utc(fin.year, fin.month, fin.day)
          .difference(DateTime.utc(debut.year, debut.month, debut.day))
          .inDays;

  bool get annulee => statut == StatutLocation.annulee;

  /// Véhicule rendu : la location a été clôturée par l'administrateur.
  bool get cloturee => dateRetourReelle != null || statut == StatutLocation.terminee;

  /// Date de fin réelle : retour effectif s'il a eu lieu, sinon date prévue.
  DateTime get finEffective => dateRetourReelle ?? dateFin;

  /// Montant total dû (location + pénalité éventuelle).
  double get totalDu => prixTotal + penalite;

  /// Statut AFFICHÉ selon la date du jour ; le statut stocké n'est pas modifié.
  /// Une location commencée reste « en cours » tant que le véhicule n'est pas rendu.
  StatutLocation get statutEffectif {
    if (statut == StatutLocation.annulee || statut == StatutLocation.enAttente) {
      return statut;
    }
    if (cloturee) return StatutLocation.terminee;
    if (dateJour(DateTime.now()).isBefore(dateJour(dateDebut))) {
      return StatutLocation.confirmee;
    }
    return StatutLocation.enCours;
  }

  /// Date de retour prévue dépassée et véhicule pas encore rendu.
  bool get enRetard =>
      !annulee && !cloturee && dateJour(DateTime.now()).isAfter(dateJour(dateFin));

  /// L'administrateur peut clôturer une location commencée, non annulée, non clôturée.
  bool get aCloturer =>
      !annulee && !cloturee && !dateJour(DateTime.now()).isBefore(dateJour(dateDebut));

  /// Une location commencée ou passée ne s'annule plus.
  bool get annulable =>
      !annulee && !cloturee && dateJour(DateTime.now()).isBefore(dateJour(dateDebut));

  /// (libellé, valeur pour couleursStatut) : « En retard » prime sur « En cours ».
  (String, String) get affichageStatut => enRetard
      ? ('En retard', 'hors_service')
      : (statutEffectif.libelle, statutEffectif.valeur);

  /// Règle de la base : la date de fin ne précède pas la date de début.
  static String? verifierPeriode(DateTime debut, DateTime fin) {
    if (dateJour(fin).isBefore(dateJour(debut))) {
      return 'La date de retour doit être après la date de prise en charge';
    }
    return null;
  }

  /// Prix d'une location : (prix journalier + options) x jours.
  /// Utilisé par le repository (montant enregistré) et par l'aperçu du formulaire.
  static double calculerPrix({
    required double prixParJour,
    required Iterable<OptionLocation> options,
    required int jours,
  }) =>
      (prixParJour + OptionLocation.totalParJour(options)) * jours;

  /// Prix avec tarification dynamique : tarif du véhicule (week-end, saison, remise)
  /// sur chaque jour loué, plus les options (prix fixe par jour).
  /// Avec des règles à 0 %, identique à [calculerPrix].
  static ({DetailTarif tarif, double options, double total}) calculerPrixDynamique({
    required ReglesTarif regles,
    required double prixParJour,
    required Iterable<OptionLocation> options,
    required DateTime debut,
    required DateTime fin,
  }) {
    final jours = joursEntre(debut, fin);
    final tarif = regles.calculer(prixParJour, jours);
    final prixOptions = OptionLocation.totalParJour(options) * jours.length;
    return (
      tarif: tarif,
      options: prixOptions,
      total: ((tarif.total + prixOptions) * 100).round() / 100,
    );
  }

  /// Format attendu d'un numéro de permis (lettres, chiffres, espaces, tirets ; 5 à 20).
  static String? verifierPermis(String? numero, {required bool obligatoire}) {
    final n = numero?.trim() ?? '';
    if (n.isEmpty) return obligatoire ? 'Numéro de permis obligatoire' : null;
    if (!RegExp(r'^[A-Za-z0-9 /\-]{5,20}$').hasMatch(n)) return 'Numéro de permis invalide';
    return null;
  }

  /// Jours de retard entre la date de fin prévue et le retour réel (0 si à l'heure).
  static int joursDeRetard(DateTime finPrevue, DateTime retour) {
    final n = ecartJours(finPrevue, retour);
    return n > 0 ? n : 0;
  }

  /// Pénalité = jours de retard x prix_par_jour x 1,5.
  static double calculerPenalite({
    required DateTime finPrevue,
    required DateTime retour,
    required double prixParJour,
  }) =>
      joursDeRetard(finPrevue, retour) * prixParJour * coefficientRetard;

  factory LocationVehicule.fromMap(Map<String, Object?> m) => LocationVehicule(
        id: m['id'] as int?,
        vehiculeId: m['vehicule_id'] as int,
        voyageId: m['voyage_id'] as int,
        dateDebut: DateTime.parse(m['date_debut'] as String),
        dateFin: DateTime.parse(m['date_fin'] as String),
        prixTotal: (m['prix_total'] as num).toDouble(),
        caution: ((m['caution'] as num?) ?? 0).toDouble(),
        statut: StatutLocation.depuis(m['statut'] as String?),
        lieuPrise: m['lieu_prise'] as String?,
        lieuRetour: m['lieu_retour'] as String?,
        notes: m['notes'] as String?,
        options: [
          for (final v in listeDepuisJson(m['options']))
            if (OptionLocation.depuis(v) case final o?) o,
        ],
        dateRetourReelle: dateDepuisIso(m['date_retour_reelle'] as String?),
        kmDepart: m['km_depart'] as int?,
        kmRetour: m['km_retour'] as int?,
        penalite: ((m['penalite'] as num?) ?? 0).toDouble(),
        numeroPermis: m['numero_permis'] as String?,
        contratSigneLe: DateTime.tryParse((m['contrat_signe_le'] as String?) ?? ''),
        creeLe: DateTime.tryParse((m['cree_le'] as String?) ?? ''),
        nomVehicule: m['nom_vehicule'] as String?,
        typeVehicule: m['type_vehicule'] == null
            ? null
            : TypeVehicule.depuis(m['type_vehicule'] as String),
        photoVehicule: listeDepuisJson(m['photos_vehicule']).firstOrNull,
        titreVoyage: m['titre_voyage'] as String?,
        nomClient: m['nom_client'] as String?,
        emailClient: m['email_client'] as String?,
      );

  /// Prix, caution et champs de clôture ne sont pas repris d'ici :
  /// le repository les calcule (enregistrer, cloturerLocation).
  Map<String, Object?> toMap() {
    String? texte(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return {
      'vehicule_id': vehiculeId,
      'voyage_id': voyageId,
      'date_debut': dateIso(dateDebut),
      'date_fin': dateIso(dateFin),
      'prix_total': prixTotal,
      'caution': caution,
      'statut': statut.valeur,
      'lieu_prise': texte(lieuPrise),
      'lieu_retour': texte(lieuRetour),
      'notes': texte(notes),
      'options': listeEnJson(options.map((o) => o.valeur)),
      'numero_permis': texte(numeroPermis)?.toUpperCase(),
      'cree_le': (creeLe ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }
}
