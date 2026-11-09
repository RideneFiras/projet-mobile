import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import 'models/commande_transport.dart';
import 'models/mise_en_relation.dart';
import 'models/reservation_transport.dart';
import 'models/transporteur.dart';
import 'models/voyageur_candidat.dart';

/// Accès SQLite du module transporteur (tables transporteur, reservation_transport,
/// commande_transport, mise_en_relation). Les écrans n'écrivent jamais en base directement.
///
/// Confidentialité : les coordonnées (téléphone) ne sortent de la base que
/// lorsque la commande ou la proposition est acceptée (CASE WHEN ... dans le SQL).
class TransportRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------
  // Transporteurs (CRUD)
  // ------------------------------------------------------------------

  Future<List<Transporteur>> transporteurs() async {
    final db = await _db.database;
    final rows = await db.query('transporteur', orderBy: 'nom COLLATE NOCASE');
    return rows.map(Transporteur.fromMap).toList();
  }

  Future<int> creerTransporteur(Transporteur t) async {
    final db = await _db.database;
    return db.insert('transporteur', t.toMap());
  }

  Future<void> modifierTransporteur(Transporteur t) async {
    final db = await _db.database;
    await db.update('transporteur', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  /// Les trajets qui citaient la fiche gardent leur prix (transporteur_id -> NULL).
  Future<void> supprimerTransporteur(int id) async {
    final db = await _db.database;
    await db.delete('transporteur', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Trajets proposés (reservation_transport)
  // ------------------------------------------------------------------

  static const String _selectTrajet = '''
    SELECT r.*, t.nom AS nom_transporteur
    FROM reservation_transport r
    LEFT JOIN transporteur t ON t.id = r.transporteur_id
  ''';

  /// Recherche par trajet et date ; sans critère, tous les trajets.
  Future<List<ReservationTransport>> trajets({
    String? depart,
    String? arrivee,
    DateTime? date,
  }) async {
    final db = await _db.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (depart != null && depart.trim().isNotEmpty) {
      conditions.add('LOWER(r.depart) = LOWER(?)');
      args.add(depart.trim());
    }
    if (arrivee != null && arrivee.trim().isNotEmpty) {
      conditions.add('LOWER(r.arrivee) = LOWER(?)');
      args.add(arrivee.trim());
    }
    if (date != null) {
      conditions.add('r.date_depart = ?');
      args.add(ReservationTransport.dateIso(date));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery(
        '$_selectTrajet $where ORDER BY r.date_depart, r.prix', args);
    return rows.map(ReservationTransport.fromMap).toList();
  }

  Future<int> creerTrajet(ReservationTransport r) async {
    final db = await _db.database;
    return db.insert('reservation_transport', r.toMap());
  }

  Future<void> modifierTrajet(ReservationTransport r) async {
    final db = await _db.database;
    await db.update('reservation_transport', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> supprimerTrajet(int id) async {
    final db = await _db.database;
    await db.delete('reservation_transport', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Commandes client (commande_transport)
  // ------------------------------------------------------------------

  static const String _selectCommande = '''
    SELECT c.*,
      cl.prenom || ' ' || cl.nom AS nom_client,
      CASE WHEN c.statut = 'acceptee' THEN cl.telephone END AS contact_client,
      vo.prenom || ' ' || vo.nom AS nom_voyageur,
      CASE WHEN c.statut = 'acceptee' THEN vo.telephone END AS contact_voyageur
    FROM commande_transport c
    JOIN utilisateur cl ON cl.id = c.client_id
    LEFT JOIN utilisateur vo ON vo.id = c.voyageur_id
  ''';

  Future<List<CommandeTransport>> _commandes(String where,
      List<Object?> args, String orderBy) async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('$_selectCommande $where ORDER BY $orderBy', args);
    return rows.map(CommandeTransport.fromMap).toList();
  }

  /// Toutes les commandes d'un client (la plus récente en premier).
  Future<List<CommandeTransport>> commandesDuClient(int clientId) =>
      _commandes('WHERE c.client_id = ?', [clientId], 'c.cree_le DESC');

  /// Commandes encore ouvertes, visibles des transporteurs.
  Future<List<CommandeTransport>> commandesOuvertes() =>
      _commandes("WHERE c.statut = 'ouverte'", const [], 'c.date_souhaitee, c.id');

  Future<CommandeTransport?> commande(int id) async {
    final liste = await _commandes('WHERE c.id = ?', [id], 'c.id');
    return liste.isEmpty ? null : liste.first;
  }

  Future<int> creerCommande(CommandeTransport c) async {
    final db = await _db.database;
    return db.insert('commande_transport', c.toMapCreation());
  }

  /// Modifie une commande seulement si elle appartient au client et qu'elle est ouverte.
  /// Renvoie false si rien n'a été modifié.
  Future<bool> modifierCommande(CommandeTransport c, int clientId) async {
    final db = await _db.database;
    final n = await db.update('commande_transport', c.toMapSaisie(),
        where: "id = ? AND client_id = ? AND statut = 'ouverte'",
        whereArgs: [c.id, clientId]);
    return n > 0;
  }

  Future<bool> annulerCommande(int id, int clientId) async {
    final db = await _db.database;
    final n = await db.update('commande_transport', {'statut': 'annulee'},
        where: "id = ? AND client_id = ? AND statut = 'ouverte'",
        whereArgs: [id, clientId]);
    return n > 0;
  }

  /// Supprime une commande du client (interdit une fois acceptée).
  Future<bool> supprimerCommande(int id, int clientId) async {
    final db = await _db.database;
    final n = await db.delete('commande_transport',
        where: "id = ? AND client_id = ? AND statut <> 'acceptee'",
        whereArgs: [id, clientId]);
    return n > 0;
  }

  // ------------------------------------------------------------------
  // Mises en relation (mise_en_relation)
  // ------------------------------------------------------------------

  static const String _selectRelation = '''
    SELECT m.*,
      vo.prenom || ' ' || vo.nom AS nom_voyageur,
      CASE WHEN m.statut = 'acceptee' THEN vo.telephone END AS contact_voyageur,
      cl.prenom || ' ' || cl.nom AS nom_client,
      CASE WHEN m.statut = 'acceptee' THEN cl.telephone END AS contact_client,
      t.nom AS nom_transporteur,
      c.depart || ' → ' || c.arrivee AS trajet,
      c.budget AS budget
    FROM mise_en_relation m
    JOIN commande_transport c ON c.id = m.commande_id
    JOIN utilisateur vo ON vo.id = m.voyageur_id
    JOIN utilisateur cl ON cl.id = c.client_id
    LEFT JOIN transporteur t ON t.id = m.transporteur_id
  ''';

  Future<List<MiseEnRelation>> _relations(String where, List<Object?> args) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectRelation $where ORDER BY m.cree_le DESC', args);
    return rows.map(MiseEnRelation.fromMap).toList();
  }

  /// Propositions créées par un transporteur (auteur).
  Future<List<MiseEnRelation>> relationsDuTransporteur(int auteurId) =>
      _relations('WHERE m.auteur_id = ?', [auteurId]);

  /// Propositions reçues par un voyageur.
  Future<List<MiseEnRelation>> relationsDuVoyageur(int voyageurId) =>
      _relations('WHERE m.voyageur_id = ?', [voyageurId]);

  /// Un transporteur propose un voyageur pour une commande encore ouverte.
  /// Renvoie un message d'erreur, ou null si tout est correct.
  Future<String?> proposerVoyageur({
    required int commandeId,
    required int auteurId,
    required int voyageurId,
    int? transporteurId,
  }) async {
    final db = await _db.database;
    final c = await db.query('commande_transport',
        columns: ['statut'], where: 'id = ?', whereArgs: [commandeId], limit: 1);
    if (c.isEmpty) return 'Commande introuvable';
    if (c.first['statut'] != 'ouverte') return "Cette commande n'est plus ouverte";
    final deja = await db.query('mise_en_relation',
        where: "commande_id = ? AND voyageur_id = ? AND statut <> 'refusee'",
        whereArgs: [commandeId, voyageurId], limit: 1);
    if (deja.isNotEmpty) return 'Ce voyageur a déjà été proposé pour cette commande';
    await db.insert(
        'mise_en_relation',
        MiseEnRelation(
          commandeId: commandeId,
          auteurId: auteurId,
          voyageurId: voyageurId,
          transporteurId: transporteurId,
          creeLe: DateTime.now(),
        ).toMapCreation());
    return null;
  }

  /// Le voyageur accepte ou refuse. Accepter ferme la commande (statut acceptee,
  /// voyageur_id renseigné) et refuse les autres propositions en attente.
  /// Renvoie un message d'erreur, ou null si tout est correct.
  Future<String?> repondreProposition({
    required int relationId,
    required int voyageurId,
    required bool accepter,
  }) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.query('mise_en_relation',
          where: 'id = ?', whereArgs: [relationId], limit: 1);
      if (rows.isEmpty) return 'Proposition introuvable';
      final m = MiseEnRelation.fromMap(rows.first);
      if (m.voyageurId != voyageurId) return 'Action non autorisée';
      if (m.statut != StatutRelation.proposee) {
        return 'Cette proposition a déjà été traitée';
      }
      if (!accepter) {
        await txn.update('mise_en_relation', {'statut': 'refusee'},
            where: 'id = ?', whereArgs: [relationId]);
        return null;
      }
      final ouvertes = await txn.update(
          'commande_transport', {'statut': 'acceptee', 'voyageur_id': voyageurId},
          where: "id = ? AND statut = 'ouverte'", whereArgs: [m.commandeId]);
      if (ouvertes == 0) return "Cette commande n'est plus disponible";
      await txn.update('mise_en_relation', {'statut': 'acceptee'},
          where: 'id = ?', whereArgs: [relationId]);
      await txn.update('mise_en_relation', {'statut': 'refusee'},
          where: "commande_id = ? AND id <> ? AND statut = 'proposee'",
          whereArgs: [m.commandeId, relationId]);
      return null;
    });
  }

  // ------------------------------------------------------------------
  // Candidats voyageurs (base du classement)
  // ------------------------------------------------------------------

  /// Tous les voyageurs avec leurs voyages (table "voyage" du module voyage).
  Future<List<VoyageurCandidat>> voyageursCandidats() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT u.id, u.prenom || ' ' || u.nom AS nom,
             v.destination, v.date_debut, v.date_fin
      FROM utilisateur u
      LEFT JOIN voyage v ON v.utilisateur_id = u.id
      WHERE u.role = 'traveller'
      ORDER BY u.nom, u.id
    ''');
    final noms = <int, String>{};
    final voyages = <int, List<VoyageTrajet>>{};
    for (final r in rows) {
      final id = r['id'] as int;
      noms[id] = r['nom'] as String;
      voyages.putIfAbsent(id, () => []);
      final debut = DateTime.tryParse((r['date_debut'] as String?) ?? '');
      final fin = DateTime.tryParse((r['date_fin'] as String?) ?? '');
      if (r['destination'] != null && debut != null && fin != null) {
        voyages[id]!.add(VoyageTrajet(
          destination: r['destination'] as String,
          dateDebut: debut,
          dateFin: fin,
        ));
      }
    }
    return [
      for (final id in noms.keys)
        VoyageurCandidat(id: id, nom: noms[id]!, voyages: voyages[id]!),
    ];
  }
}
