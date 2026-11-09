import '../../../core/utils/dates.dart';

/// Statut stocké en base : planifie | actif | termine | annule.
enum StatutVoyage {
  planifie('planifie', 'Planifié'),
  actif('actif', 'En cours'),
  termine('termine', 'Terminé'),
  annule('annule', 'Annulé');

  const StatutVoyage(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static StatutVoyage depuis(String valeur) => StatutVoyage.values
      .firstWhere((s) => s.valeur == valeur, orElse: () => StatutVoyage.planifie);
}

/// Un voyage appartient à un utilisateur (voyage.utilisateur_id).
class Voyage {
  final int? id;
  final String titre;
  final String destination;
  final DateTime dateDebut;
  final DateTime dateFin;
  final double budget;
  final StatutVoyage statut;
  final int utilisateurId;

  const Voyage({
    this.id,
    required this.titre,
    required this.destination,
    required this.dateDebut,
    required this.dateFin,
    required this.budget,
    required this.statut,
    required this.utilisateurId,
  });

  /// Durée en jours, bornes comprises (un voyage d'un jour = 1 jour).
  int get duree => nombreDeJours(dateDebut, dateFin) + 1;

  /// Statut AFFICHÉ : tient compte des dates du jour. Le statut stocké en base
  /// n'est jamais modifié ici (annulé reste annulé).
  StatutVoyage get statutEffectif {
    if (statut == StatutVoyage.annule) return statut;
    final auj = dateJour(DateTime.now());
    if (auj.isAfter(dateJour(dateFin))) return StatutVoyage.termine;
    if (statut == StatutVoyage.planifie && !auj.isBefore(dateJour(dateDebut))) {
      return StatutVoyage.actif;
    }
    return statut;
  }

  /// Règle de la base : date_fin >= date_debut. Renvoie un message ou null.
  static String? verifierPeriode(DateTime debut, DateTime fin) {
    if (dateJour(fin).isBefore(dateJour(debut))) {
      return 'La date de fin doit être après la date de départ';
    }
    return null;
  }

  factory Voyage.fromMap(Map<String, Object?> m) => Voyage(
    id: m['id'] as int?,
    titre: m['titre'] as String,
    destination: m['destination'] as String,
    dateDebut: DateTime.parse(m['date_debut'] as String),
    dateFin: DateTime.parse(m['date_fin'] as String),
    budget: (m['budget'] as num).toDouble(),
    statut: StatutVoyage.depuis(m['statut'] as String),
    utilisateurId: m['utilisateur_id'] as int,
  );

  Map<String, Object?> toMap() => {
    'titre': titre.trim(),
    'destination': destination.trim(),
    'date_debut': dateIso(dateDebut),
    'date_fin': dateIso(dateFin),
    'budget': budget,
    'statut': statut.valeur,
    'utilisateur_id': utilisateurId,
  };
}
