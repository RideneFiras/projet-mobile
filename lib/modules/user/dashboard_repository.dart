import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/dates.dart';
import 'role.dart';
import 'utilisateur.dart';

/// Compteurs de l'accueil. Chaque rôle ne voit que SES tâches :
/// toutes les requêtes filtrent par l'identifiant de l'utilisateur connecté,
/// sauf pour le transporteur qui voit les commandes ouvertes de toute la plateforme.
class DashboardRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<Map<String, int>> compteurs(Utilisateur u) async {
    final db = await _db.database;
    final id = u.id!;
    final aujourdhui = dateIso(DateTime.now());
    switch (u.role) {
      case Role.client:
        return {
          'ouvertes': await _compte(db,
              "SELECT COUNT(*) FROM commande_transport WHERE client_id = ? AND statut = 'ouverte'",
              [id]),
          'acceptees': await _compte(db,
              "SELECT COUNT(*) FROM commande_transport WHERE client_id = ? AND statut = 'acceptee'",
              [id]),
        };
      case Role.traveller:
        return {
          'voyages': await _compte(db,
              "SELECT COUNT(*) FROM voyage WHERE utilisateur_id = ? AND date_fin >= ? AND statut <> 'annule'",
              [id, aujourdhui]),
          'propositions': await _compte(db,
              "SELECT COUNT(*) FROM mise_en_relation WHERE voyageur_id = ? AND statut = 'proposee'",
              [id]),
          'reservations': await _compte(db, '''
              SELECT (SELECT COUNT(*) FROM location_vehicule l
                        JOIN voyage v ON v.id = l.voyage_id WHERE v.utilisateur_id = ?)
                   + (SELECT COUNT(*) FROM reservation_hebergement r
                        JOIN voyage v ON v.id = r.voyage_id WHERE v.utilisateur_id = ?)
              ''', [id, id]),
        };
      case Role.transporter:
        return {
          'ouvertes': await _compte(db,
              "SELECT COUNT(*) FROM commande_transport WHERE statut = 'ouverte'", const []),
          'propositions': await _compte(db,
              "SELECT COUNT(*) FROM mise_en_relation WHERE auteur_id = ? AND statut = 'proposee'",
              [id]),
          'acceptees': await _compte(db,
              "SELECT COUNT(*) FROM mise_en_relation WHERE auteur_id = ? AND statut = 'acceptee'",
              [id]),
        };
      case Role.admin:
        return {
          'actualites': await _compte(db, 'SELECT COUNT(*) FROM actualite', const []),
          'comptes': await _compte(db, 'SELECT COUNT(*) FROM utilisateur', const []),
          'sujets': await _compte(db, 'SELECT COUNT(*) FROM forum_sujet', const []),
        };
    }
  }

  Future<int> _compte(Database db, String sql, List<Object?> args) async {
    final rows = await db.rawQuery(sql, args);
    return (rows.first.values.first as int?) ?? 0;
  }
}
