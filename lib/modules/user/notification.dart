/// Notification du fil d'actualité : « X a commenté/aimé/voté ton post ».
class NotificationFil {
  final int? id;
  final int destinataireId;
  final int? acteurId;
  final String acteurNom;
  /// commentaire | reaction | sondage | participation
  final String type;
  final int? actualiteId;
  final String texte;
  final bool lue;
  final DateTime creeLe;

  const NotificationFil({
    this.id,
    required this.destinataireId,
    this.acteurId,
    required this.acteurNom,
    required this.type,
    this.actualiteId,
    required this.texte,
    required this.lue,
    required this.creeLe,
  });

  factory NotificationFil.fromMap(Map<String, dynamic> m) => NotificationFil(
        id: m['id'] as int?,
        destinataireId: m['destinataire_id'] as int,
        acteurId: m['acteur_id'] as int?,
        acteurNom: m['acteur_nom'] as String,
        type: m['type'] as String,
        actualiteId: m['actualite_id'] as int?,
        texte: m['texte'] as String,
        lue: (m['lue'] as int?) == 1,
        creeLe: DateTime.parse(m['cree_le'] as String),
      );
}
