import '../../core/database/database_helper.dart';
import 'models/avis.dart';
import 'models/sujet_forum.dart';

/// Accès SQLite du module forum (forum_sujet, forum_reponse, avis).
/// Seul l'auteur peut modifier ou supprimer ses propres messages et avis.
class ForumRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  String get _maintenant => DateTime.now().toUtc().toIso8601String();

  // ------------------------------------------------------------------
  // Sujets de discussion
  // ------------------------------------------------------------------

  static const String _selectSujet = '''
    SELECT s.*, u.prenom || ' ' || u.nom AS nom_auteur,
      (SELECT COUNT(*) FROM forum_reponse r WHERE r.sujet_id = s.id) AS nb_reponses
    FROM forum_sujet s
    JOIN utilisateur u ON u.id = s.auteur_id
  ''';

  Future<List<SujetForum>> sujets() async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('$_selectSujet ORDER BY s.cree_le DESC, s.id DESC');
    return rows.map(SujetForum.fromMap).toList();
  }

  Future<SujetForum?> sujet(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery('$_selectSujet WHERE s.id = ?', [id]);
    return rows.isEmpty ? null : SujetForum.fromMap(rows.first);
  }

  Future<int> creerSujet(SujetForum s) async {
    final db = await _db.database;
    final Map<String, Object?> valeurs = {
      ...s.toMap(),
      'cree_le': _maintenant,
    };
    return db.insert('forum_sujet', valeurs);
  }

  /// Renvoie false si le sujet n'existe pas ou n'appartient pas à l'auteur.
  Future<bool> modifierSujet(SujetForum s, int auteurId) async {
    final db = await _db.database;
    final n = await db.update(
      'forum_sujet',
      {'titre': s.titre.trim(), 'contenu': s.contenu.trim()},
      where: 'id = ? AND auteur_id = ?',
      whereArgs: [s.id, auteurId],
    );
    return n > 0;
  }

  /// Les réponses du sujet sont supprimées avec lui (ON DELETE CASCADE).
  Future<bool> supprimerSujet(int id, int auteurId) async {
    final db = await _db.database;
    final n = await db.delete('forum_sujet',
        where: 'id = ? AND auteur_id = ?', whereArgs: [id, auteurId]);
    return n > 0;
  }

  // ------------------------------------------------------------------
  // Réponses
  // ------------------------------------------------------------------

  Future<List<ReponseForum>> reponses(int sujetId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT r.*, u.prenom || ' ' || u.nom AS nom_auteur
      FROM forum_reponse r
      JOIN utilisateur u ON u.id = r.auteur_id
      WHERE r.sujet_id = ?
      ORDER BY r.cree_le, r.id
    ''', [sujetId]);
    return rows.map(ReponseForum.fromMap).toList();
  }

  Future<int> ajouterReponse({
    required int sujetId,
    required int auteurId,
    required String contenu,
  }) async {
    final db = await _db.database;
    return db.insert('forum_reponse', {
      'contenu': contenu.trim(),
      'cree_le': _maintenant,
      'sujet_id': sujetId,
      'auteur_id': auteurId,
    });
  }

  Future<bool> supprimerReponse(int id, int auteurId) async {
    final db = await _db.database;
    final n = await db.delete('forum_reponse',
        where: 'id = ? AND auteur_id = ?', whereArgs: [id, auteurId]);
    return n > 0;
  }

  // ------------------------------------------------------------------
  // Avis
  // ------------------------------------------------------------------

  /// Le libellé du service noté est lu dans sa propre table selon le type.
  static const String _selectAvis = '''
    SELECT a.*, u.prenom || ' ' || u.nom AS nom_auteur,
      CASE a.cible_type
        WHEN 'location' THEN
          (SELECT v.marque || ' ' || v.modele FROM vehicule v WHERE v.id = a.cible_id)
        WHEN 'hebergement' THEN
          (SELECT h.nom FROM hebergement h WHERE h.id = a.cible_id)
        WHEN 'transport' THEN
          (SELECT t.ville_depart || ' → ' || t.destination FROM trajet_transport t WHERE t.id = a.cible_id)
      END AS libelle_cible
    FROM avis a
    JOIN utilisateur u ON u.id = a.auteur_id
  ''';

  Future<List<Avis>> avis() async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('$_selectAvis ORDER BY a.cree_le DESC, a.id DESC');
    return rows.map(Avis.fromMap).toList();
  }

  Future<int> creerAvis(Avis a) async {
    final db = await _db.database;
    final Map<String, Object?> valeurs = {
      ...a.toMap(),
      'cree_le': _maintenant,
    };
    return db.insert('avis', valeurs);
  }

  Future<bool> modifierAvis(Avis a, int auteurId) async {
    final db = await _db.database;
    final n = await db.update('avis', a.toMap(),
        where: 'id = ? AND auteur_id = ?', whereArgs: [a.id, auteurId]);
    return n > 0;
  }

  Future<bool> supprimerAvis(int id, int auteurId) async {
    final db = await _db.database;
    final n = await db.delete('avis',
        where: 'id = ? AND auteur_id = ?', whereArgs: [id, auteurId]);
    return n > 0;
  }

  /// Services pouvant être notés pour un type donné : (id, libellé).
  Future<List<(int, String)>> cibles(CibleAvis cible) async {
    final db = await _db.database;
    switch (cible) {
      case CibleAvis.location:
        final rows = await db.query('vehicule', orderBy: 'marque, modele');
        return [
          for (final r in rows)
            (r['id'] as int, '${r['marque']} ${r['modele']}'),
        ];
      case CibleAvis.hebergement:
        final rows = await db.query('hebergement', orderBy: 'nom COLLATE NOCASE');
        return [for (final r in rows) (r['id'] as int, r['nom'] as String)];
      case CibleAvis.transport:
        final rows = await db.query('trajet_transport',
            columns: ['id', 'ville_depart', 'destination', 'date_depart'],
            orderBy: 'date_depart, id');
        return [
          for (final r in rows)
            (
              r['id'] as int,
              '${r['ville_depart']} → ${r['destination']} (${r['date_depart']})',
            ),
        ];
    }
  }
}
