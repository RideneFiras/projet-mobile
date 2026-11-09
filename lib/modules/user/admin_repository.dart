import '../../core/database/database_helper.dart';
import 'actualite.dart';
import 'role.dart';
import 'utilisateur.dart';

/// Opérations réservées à l'administrateur : publier, modifier et supprimer les
/// actualités ; lister et supprimer des comptes (jamais le sien ni un autre admin).
class AdminRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  String get _maintenant => DateTime.now().toUtc().toIso8601String();

  // ------------------------------------------------------------------
  // Actualités (CRUD)
  // ------------------------------------------------------------------

  Future<List<Actualite>> actualites() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT a.*, u.prenom || ' ' || u.nom AS auteur_nom, u.photo AS auteur_photo, u.role AS auteur_role
      FROM actualite a
      LEFT JOIN utilisateur u ON u.id = a.auteur_id
      ORDER BY a.epingle DESC, a.date_publication DESC, a.id DESC
    ''');
    return rows.map(Actualite.fromMap).toList();
  }

  /// Publie une actualité et renvoie son identifiant (pour les sondages).
  Future<int> publier({
    required String titre,
    required String contenu,
    required int auteurId,
    AudienceActualite audience = AudienceActualite.tous,
    CategorieActualite categorie = CategorieActualite.general,
    String? photoBase64,
    TypePost typePost = TypePost.standard,
    String? dateEvenement,
    String? lieu,
  }) async {
    final db = await _db.database;
    final nouvelId = await db.insert('actualite', {
      'titre': titre.trim(),
      'contenu': contenu.trim(),
      'photo': photoBase64,
      'type_post': typePost.valeur,
      'date_evenement': dateEvenement,
      'lieu': lieu,
      'date_publication': _maintenant,
      'auteur_id': auteurId,
      'audience': audience.valeur,
      'categorie': categorie.valeur,
    });
    // Historique : la première version est stockée dès la création.
    await db.insert('historique_post', {
      'actualite_id': nouvelId,
      'titre': titre.trim(),
      'contenu': contenu.trim(),
      'auteur_id': auteurId,
      'action': 'creation',
      'cree_le': _maintenant,
    });
    return nouvelId;
  }

  /// Épingle (ou détache) son propre post en haut du fil.
  /// Renvoie false si le post n'appartient pas à [auteurId].
  Future<bool> epingler(int id, int auteurId, bool epingle) async {
    final db = await _db.database;
    final n = await db.update(
      'actualite',
      {'epingle': epingle ? 1 : 0},
      where: 'id = ? AND auteur_id = ?',
      whereArgs: [id, auteurId],
    );
    return n > 0;
  }

  Future<void> modifierActualite(
    int id, {
    required String titre,
    required String contenu,
    AudienceActualite audience = AudienceActualite.tous,
    CategorieActualite categorie = CategorieActualite.general,
    String? photoBase64,
  }) async {
    final db = await _db.database;
    // Historique : archive la version actuelle avant modification.
    final avant = await db.query('actualite',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (avant.isNotEmpty) {
      await db.insert('historique_post', {
        'actualite_id': id,
        'titre': avant.first['titre'],
        'contenu': avant.first['contenu'],
        'auteur_id': avant.first['auteur_id'],
        'action': 'modification',
        'cree_le': _maintenant,
      });
    }
    await db.update(
      'actualite',
      {
        'titre': titre.trim(),
        'contenu': contenu.trim(),
        'photo': photoBase64,
        'audience': audience.valeur,
        'categorie': categorie.valeur,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> supprimerActualite(int id) async {
    final db = await _db.database;
    // Historique : archive la version finale avant suppression
    // (la table n'a pas de clé étrangère : l'historique survit).
    final avant = await db.query('actualite',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (avant.isNotEmpty) {
      await db.insert('historique_post', {
        'actualite_id': id,
        'titre': avant.first['titre'],
        'contenu': avant.first['contenu'],
        'auteur_id': avant.first['auteur_id'],
        'action': 'suppression',
        'cree_le': _maintenant,
      });
    }
    await db.delete('actualite', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Utilisateurs (lecture et suppression)
  // ------------------------------------------------------------------

  Future<List<Utilisateur>> utilisateurs() async {
    final db = await _db.database;
    final rows = await db.query('utilisateur',
        orderBy: 'role, nom COLLATE NOCASE, prenom COLLATE NOCASE');
    return rows.map(Utilisateur.fromMap).toList();
  }

  /// Supprime le compte et, par cascade, ses voyages, commandes et avis.
  /// Renvoie un message d'erreur, ou null si la suppression a eu lieu.
  Future<String?> supprimerUtilisateur(int id, int adminId) async {
    if (id == adminId) return 'Vous ne pouvez pas supprimer votre propre compte';
    final db = await _db.database;
    final rows = await db.query('utilisateur',
        columns: ['role'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return 'Utilisateur introuvable';
    if (rows.first['role'] == Role.admin.valeur) {
      return 'Un administrateur ne peut pas être supprimé ici';
    }
    await db.delete('utilisateur', where: 'id = ?', whereArgs: [id]);
    return null;
  }
}
