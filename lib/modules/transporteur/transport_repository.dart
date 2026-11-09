import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import 'models/commande_transport.dart';
import 'models/mise_en_relation.dart';
import 'models/reservation_transport.dart';
import 'models/trajet_transport.dart';
import 'models/transporteur.dart';
import 'transport_format.dart';

/// Critères de tri de la recherche voyageur (libellés affichés dans l'écran).
enum TriTrajet {
  dateDepart('Date de départ'),
  prixCroissant('Prix le plus bas'),
  placesLibres('Plus de places libres');

  final String libelle;

  const TriTrajet(this.libelle);
}

/// Une page de résultats de recherche, avec le total pour la pagination.
class PageTrajets {
  static const int tailleDefaut = 10;

  final List<TrajetTransport> trajets;
  final int total;
  final int page;
  final int taillePage;

  const PageTrajets({
    required this.trajets,
    required this.total,
    required this.page,
    required this.taillePage,
  });

  int get nombrePages => total == 0 ? 1 : (total + taillePage - 1) ~/ taillePage;

  bool get aPrecedente => page > 1;

  bool get aSuivante => page < nombrePages;
}

/// Accès SQLite du module transporteur. Les écrans n'écrivent jamais en base directement.
///
/// Règles appliquées ici, et non dans l'interface :
///  - un compte transporteur a un seul profil ; seul ce compte modifie ses trajets ;
///  - une commande du voyageur est proposée automatiquement aux transporteurs dont un
///    trajet correspond : même départ, même arrivée, même jour, assez de places,
///    budget respecté ;
///  - accepter une proposition crée la réservation confirmée, accepte la commande et
///    refuse les autres propositions ;
///  - le voyageur annule une réservation au plus tard 24 h avant le départ ; le
///    transporteur peut l'annuler à tout moment, avec un motif ;
///  - les coordonnées ne sortent de la base qu'après acceptation (CASE WHEN en SQL).
class TransportRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Délai minimal avant le départ pour qu'un voyageur annule une réservation.
  static const Duration delaiAnnulationVoyageur = Duration(hours: 24);

  /// Places réservées (réservations non annulées) du trajet alias « tt ».
  static const String _placesReservees =
      "(SELECT COALESCE(SUM(r.nombre_places), 0) FROM reservation_transport r "
      "WHERE r.trajet_id = tt.id AND r.statut <> 'annulee')";

  // ------------------------------------------------------------------
  // Outils internes
  // ------------------------------------------------------------------

  static String _maintenant() => DateTime.now().toUtc().toIso8601String();

  Future<void> _journaliser(
      DatabaseExecutor db, int reservationId, String evenement) async {
    await db.insert('historique_reservation', {
      'reservation_id': reservationId,
      'evenement': evenement,
      'cree_le': _maintenant(),
    });
  }

  Future<void> _annulerReservationEn(DatabaseExecutor db, int reservationId,
      String motif, String evenement) async {
    await db.update(
      'reservation_transport',
      {'statut': StatutReservation.annulee.valeur, 'motif_annulation': motif},
      where: 'id = ?',
      whereArgs: [reservationId],
    );
    await _journaliser(db, reservationId, evenement);
  }

  Future<int?> _profilId(DatabaseExecutor db, int utilisateurId) async {
    final rows = await db.query('transporteur',
        columns: ['id'],
        where: 'utilisateur_id = ?',
        whereArgs: [utilisateurId],
        limit: 1);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  // ------------------------------------------------------------------
  // Profil transporteur (un par compte)
  // ------------------------------------------------------------------

  static String get _selectProfil => '''
    SELECT t.*,
      (SELECT COUNT(*) FROM trajet_transport tt WHERE tt.transporteur_id = t.id) AS nb_trajets
    FROM transporteur t
  ''';

  /// Profil du compte, ou null si le compte n'en a pas encore créé.
  Future<Transporteur?> profilDe(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectProfil WHERE t.utilisateur_id = ?', [utilisateurId]);
    return rows.isEmpty ? null : Transporteur.fromMap(rows.first);
  }

  /// Crée le profil. Renvoie un message d'erreur, ou null.
  Future<String?> creerProfil(Transporteur t) async {
    final db = await _db.database;
    if (await _profilId(db, t.utilisateurId) != null) {
      return 'Ce compte a déjà un profil';
    }
    await db.insert('transporteur', t.toMapCreation());
    return null;
  }

  /// Modifie le profil seulement s'il appartient au compte.
  Future<bool> modifierProfil(Transporteur t) async {
    final id = t.id;
    if (id == null) return false;
    final db = await _db.database;
    final n = await db.update('transporteur', t.toMapSaisie(),
        where: 'id = ? AND utilisateur_id = ?',
        whereArgs: [id, t.utilisateurId]);
    return n > 0;
  }

  /// Désactive ou réactive le profil : il disparaît des recherches, mais reste en base.
  Future<bool> changerActivite(int utilisateurId, {required bool actif}) async {
    final db = await _db.database;
    final n = await db.update('transporteur', {'actif': actif ? 1 : 0},
        where: 'utilisateur_id = ?', whereArgs: [utilisateurId]);
    return n > 0;
  }

  // ------------------------------------------------------------------
  // Trajets (trajet_transport)
  // ------------------------------------------------------------------

  static String get _selectTrajet => '''
    SELECT tt.*, tr.nom AS nom_transporteur, $_placesReservees AS places_reservees
    FROM trajet_transport tt
    JOIN transporteur tr ON tr.id = tt.transporteur_id
  ''';

  /// Trajet « tt » seulement s'il appartient au compte connecté.
  Future<TrajetTransport?> _trajetAuTransporteur(
      DatabaseExecutor db, int trajetId, int utilisateurId) async {
    final rows = await db.rawQuery(
        '$_selectTrajet WHERE tt.id = ? AND tr.utilisateur_id = ?',
        [trajetId, utilisateurId]);
    return rows.isEmpty ? null : TrajetTransport.fromMap(rows.first);
  }

  /// Tous les trajets du transporteur connecté, quel que soit leur statut.
  Future<List<TrajetTransport>> trajetsDuTransporteur(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectTrajet WHERE tr.utilisateur_id = ? ORDER BY tt.date_depart',
        [utilisateurId]);
    return rows.map(TrajetTransport.fromMap).toList();
  }

  /// Ordre SQL de chaque tri (valeurs fixes, jamais saisies par l'utilisateur).
  static String _ordre(TriTrajet tri) => switch (tri) {
        TriTrajet.dateDepart => 'tt.date_depart ASC, tt.id ASC',
        TriTrajet.prixCroissant => 'tt.prix_par_personne ASC, tt.date_depart ASC',
        TriTrajet.placesLibres =>
          '(tt.places_totales - $_placesReservees) DESC, tt.date_depart ASC',
      };

  /// Recherche d'un voyageur : trajets planifiés, à venir, de transporteurs actifs.
  /// Renvoie une page de résultats avec le total, pour la pagination de l'écran.
  Future<PageTrajets> rechercherTrajets({
    String? depart,
    String? arrivee,
    DateTime? jour,
    TriTrajet tri = TriTrajet.dateDepart,
    int page = 1,
    int taillePage = PageTrajets.tailleDefaut,
  }) async {
    final db = await _db.database;
    final conditions = [
      "tt.statut = 'planifie'",
      'tr.actif = 1',
      'tt.date_depart >= ?',
    ];
    final args = <Object?>[TransportFormat.dateHeureIso(DateTime.now())];
    final d = depart?.trim() ?? '';
    final a = arrivee?.trim() ?? '';
    if (d.isNotEmpty) {
      conditions.add('LOWER(tt.ville_depart) = LOWER(?)');
      args.add(d);
    }
    if (a.isNotEmpty) {
      conditions.add('LOWER(tt.destination) = LOWER(?)');
      args.add(a);
    }
    if (jour != null) {
      conditions.add('substr(tt.date_depart, 1, 10) = ?');
      args.add(TransportFormat.jourIso(jour));
    }
    final where = conditions.join(' AND ');

    final total = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM trajet_transport tt '
          'JOIN transporteur tr ON tr.id = tt.transporteur_id WHERE $where',
          args,
        )) ??
        0;
    final taille = taillePage < 1 ? PageTrajets.tailleDefaut : taillePage;
    final pages = total == 0 ? 1 : (total + taille - 1) ~/ taille;
    final numero = page < 1 ? 1 : (page > pages ? pages : page);

    final rows = await db.rawQuery(
        '$_selectTrajet WHERE $where ORDER BY ${_ordre(tri)} LIMIT ? OFFSET ?',
        [...args, taille, (numero - 1) * taille]);
    return PageTrajets(
      trajets: rows.map(TrajetTransport.fromMap).toList(),
      total: total,
      page: numero,
      taillePage: taille,
    );
  }

  /// Ajoute un trajet au profil du compte. Renvoie un message d'erreur, ou null.
  Future<String?> creerTrajet(TrajetTransport t, int utilisateurId) async {
    final db = await _db.database;
    final profil = await _profilId(db, utilisateurId);
    if (profil == null) return "Créez d'abord votre profil transporteur";
    if (profil != t.transporteurId) return 'Action non autorisée';
    await db.transaction((txn) async {
      final id = await txn.insert('trajet_transport', t.toMapCreation());
      await _proposerCommandesOuvertes(txn, id);
    });
    return null;
  }

  /// Modifie un trajet planifié. Les places ne peuvent pas descendre sous les
  /// réservations existantes. Le statut ne se change que par [changerStatutTrajet].
  Future<String?> modifierTrajet(TrajetTransport t, int utilisateurId) async {
    final id = t.id;
    if (id == null) return 'Trajet introuvable';
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final actuel = await _trajetAuTransporteur(txn, id, utilisateurId);
      if (actuel == null) return 'Trajet introuvable';
      if (actuel.statut != StatutTrajet.planifie) {
        return 'Seul un trajet planifié peut être modifié';
      }
      if (t.placesTotales < actuel.placesReservees) {
        return 'Il y a déjà ${actuel.placesReservees} place(s) réservée(s)';
      }
      final valeurs = t.toMapSaisie()..remove('statut');
      await txn.update('trajet_transport', valeurs,
          where: 'id = ?', whereArgs: [id]);
      await _proposerCommandesOuvertes(txn, id);
      return null;
    });
  }

  /// Copie un trajet à une autre date : même heure, même durée, mêmes places.
  /// Le nouveau trajet est planifié.
  Future<String?> dupliquerTrajet(
      int trajetId, int utilisateurId, DateTime nouvelleDate) async {
    final db = await _db.database;
    final t = await _trajetAuTransporteur(db, trajetId, utilisateurId);
    if (t == null) return 'Trajet introuvable';
    final debut = DateTime(nouvelleDate.year, nouvelleDate.month,
        nouvelleDate.day, t.dateDepart.hour, t.dateDepart.minute);
    final fin = debut.add(t.dateArriveeEstimee.difference(t.dateDepart));
    final copie = TrajetTransport(
      transporteurId: t.transporteurId,
      villeDepart: t.villeDepart,
      destination: t.destination,
      adresseDepart: t.adresseDepart,
      adresseArrivee: t.adresseArrivee,
      dateDepart: debut,
      dateArriveeEstimee: fin,
      prixParPersonne: t.prixParPersonne,
      placesTotales: t.placesTotales,
      typeTransport: t.typeTransport,
      arrets: t.arrets,
      creeLe: DateTime.now(),
    );
    await db.transaction((txn) async {
      final id = await txn.insert('trajet_transport', copie.toMapCreation());
      await _proposerCommandesOuvertes(txn, id);
    });
    return null;
  }

  /// Change le statut : planifié → en cours ou annulé ; en cours → terminé.
  /// Annuler un trajet annule ses réservations ; le terminer clôt les commandes acceptées.
  Future<String?> changerStatutTrajet(
      int trajetId, int utilisateurId, StatutTrajet nouveau) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final t = await _trajetAuTransporteur(txn, trajetId, utilisateurId);
      if (t == null) return 'Trajet introuvable';
      final transitionOk =
          (t.statut == StatutTrajet.planifie &&
                  (nouveau == StatutTrajet.enCours ||
                      nouveau == StatutTrajet.annule)) ||
              (t.statut == StatutTrajet.enCours &&
                  nouveau == StatutTrajet.termine);
      if (!transitionOk) return 'Changement de statut impossible';

      await txn.update('trajet_transport', {'statut': nouveau.valeur},
          where: 'id = ?', whereArgs: [trajetId]);

      if (nouveau == StatutTrajet.annule) {
        final reservations = await txn.rawQuery(
            "SELECT id, commande_id FROM reservation_transport "
            "WHERE trajet_id = ? AND statut <> 'annulee'",
            [trajetId]);
        for (final r in reservations) {
          const motif = 'Trajet annulé par le transporteur';
          await _annulerReservationEn(txn, r['id'] as int, motif, motif);
          if (r['commande_id'] != null) {
            await txn.update('commande_transport',
                {'statut': StatutCommande.annulee.valeur},
                where: 'id = ?', whereArgs: [r['commande_id']]);
          }
        }
      }
      if (nouveau == StatutTrajet.annule) {
        // Les propositions encore en attente sur ce trajet ne peuvent plus être acceptées.
        await txn.update(
            'mise_en_relation',
            {'statut': StatutRelation.refusee.valeur, 'repondu_le': _maintenant()},
            where: "trajet_id = ? AND statut = 'proposee'",
            whereArgs: [trajetId]);
        // Une commande qui n'a plus aucune proposition en attente est refusée.
        await txn.rawUpdate('''
          UPDATE commande_transport SET statut = ?
          WHERE statut = 'EN_ATTENTE'
            AND id IN (SELECT commande_id FROM mise_en_relation WHERE trajet_id = ?)
            AND NOT EXISTS (
              SELECT 1 FROM mise_en_relation m
              WHERE m.commande_id = commande_transport.id AND m.statut = 'proposee')
        ''', [StatutCommande.refusee.valeur, trajetId]);
      }
      if (nouveau == StatutTrajet.termine) {
        final commandes = await txn.rawQuery(
            "SELECT commande_id FROM reservation_transport WHERE trajet_id = ? "
            "AND statut <> 'annulee' AND commande_id IS NOT NULL",
            [trajetId]);
        for (final c in commandes) {
          await txn.update('commande_transport',
              {'statut': StatutCommande.termine.valeur},
              where: "id = ? AND statut = 'ACCEPTEE'",
              whereArgs: [c['commande_id']]);
        }
      }
      return null;
    });
  }

  /// Supprime un trajet sans réservation active. Sinon, annuler les réservations d'abord.
  Future<String?> supprimerTrajet(int trajetId, int utilisateurId) async {
    final db = await _db.database;
    final t = await _trajetAuTransporteur(db, trajetId, utilisateurId);
    if (t == null) return 'Trajet introuvable';
    if (t.placesReservees > 0) {
      return "Annulez d'abord les réservations de ce trajet";
    }
    await db.delete('trajet_transport', where: 'id = ?', whereArgs: [trajetId]);
    return null;
  }

  // ------------------------------------------------------------------
  // Commandes du voyageur (commande_transport)
  // ------------------------------------------------------------------

  static String get _selectCommande => '''
    SELECT c.*,
      vo.prenom || ' ' || vo.nom AS nom_voyageur,
      (SELECT COUNT(*) FROM mise_en_relation m WHERE m.commande_id = c.id) AS nb_propositions,
      CASE WHEN c.statut IN ('ACCEPTEE', 'termine') THEN tr.nom END AS nom_transporteur,
      CASE WHEN c.statut IN ('ACCEPTEE', 'termine') THEN tr.telephone END AS telephone_transporteur,
      r.id AS reservation_id
    FROM commande_transport c
    JOIN utilisateur vo ON vo.id = c.voyageur_id
    LEFT JOIN reservation_transport r ON r.commande_id = c.id AND r.statut <> 'annulee'
    LEFT JOIN trajet_transport tt ON tt.id = r.trajet_id
    LEFT JOIN transporteur tr ON tr.id = tt.transporteur_id
  ''';

  /// Commandes du voyageur, de la plus proche à la plus lointaine.
  Future<List<CommandeTransport>> commandesDuVoyageur(int voyageurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectCommande WHERE c.voyageur_id = ? ORDER BY c.date_voyage, c.id',
        [voyageurId]);
    return rows.map(CommandeTransport.fromMap).toList();
  }

  /// Crée la commande, puis la propose aux transporteurs compatibles.
  /// Renvoie l'id et le nombre de transporteurs sollicités.
  Future<({int id, int propositions})> creerCommande(
      CommandeTransport c) async {
    final db = await _db.database;
    final reference =
        'CMD-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    return db.transaction<({int id, int propositions})>((txn) async {
      final id = await txn.insert(
          'commande_transport', {...c.toMapCreation(), 'reference': reference});
      final n = await _proposerAuxTransporteurs(txn, id, c);
      return (id: id, propositions: n);
    });
  }

  /// Crée une proposition pour chaque trajet compatible, du plus proche en heure
  /// au plus loin. Renvoie le nombre de propositions créées.
  /// Les villes sont comparées sans casse ni accents ; le jour, les places et le budget
  /// sont filtrés en SQL.
  Future<int> _proposerAuxTransporteurs(
      DatabaseExecutor db, int commandeId, CommandeTransport c) async {
    final rows = await db.rawQuery('''
      SELECT tt.id AS trajet_id, tt.transporteur_id, tt.ville_depart, tt.destination
      FROM trajet_transport tt
      JOIN transporteur tr ON tr.id = tt.transporteur_id
      WHERE tr.actif = 1 AND tr.disponible = 1
        AND tt.statut = 'planifie'
        AND substr(tt.date_depart, 1, 10) = ?
        AND (tt.places_totales - $_placesReservees) >= ?
        AND (? = 0 OR tt.prix_par_personne * ? <= ?)
      ORDER BY ABS(julianday(tt.date_depart) - julianday(?))
    ''', [
      TransportFormat.jourIso(c.dateVoyage),
      c.nombrePassagers,
      c.prixPropose,
      c.nombrePassagers,
      c.prixPropose,
      TransportFormat.dateHeureIso(c.dateVoyage),
    ]);
    final compatibles = rows
        .where((r) =>
            TransportFormat.memeVille(r['ville_depart'] as String, c.depart) &&
            TransportFormat.memeVille(r['destination'] as String, c.arrivee))
        .toList();
    for (final r in compatibles) {
      await db.insert(
        'mise_en_relation',
        {
          'commande_id': commandeId,
          'trajet_id': r['trajet_id'],
          'transporteur_id': r['transporteur_id'],
          'statut': StatutRelation.proposee.valeur,
          'cree_le': _maintenant(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return compatibles.length;
  }

  /// Sens inverse : un trajet publié ou modifié est proposé aux commandes ouvertes
  /// compatibles. Sans cela, une demande déposée avant le trajet ne l'atteindrait jamais.
  Future<void> _proposerCommandesOuvertes(
      DatabaseExecutor db, int trajetId) async {
    final trajets = await db.rawQuery('''
      SELECT tt.transporteur_id, tt.ville_depart, tt.destination, tt.date_depart,
             tt.prix_par_personne,
             (tt.places_totales - $_placesReservees) AS places_libres
      FROM trajet_transport tt
      JOIN transporteur tr ON tr.id = tt.transporteur_id
      WHERE tt.id = ? AND tr.actif = 1 AND tr.disponible = 1 AND tt.statut = 'planifie'
    ''', [trajetId]);
    if (trajets.isEmpty) return;
    final t = trajets.first;
    final commandes = await db.rawQuery('''
      SELECT id, depart, arrivee, nombre_passagers, prix_propose
      FROM commande_transport
      WHERE statut = 'EN_ATTENTE' AND substr(date_voyage, 1, 10) = ?
    ''', [(t['date_depart'] as String).substring(0, 10)]);
    final prix = (t['prix_par_personne'] as num).toDouble();
    final places = (t['places_libres'] as num).toInt();
    for (final c in commandes) {
      final passagers = c['nombre_passagers'] as int;
      final budget = (c['prix_propose'] as num).toDouble();
      if (places < passagers) continue;
      if (budget > 0 && prix * passagers > budget) continue;
      if (!TransportFormat.memeVille(t['ville_depart'] as String, c['depart'] as String)) {
        continue;
      }
      if (!TransportFormat.memeVille(t['destination'] as String, c['arrivee'] as String)) {
        continue;
      }
      await db.insert(
        'mise_en_relation',
        {
          'commande_id': c['id'],
          'trajet_id': trajetId,
          'transporteur_id': t['transporteur_id'],
          'statut': StatutRelation.proposee.valeur,
          'cree_le': _maintenant(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Modifie une commande en attente, puis relance la recherche de transporteurs.
  /// Renvoie un message d'erreur, ou null.
  Future<String?> modifierCommande(CommandeTransport c, int voyageurId) async {
    final id = c.id;
    if (id == null) return 'Commande introuvable';
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.query('commande_transport',
          where: 'id = ? AND voyageur_id = ?',
          whereArgs: [id, voyageurId],
          limit: 1);
      if (rows.isEmpty) return 'Commande introuvable';
      if (StatutCommande.depuis(rows.first['statut'] as String) !=
          StatutCommande.enAttente) {
        return 'Cette commande ne peut plus être modifiée';
      }
      await txn.update('commande_transport', c.toMapSaisie(),
          where: 'id = ?', whereArgs: [id]);
      await txn.delete('mise_en_relation',
          where: "commande_id = ? AND statut = 'proposee'", whereArgs: [id]);
      await _proposerAuxTransporteurs(txn, id, c);
      return null;
    });
  }

  /// Annule une commande du voyageur.
  /// - En attente : annulation libre, les propositions en cours sont retirées.
  /// - Acceptée : annulation de la réservation, au plus tard 24 h avant le départ,
  ///   avec un motif obligatoire.
  Future<String?> annulerCommande(int id, int voyageurId,
      {String motif = ''}) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.query('commande_transport',
          where: 'id = ? AND voyageur_id = ?',
          whereArgs: [id, voyageurId],
          limit: 1);
      if (rows.isEmpty) return 'Commande introuvable';
      final statut = StatutCommande.depuis(rows.first['statut'] as String);

      if (statut == StatutCommande.enAttente) {
        await txn.update('commande_transport',
            {'statut': StatutCommande.annulee.valeur},
            where: 'id = ?', whereArgs: [id]);
        await txn.update(
            'mise_en_relation',
            {'statut': StatutRelation.refusee.valeur, 'repondu_le': _maintenant()},
            where: "commande_id = ? AND statut = 'proposee'",
            whereArgs: [id]);
        return null;
      }
      if (statut != StatutCommande.acceptee) {
        return 'Cette commande ne peut plus être annulée';
      }

      final reservations = await txn.rawQuery(
          "SELECT r.id, tt.date_depart FROM reservation_transport r "
          "JOIN trajet_transport tt ON tt.id = r.trajet_id "
          "WHERE r.commande_id = ? AND r.statut <> 'annulee' LIMIT 1",
          [id]);
      if (reservations.isEmpty) {
        await txn.update('commande_transport',
            {'statut': StatutCommande.annulee.valeur},
            where: 'id = ?', whereArgs: [id]);
        return null;
      }
      final depart = DateTime.parse(reservations.first['date_depart'] as String);
      if (motif.trim().isEmpty) return "Indiquez le motif de l'annulation";
      if (depart.difference(DateTime.now()) < delaiAnnulationVoyageur) {
        return "Annulation impossible moins de 24 h avant le départ";
      }
      final texte = motif.trim();
      await _annulerReservationEn(txn, reservations.first['id'] as int, texte,
          'Annulée par le voyageur : $texte');
      await txn.update('commande_transport',
          {'statut': StatutCommande.annulee.valeur},
          where: 'id = ?', whereArgs: [id]);
      return null;
    });
  }

  /// Supprime une commande qui n'est ni acceptée ni terminée.
  Future<String?> supprimerCommande(int id, int voyageurId) async {
    final db = await _db.database;
    final n = await db.delete('commande_transport',
        where: "id = ? AND voyageur_id = ? "
            "AND statut IN ('EN_ATTENTE', 'REFUSEE', 'ANNULEE')",
        whereArgs: [id, voyageurId]);
    return n > 0
        ? null
        : 'Seule une commande en attente, refusée ou annulée peut être supprimée';
  }

  // ------------------------------------------------------------------
  // Mises en relation (mise_en_relation), vues par le transporteur
  // ------------------------------------------------------------------

  static String get _selectRelation => '''
    SELECT m.*,
      c.reference, c.depart, c.arrivee, c.date_voyage, c.nombre_passagers, c.prix_propose,
      vo.prenom || ' ' || vo.nom AS nom_voyageur,
      CASE WHEN m.statut = 'acceptee' THEN vo.telephone END AS telephone_voyageur,
      tt.date_depart, tt.prix_par_personne, tt.statut AS statut_trajet,
      (tt.places_totales - $_placesReservees) AS places_libres,
      tr.nom AS nom_transporteur
    FROM mise_en_relation m
    JOIN commande_transport c ON c.id = m.commande_id
    JOIN utilisateur vo ON vo.id = c.voyageur_id
    JOIN trajet_transport tt ON tt.id = m.trajet_id
    JOIN transporteur tr ON tr.id = m.transporteur_id
  ''';

  /// Propositions reçues par le transporteur connecté, éventuellement filtrées par statut.
  Future<List<MiseEnRelation>> relationsDuTransporteur(int utilisateurId,
      {StatutRelation? statut}) async {
    final db = await _db.database;
    final filtre = statut == null ? '' : 'AND m.statut = ?';
    final rows = await db.rawQuery(
        '$_selectRelation WHERE tr.utilisateur_id = ? $filtre '
        'ORDER BY m.cree_le DESC',
        [utilisateurId, if (statut != null) statut.valeur]);
    return rows.map(MiseEnRelation.fromMap).toList();
  }

  /// Le transporteur accepte ou refuse une proposition.
  /// Accepter crée la réservation confirmée (si les places suffisent), accepte la
  /// commande et refuse les autres propositions. Refuser la dernière proposition
  /// en attente refuse la commande. Renvoie un message d'erreur, ou null.
  Future<String?> repondreProposition({
    required int relationId,
    required int utilisateurId,
    required bool accepter,
  }) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.rawQuery(
          '$_selectRelation WHERE m.id = ? AND tr.utilisateur_id = ?',
          [relationId, utilisateurId]);
      if (rows.isEmpty) return 'Proposition introuvable';
      final m = MiseEnRelation.fromMap(rows.first);
      if (!m.enAttente) return 'Cette proposition a déjà été traitée';
      final maintenant = _maintenant();

      if (!accepter) {
        await txn.update(
            'mise_en_relation',
            {'statut': StatutRelation.refusee.valeur, 'repondu_le': maintenant},
            where: 'id = ?',
            whereArgs: [relationId]);
        final encore = await txn.query('mise_en_relation',
            where: "commande_id = ? AND statut = 'proposee'",
            whereArgs: [m.commandeId],
            limit: 1);
        if (encore.isEmpty) {
          await txn.update('commande_transport',
              {'statut': StatutCommande.refusee.valeur},
              where: "id = ? AND statut = 'EN_ATTENTE'",
              whereArgs: [m.commandeId]);
        }
        return null;
      }

      final partAt = DateTime.parse(rows.first['date_depart'] as String);
      if (rows.first['statut_trajet'] != StatutTrajet.planifie.valeur ||
          partAt.isBefore(DateTime.now())) {
        return "Ce trajet n'est plus disponible";
      }

      final commande = await txn.query('commande_transport',
          columns: ['statut', 'voyageur_id'],
          where: 'id = ?',
          whereArgs: [m.commandeId],
          limit: 1);
      if (commande.isEmpty ||
          commande.first['statut'] != StatutCommande.enAttente.valeur) {
        return "Cette commande n'est plus disponible";
      }
      if (m.placesLibres < m.nombrePassagers) {
        return "Il n'y a plus assez de places sur ce trajet";
      }

      final reservationId = await txn.insert('reservation_transport', {
        'trajet_id': m.trajetId,
        'voyageur_id': commande.first['voyageur_id'],
        'commande_id': m.commandeId,
        'nombre_places': m.nombrePassagers,
        'statut': StatutReservation.confirmee.valeur,
        'motif_annulation': '',
        'cree_le': maintenant,
      });
      await _journaliser(
          txn, reservationId, 'Réservation confirmée par le transporteur');
      await txn.update('commande_transport',
          {'statut': StatutCommande.acceptee.valeur},
          where: 'id = ?', whereArgs: [m.commandeId]);
      await txn.update(
          'mise_en_relation',
          {'statut': StatutRelation.acceptee.valeur, 'repondu_le': maintenant},
          where: 'id = ?',
          whereArgs: [relationId]);
      await txn.update(
          'mise_en_relation',
          {'statut': StatutRelation.refusee.valeur, 'repondu_le': maintenant},
          where: "commande_id = ? AND statut = 'proposee'",
          whereArgs: [m.commandeId]);
      return null;
    });
  }

  // ------------------------------------------------------------------
  // Réservations confirmées (reservation_transport)
  // ------------------------------------------------------------------

  static String get _selectReservation => '''
    SELECT r.*,
      vo.prenom || ' ' || vo.nom AS nom_voyageur,
      vo.telephone AS telephone_voyageur,
      tt.ville_depart, tt.destination, tt.date_depart, tt.prix_par_personne,
      tr.nom AS nom_transporteur,
      tr.telephone AS telephone_transporteur
    FROM reservation_transport r
    JOIN utilisateur vo ON vo.id = r.voyageur_id
    JOIN trajet_transport tt ON tt.id = r.trajet_id
    JOIN transporteur tr ON tr.id = tt.transporteur_id
  ''';

  /// Passagers et réservations des trajets du transporteur, éventuellement d'un seul trajet.
  Future<List<ReservationTransport>> reservationsDuTransporteur(
      int utilisateurId, {int? trajetId}) async {
    final db = await _db.database;
    final filtre = trajetId == null ? '' : 'AND r.trajet_id = ?';
    final rows = await db.rawQuery(
        '$_selectReservation WHERE tr.utilisateur_id = ? $filtre '
        'ORDER BY tt.date_depart, r.id',
        [utilisateurId, if (trajetId != null) trajetId]);
    return rows.map(ReservationTransport.fromMap).toList();
  }

  /// Réservations du voyageur.
  Future<List<ReservationTransport>> reservationsDuVoyageur(
      int voyageurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectReservation WHERE r.voyageur_id = ? ORDER BY tt.date_depart DESC',
        [voyageurId]);
    return rows.map(ReservationTransport.fromMap).toList();
  }

  /// Historique d'une réservation, du plus ancien au plus récent.
  Future<List<EvenementReservation>> historique(int reservationId) async {
    final db = await _db.database;
    final rows = await db.query('historique_reservation',
        where: 'reservation_id = ?',
        whereArgs: [reservationId],
        orderBy: 'id');
    return rows.map(EvenementReservation.fromMap).toList();
  }

  /// Le transporteur confirme la prise en charge du voyageur.
  Future<String?> confirmerPriseEnCharge(
      int reservationId, int utilisateurId) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.rawQuery(
          '$_selectReservation WHERE r.id = ? AND tr.utilisateur_id = ?',
          [reservationId, utilisateurId]);
      if (rows.isEmpty) return 'Réservation introuvable';
      final r = ReservationTransport.fromMap(rows.first);
      if (r.statut != StatutReservation.confirmee) {
        return 'Cette réservation ne peut pas être prise en charge';
      }
      await txn.update('reservation_transport',
          {'statut': StatutReservation.priseEnCharge.valeur},
          where: 'id = ?', whereArgs: [reservationId]);
      await _journaliser(txn, reservationId, 'Prise en charge confirmée');
      return null;
    });
  }

  /// Le transporteur annule une réservation, avec un motif obligatoire.
  Future<String?> annulerReservationParTransporteur(
      int reservationId, int utilisateurId,
      {required String motif}) async {
    final texte = motif.trim();
    if (texte.isEmpty) return "Indiquez le motif de l'annulation";
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.rawQuery(
          '$_selectReservation WHERE r.id = ? AND tr.utilisateur_id = ?',
          [reservationId, utilisateurId]);
      if (rows.isEmpty) return 'Réservation introuvable';
      final r = ReservationTransport.fromMap(rows.first);
      if (!r.active) return 'Cette réservation est déjà annulée';
      await _annulerReservationEn(txn, reservationId, texte,
          'Annulée par le transporteur : $texte');
      if (r.commandeId != null) {
        await txn.update('commande_transport',
            {'statut': StatutCommande.annulee.valeur},
            where: 'id = ?', whereArgs: [r.commandeId]);
      }
      return null;
    });
  }
}
