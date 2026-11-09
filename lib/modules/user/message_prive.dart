/// Message privé entre deux utilisateurs (messenger du fil).
/// [type] : texte (contenu = texte), image (base64), vocal (base64 audio).
class MessagePrive {
  final int? id;
  final int expediteurId;
  final int destinataireId;
  final String contenu;
  final String type;
  final DateTime creeLe;

  const MessagePrive({
    this.id,
    required this.expediteurId,
    required this.destinataireId,
    required this.contenu,
    this.type = 'texte',
    required this.creeLe,
  });

  bool get estImage => type == 'image';
  bool get estVocal => type == 'vocal';

  factory MessagePrive.fromMap(Map<String, dynamic> m) => MessagePrive(
        id: m['id'] as int?,
        expediteurId: m['expediteur_id'] as int,
        destinataireId: m['destinataire_id'] as int,
        contenu: m['contenu'] as String,
        type: (m['type'] as String?) ?? 'texte',
        creeLe: DateTime.parse(m['cree_le'] as String),
      );
}

/// Résumé d'une conversation pour la liste (un interlocuteur).
class Conversation {
  final int autreId;
  final String autreNom;
  final String dernierMessage;
  final DateTime dernierDate;

  const Conversation({
    required this.autreId,
    required this.autreNom,
    required this.dernierMessage,
    required this.dernierDate,
  });
}
