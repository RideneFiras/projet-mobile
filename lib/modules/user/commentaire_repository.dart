import '../../core/database/database_helper.dart';
import 'commentaire.dart';

/// Commentaires du fil d'actualité (type Facebook : réponse sous un post).
///
/// Règle d'accès, appliquée dans le SQL (pas seulement à l'écran) :
/// chacun ne peut modifier ou supprimer que SES propres commentaires.
class CommentaireRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Commentaires d'une actualité, du plus ancien au plus récent.
  Future<List<CommentaireActualite>> lister(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT c.*, u.role AS auteur_role
      FROM commentaire_actualite c
      LEFT JOIN utilisateur u ON u.id = c.auteur_id
      WHERE c.actualite_id = ?
      ORDER BY c.cree_le ASC, c.id ASC
    ''', [actualiteId]);
    return rows.map(CommentaireActualite.fromMap).toList();
  }

  Future<int> compter(int actualiteId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM commentaire_actualite WHERE actualite_id = ?',
      [actualiteId],
    );
    return (rows.first.values.first as int?) ?? 0;
  }

  Future<void> ajouter({
    required int actualiteId,
    required int auteurId,
    required String auteurNom,
    required String contenu,
    int? parentId,
  }) async {
    final db = await _db.database;
    await db.insert('commentaire_actualite', {
      'actualite_id': actualiteId,
      'parent_id': parentId,
      'auteur_id': auteurId,
      'auteur_nom': auteurNom.trim(),
      'contenu': contenu.trim(),
      'cree_le': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Réponses à un commentaire (un niveau de fil).
  Future<List<CommentaireActualite>> reponses(int commentaireId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT c.*, u.role AS auteur_role
      FROM commentaire_actualite c
      LEFT JOIN utilisateur u ON u.id = c.auteur_id
      WHERE c.parent_id = ?
      ORDER BY c.cree_le ASC, c.id ASC
    ''', [commentaireId]);
    return rows.map(CommentaireActualite.fromMap).toList();
  }

  /// Modifie uniquement si le commentaire appartient à [auteurId].
  /// Renvoie false si rien n'a été modifié (commentaire d'un autre).
  Future<bool> modifier(int id, int auteurId, String contenu) async {
    final db = await _db.database;
    final n = await db.update(
      'commentaire_actualite',
      {'contenu': contenu.trim()},
      where: 'id = ? AND auteur_id = ?',
      whereArgs: [id, auteurId],
    );
    return n > 0;
  }

  /// Supprime uniquement si le commentaire appartient à [auteurId].
  Future<bool> supprimer(int id, int auteurId) async {
    final db = await _db.database;
    final n = await db.delete(
      'commentaire_actualite',
      where: 'id = ? AND auteur_id = ?',
      whereArgs: [id, auteurId],
    );
    return n > 0;
  }
}
