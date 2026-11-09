class Actualite {
  final int? id;
  final String titre;
  final String contenu;
  final DateTime datePublication;
  final int? auteurId;

  const Actualite({
    this.id,
    required this.titre,
    required this.contenu,
    required this.datePublication,
    this.auteurId,
  });

  factory Actualite.fromMap(Map<String, dynamic> m) => Actualite(
        id: m['id'] as int?,
        titre: m['titre'] as String,
        contenu: m['contenu'] as String,
        datePublication: DateTime.parse(m['date_publication'] as String),
        auteurId: m['auteur_id'] as int?,
      );
}
