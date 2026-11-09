/// Public visé par une actualité (valeurs stockées en base, table `actualite`).
enum AudienceActualite {
  tous('tous', 'Tous les utilisateurs'),
  client('client', 'Clients uniquement'),
  traveller('traveller', 'Voyageurs uniquement'),
  transporter('transporter', 'Transporteurs uniquement');

  const AudienceActualite(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static AudienceActualite depuis(String? valeur) =>
      AudienceActualite.values.firstWhere((a) => a.valeur == valeur,
          orElse: () => tous);
}

/// Type de post : standard (texte/photo/sondage) ou annonce (événement).
enum TypePost {
  standard('standard', 'Post'),
  annonce('annonce', 'Annonce');

  const TypePost(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static TypePost depuis(String? valeur) =>
      TypePost.values.firstWhere((t) => t.valeur == valeur, orElse: () => standard);
}

/// Catégorie d'une actualité (valeurs stockées en base).
enum CategorieActualite {
  general('general', 'Général'),
  voyage('voyage', 'Voyage'),
  commande('commande', 'Commande'),
  transport('transport', 'Transport'),
  annonce('annonce', 'Annonce');

  const CategorieActualite(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  static CategorieActualite depuis(String? valeur) =>
      CategorieActualite.values.firstWhere((c) => c.valeur == valeur,
          orElse: () => general);
}

class Actualite {
  final int? id;
  final String titre;
  final String contenu;
  /// Photo du post encodée en base64 (null = post texte seulement).
  final String? photo;
  /// Post épinglé en haut du fil (auteur seul).
  final bool epingle;
  final TypePost typePost;
  final DateTime? dateEvenement;
  final String? lieu;
  final DateTime datePublication;
  final int? auteurId;
  /// Nom, photo et rôle de l'auteur (jointure avec `utilisateur`).
  final String? auteurNom;
  final String? auteurPhoto;
  final String? auteurRole;
  final AudienceActualite audience;
  final CategorieActualite categorie;

  const Actualite({
    this.id,
    required this.titre,
    required this.contenu,
    this.photo,
    this.epingle = false,
    this.typePost = TypePost.standard,
    this.dateEvenement,
    this.lieu,
    required this.datePublication,
    this.auteurId,
    this.auteurNom,
    this.auteurPhoto,
    this.auteurRole,
    this.audience = AudienceActualite.tous,
    this.categorie = CategorieActualite.general,
  });

  factory Actualite.fromMap(Map<String, dynamic> m) => Actualite(
        id: m['id'] as int?,
        titre: m['titre'] as String,
        contenu: m['contenu'] as String,
        photo: m['photo'] as String?,
        epingle: (m['epingle'] as int?) == 1,
        typePost: TypePost.depuis(m['type_post'] as String?),
        dateEvenement: m['date_evenement'] == null
            ? null
            : DateTime.parse(m['date_evenement'] as String),
        lieu: m['lieu'] as String?,
        datePublication: DateTime.parse(m['date_publication'] as String),
        auteurId: m['auteur_id'] as int?,
        auteurNom: m['auteur_nom'] as String?,
        auteurPhoto: m['auteur_photo'] as String?,
        auteurRole: m['auteur_role'] as String?,
        // Null si la base est antérieure à l'ajout des colonnes -> valeur par défaut.
        audience: AudienceActualite.depuis(m['audience'] as String?),
        categorie: CategorieActualite.depuis(m['categorie'] as String?),
      );

  Map<String, dynamic> versMap() => {
        'titre': titre.trim(),
        'contenu': contenu.trim(),
        'audience': audience.valeur,
        'categorie': categorie.valeur,
      };
}
