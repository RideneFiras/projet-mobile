import '../../core/database/database_helper.dart';
import 'models/voyage.dart';

/// CRUD de la table "voyage". Un utilisateur ne voit et ne modifie que ses voyages.
class VoyageRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Voyages d'un utilisateur, du plus proche au plus lointain.
  Future<List<Voyage>> voyagesDe(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.query(
      'voyage',
      where: 'utilisateur_id = ?',
      whereArgs: [utilisateurId],
      orderBy: 'date_debut, id',
    );
    return rows.map(Voyage.fromMap).toList();
  }

  Future<int> creer(Voyage v) async {
    final db = await _db.database;
    return db.insert('voyage', v.toMap());
  }

  /// Renvoie false si le voyage n'existe pas ou n'appartient pas à l'utilisateur.
  Future<bool> modifier(Voyage v, int utilisateurId) async {
    final db = await _db.database;
    final n = await db.update(
      'voyage',
      v.toMap(),
      where: 'id = ? AND utilisateur_id = ?',
      whereArgs: [v.id, utilisateurId],
    );
    return n > 0;
  }

  /// Supprime le voyage ; les réservations liées (location, hébergement) partent avec lui.
  Future<bool> supprimer(int id, int utilisateurId) async {
    final db = await _db.database;
    final n = await db.delete(
      'voyage',
      where: 'id = ? AND utilisateur_id = ?',
      whereArgs: [id, utilisateurId],
    );
    return n > 0;
  }
}
