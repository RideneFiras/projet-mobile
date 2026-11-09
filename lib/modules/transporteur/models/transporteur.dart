/// Profil d'un transporteur (table "transporteur"). Un seul profil par compte.
class Transporteur {
  /// Types de transport proposés (valeurs stockées en base).
  static const List<String> types = ['individuel', 'collectif', 'navette'];

  static String libelleType(String valeur) => switch (valeur) {
        'individuel' => 'Individuel',
        'collectif' => 'Collectif',
        'navette' => 'Navette',
        _ => valeur,
      };

  final int? id;
  final int utilisateurId;
  final String nom;
  final String telephone;
  final String email;

  /// Photo ou logo encodé en base64 ('' si aucun).
  final String photo;
  final String ville;
  final String zoneCouverture;
  final String typeTransport;
  final int capacite;
  final String description;
  final String tarifs;
  final bool disponible;

  /// Un profil désactivé reste en base mais n'apparaît plus dans les recherches.
  final bool actif;

  /// Note moyenne sur 5 (0 tant que personne n'a noté).
  final double noteMoyenne;
  final DateTime creeLe;

  /// Nombre de trajets du profil : calculé par SQL, jamais stocké.
  final int nbTrajets;

  const Transporteur({
    this.id,
    required this.utilisateurId,
    required this.nom,
    required this.telephone,
    required this.email,
    this.photo = '',
    required this.ville,
    this.zoneCouverture = '',
    required this.typeTransport,
    this.capacite = 1,
    this.description = '',
    this.tarifs = '',
    this.disponible = true,
    this.actif = true,
    this.noteMoyenne = 0,
    required this.creeLe,
    this.nbTrajets = 0,
  });

  factory Transporteur.fromMap(Map<String, dynamic> m) => Transporteur(
        id: m['id'] as int?,
        utilisateurId: m['utilisateur_id'] as int,
        nom: m['nom'] as String,
        telephone: m['telephone'] as String,
        email: m['email'] as String,
        photo: (m['photo'] as String?) ?? '',
        ville: m['ville'] as String,
        zoneCouverture: (m['zone_couverture'] as String?) ?? '',
        typeTransport: m['type_transport'] as String,
        capacite: (m['capacite'] as int?) ?? 1,
        description: (m['description'] as String?) ?? '',
        tarifs: (m['tarifs'] as String?) ?? '',
        disponible: (m['disponible'] as int?) == 1,
        actif: (m['actif'] as int?) == 1,
        noteMoyenne: ((m['note_moyenne'] as num?) ?? 0).toDouble(),
        creeLe: DateTime.parse(m['cree_le'] as String),
        nbTrajets: (m['nb_trajets'] as int?) ?? 0,
      );

  /// Colonnes saisies dans le formulaire (ni id, ni utilisateur_id, ni date de création).
  Map<String, dynamic> toMapSaisie() => {
        'nom': nom.trim(),
        'telephone': telephone.trim(),
        'email': email.trim().toLowerCase(),
        'photo': photo,
        'ville': ville.trim(),
        'zone_couverture': zoneCouverture.trim(),
        'type_transport': typeTransport,
        'capacite': capacite,
        'description': description.trim(),
        'tarifs': tarifs.trim(),
        'disponible': disponible ? 1 : 0,
        'actif': actif ? 1 : 0,
      };

  Map<String, dynamic> toMapCreation() => {
        ...toMapSaisie(),
        'utilisateur_id': utilisateurId,
        'note_moyenne': 0,
        'cree_le': creeLe.toUtc().toIso8601String(),
      };
}
