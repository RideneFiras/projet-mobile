import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/geo.dart';
import 'models/blocage_hebergement.dart';
import 'models/filtres_hebergement.dart';
import 'models/hebergement.dart';
import 'models/reservation_hebergement.dart';

/// Tri de la liste des établissements.
enum TriHebergement {
  nom('Nom'),
  prixCroissant('Prix croissant'),
  prixDecroissant('Prix décroissant'),
  note('Mieux notés'),
  popularite('Les plus réservés'),
  distance('Les plus proches');

  const TriHebergement(this.libelle);

  final String libelle;
}

/// Avis affiché sur la fiche d'un établissement (table "avis" du module forum).
typedef AvisHebergement = ({int note, String? commentaire, String auteur, DateTime creeLe});

/// Accès SQLite du module hébergement
/// (tables hebergement, reservation_hebergement et blocage_hebergement).
class HebergementRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------
  // Établissements
  // ------------------------------------------------------------------

  /// Recalcule note_moyenne et nb_avis depuis les avis du forum.
  /// [id] : un seul établissement, sinon tous.
  Future<void> actualiserNotes({int? id, DatabaseExecutor? executeur}) async {
    final db = executeur ?? await _db.database;
    await db.rawUpdate('''
      UPDATE hebergement SET
        note_moyenne = IFNULL((SELECT ROUND(AVG(a.note), 1) FROM avis a
          WHERE a.cible_type = 'hebergement' AND a.cible_id = hebergement.id), 0),
        nb_avis = (SELECT COUNT(*) FROM avis a
          WHERE a.cible_type = 'hebergement' AND a.cible_id = hebergement.id)
      ${id == null ? '' : 'WHERE id = ?'}
    ''', id == null ? const [] : [id]);
  }

  /// Popularité : nombre de séjours non annulés.
  static const String _select = '''
    SELECT h.*, (SELECT COUNT(*) FROM reservation_hebergement r
      WHERE r.hebergement_id = h.id AND r.statut <> 'annulee') AS nb_reservations
    FROM hebergement h
  ''';

  /// Liste filtrée et triée. Les [equipements] demandés doivent TOUS être présents.
  /// [filtres] regroupe tous les critères ; les paramètres nommés restent des raccourcis
  /// (ils priment sur [filtres]).
  Future<List<Hebergement>> hebergements({
    TypeHebergement? type,
    String? recherche,
    int? etoilesMin,
    double? prixMax,
    int? personnes,
    Set<Equipement>? equipements,
    bool ouvertsSeulement = false,
    TriHebergement tri = TriHebergement.nom,
    FiltresHebergement? filtres,
  }) async {
    final f = filtres ?? const FiltresHebergement();
    final db = await _db.database;
    await actualiserNotes(executeur: db);
    final conditions = <String>[];
    final args = <Object?>[];
    final typeChoisi = type ?? f.type;
    if (typeChoisi != null) {
      conditions.add('h.type = ?');
      args.add(typeChoisi.valeur);
    }
    if (ouvertsSeulement) conditions.add("h.statut = 'actif'");
    final etoiles = etoilesMin ?? f.etoilesMin;
    if (etoiles != null) {
      conditions.add('h.etoiles >= ?');
      args.add(etoiles);
    }
    final max = prixMax ?? f.prixMax;
    if (max != null) {
      conditions.add('h.prix_par_nuit <= ?');
      args.add(max);
    }
    if (f.prixMin != null) {
      conditions.add('h.prix_par_nuit >= ?');
      args.add(f.prixMin);
    }
    if (f.noteMin != null) {
      conditions.add('h.note_moyenne >= ? AND h.nb_avis > 0');
      args.add(f.noteMin);
    }
    final nbPersonnes = personnes ?? f.personnes;
    if (nbPersonnes != null) {
      conditions.add('h.capacite * h.nb_chambres >= ?');
      args.add(nbPersonnes);
    }
    if (f.aDates) {
      // Au moins une chambre libre sur la période et aucune fermeture.
      final arr = dateIso(f.arrivee!);
      final dep = dateIso(f.depart!);
      conditions.add('''h.nb_chambres > IFNULL((SELECT SUM(r.nb_chambres)
          FROM reservation_hebergement r
          WHERE r.hebergement_id = h.id AND r.statut NOT IN ('annulee', 'check_out')
            AND r.date_arrivee < ? AND r.date_depart > ?), 0)
        AND NOT EXISTS (SELECT 1 FROM blocage_hebergement b
          WHERE b.hebergement_id = h.id AND b.date_debut < ? AND b.date_fin >= ?)''');
      args.addAll([dep, arr, dep, arr]);
    }
    final r = (recherche ?? f.recherche)?.trim() ?? '';
    if (r.isNotEmpty) {
      conditions.add(
          "(h.nom || ' ' || h.adresse || ' ' || IFNULL(h.ville, '')) LIKE ? COLLATE NOCASE");
      args.add('%$r%');
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final ordre = switch (tri) {
      TriHebergement.prixCroissant => 'h.prix_par_nuit, h.nom COLLATE NOCASE',
      TriHebergement.prixDecroissant => 'h.prix_par_nuit DESC, h.nom COLLATE NOCASE',
      TriHebergement.note => 'h.note_moyenne DESC, h.nb_avis DESC, h.nom COLLATE NOCASE',
      TriHebergement.popularite => 'nb_reservations DESC, h.note_moyenne DESC',
      _ => 'h.nom COLLATE NOCASE',
    };
    final rows = await db.rawQuery('$_select $where ORDER BY $ordre', args);
    final voulus = equipements ?? f.equipements;
    // Équipements stockés en JSON : filtre côté Dart.
    final liste = rows
        .map(Hebergement.fromMap)
        .where((h) => voulus.every(h.possede))
        .toList();
    if (tri == TriHebergement.distance && f.aPositionRef) {
      double d(Hebergement h) => h.aPosition
          ? distanceKm(f.latitudeRef!, f.longitudeRef!, h.latitude!, h.longitude!)
          : double.infinity;
      liste.sort((a, b) => d(a).compareTo(d(b)));
    }
    return liste;
  }

  Future<Hebergement?> hebergement(int id) async {
    final db = await _db.database;
    await actualiserNotes(id: id, executeur: db);
    final rows = await db.rawQuery('$_select WHERE h.id = ? LIMIT 1', [id]);
    return rows.isEmpty ? null : Hebergement.fromMap(rows.first);
  }

  /// Derniers avis laissés sur l'établissement.
  Future<List<AvisHebergement>> avisDe(int hebergementId, {int limite = 5}) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT a.note, a.commentaire, a.cree_le, u.prenom || ' ' || u.nom AS auteur
      FROM avis a JOIN utilisateur u ON u.id = a.auteur_id
      WHERE a.cible_type = 'hebergement' AND a.cible_id = ?
      ORDER BY a.cree_le DESC, a.id DESC LIMIT ?
    ''', [hebergementId, limite]);
    return [
      for (final r in rows)
        (
          note: r['note'] as int,
          commentaire: r['commentaire'] as String?,
          auteur: r['auteur'] as String,
          creeLe: DateTime.parse(r['cree_le'] as String),
        ),
    ];
  }

  /// Répartition des notes : {5: 12, 4: 3, 3: 0, 2: 1, 1: 0}.
  Future<Map<int, int>> distributionNotes(int hebergementId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT note, COUNT(*) AS nb FROM avis
      WHERE cible_type = 'hebergement' AND cible_id = ?
      GROUP BY note
    ''', [hebergementId]);
    return {
      for (var n = 5; n >= 1; n--) n: 0,
      for (final r in rows)
        if ((r['note'] as int) >= 1 && (r['note'] as int) <= 5) r['note'] as int: r['nb'] as int,
    };
  }

  /// Lève [ArgumentError] si une règle n'est pas respectée.
  Future<int> creerHebergement(Hebergement h) async {
    _controler(h);
    final db = await _db.database;
    return db.insert('hebergement', h.toMap());
  }

  Future<void> modifierHebergement(Hebergement h) async {
    _controler(h);
    final db = await _db.database;
    await db.update('hebergement', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  /// Variante pour les écrans : renvoie un message d'erreur, ou null si enregistré.
  Future<String?> enregistrerHebergement(Hebergement h) async {
    final erreur = h.verifier();
    if (erreur != null) return erreur;
    if (h.id == null) {
      await creerHebergement(h);
    } else {
      await modifierHebergement(h);
    }
    return null;
  }

  Future<void> changerStatut(int id, StatutHebergement statut) async {
    final db = await _db.database;
    await db.update('hebergement', {'statut': statut.valeur},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Les séjours réservés dans cet établissement sont supprimés avec lui.
  Future<void> supprimerHebergement(int id) async {
    final db = await _db.database;
    await db.delete('hebergement', where: 'id = ?', whereArgs: [id]);
  }

  void _controler(Hebergement h) {
    final erreur = h.verifier();
    if (erreur != null) throw ArgumentError(erreur);
  }

  // ------------------------------------------------------------------
  // Disponibilités et fermetures
  // ------------------------------------------------------------------

  /// Chambres encore libres sur la période (séjours non annulés qui se chevauchent).
  /// Chevauchement : arrivée < autre départ ET départ > autre arrivée
  /// (on peut arriver le jour où un autre client part). Fermeture = 0 chambre.
  Future<int> chambresLibres(int hebergementId, DateTime arrivee, DateTime depart,
      {int? exclureId, DatabaseExecutor? executeur}) async {
    final db = executeur ?? await _db.database;
    final arr = dateIso(arrivee);
    final dep = dateIso(depart);
    final ferme = await db.rawQuery('''
      SELECT 1 FROM blocage_hebergement
      WHERE hebergement_id = ? AND date_debut < ? AND date_fin >= ? LIMIT 1
    ''', [hebergementId, dep, arr]);
    if (ferme.isNotEmpty) return 0;
    final rows = await db.rawQuery('''
      SELECT h.nb_chambres - IFNULL((
        SELECT SUM(r.nb_chambres) FROM reservation_hebergement r
        WHERE r.hebergement_id = h.id AND r.statut NOT IN ('annulee', 'check_out')
          AND r.id <> ? AND r.date_arrivee < ? AND r.date_depart > ?), 0) AS libres
      FROM hebergement h WHERE h.id = ?
    ''', [exclureId ?? -1, dep, arr, hebergementId]);
    return rows.isEmpty ? 0 : (rows.first['libres'] as int);
  }

  /// Nuits complètes (toutes les chambres prises) ou fermées dans les [jours] à venir,
  /// pour griser le calendrier. [exclureId] : séjour en cours de modification.
  Future<Set<DateTime>> nuitsIndisponibles(int hebergementId,
      {int jours = 365, int? exclureId}) async {
    final db = await _db.database;
    final auj = dateJour(DateTime.now());
    final fin = DateTime(auj.year, auj.month, auj.day + jours);
    final h = await db.query('hebergement',
        columns: ['nb_chambres'], where: 'id = ?', whereArgs: [hebergementId], limit: 1);
    if (h.isEmpty) return {};
    final capacite = h.first['nb_chambres'] as int;
    final occupation = <DateTime, int>{};
    final sejours = await db.rawQuery('''
      SELECT date_arrivee, date_depart, nb_chambres FROM reservation_hebergement
      WHERE hebergement_id = ? AND statut NOT IN ('annulee', 'check_out') AND id <> ?
        AND date_depart > ? AND date_arrivee < ?
    ''', [hebergementId, exclureId ?? -1, dateIso(auj), dateIso(fin)]);
    for (final s in sejours) {
      var j = dateJour(DateTime.parse(s['date_arrivee'] as String));
      final d = dateJour(DateTime.parse(s['date_depart'] as String));
      while (j.isBefore(d)) {
        occupation[j] = (occupation[j] ?? 0) + (s['nb_chambres'] as int);
        j = DateTime(j.year, j.month, j.day + 1);
      }
    }
    final pleines = {
      for (final e in occupation.entries)
        if (e.value >= capacite) e.key,
    };
    for (final b in await blocagesDe(hebergementId)) {
      var j = dateJour(b.dateDebut);
      while (!j.isAfter(dateJour(b.dateFin))) {
        pleines.add(j);
        j = DateTime(j.year, j.month, j.day + 1);
      }
    }
    return pleines;
  }

  Future<List<BlocageHebergement>> blocagesDe(int hebergementId) async {
    final db = await _db.database;
    final rows = await db.query('blocage_hebergement',
        where: 'hebergement_id = ? AND date_fin >= ?',
        whereArgs: [hebergementId, dateIso(DateTime.now())],
        orderBy: 'date_debut');
    return rows.map(BlocageHebergement.fromMap).toList();
  }

  /// Ferme l'établissement sur une période ; refusé si des séjours l'occupent déjà.
  Future<String?> ajouterBlocage(BlocageHebergement b) async {
    final erreur = b.verifier();
    if (erreur != null) return erreur;
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final conflit = await txn.rawQuery('''
        SELECT 1 FROM reservation_hebergement
        WHERE hebergement_id = ? AND statut NOT IN ('annulee', 'check_out')
          AND date_arrivee <= ? AND date_depart > ?
        LIMIT 1
      ''', [b.hebergementId, dateIso(b.dateFin), dateIso(b.dateDebut)]);
      if (conflit.isNotEmpty) {
        return 'Des séjours sont réservés sur cette période : annulez-les d\'abord';
      }
      await txn.insert('blocage_hebergement', b.toMap());
      return null;
    });
  }

  Future<void> supprimerBlocage(int id) async {
    final db = await _db.database;
    await db.delete('blocage_hebergement', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Séjours
  // ------------------------------------------------------------------

  static const String _selectSejour = '''
    SELECT r.*, h.nom AS nom_hebergement, h.type AS type_hebergement,
      h.photos AS photos_hebergement, vo.titre AS titre_voyage
    FROM reservation_hebergement r
    JOIN hebergement h ON h.id = r.hebergement_id
    JOIN voyage vo ON vo.id = r.voyage_id
  ''';

  /// Séjours rattachés aux voyages de l'utilisateur (annulés à la fin).
  Future<List<ReservationHebergement>> sejoursDe(int utilisateurId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
        '$_selectSejour WHERE vo.utilisateur_id = ? '
        "ORDER BY r.statut = 'annulee', r.date_arrivee, r.id",
        [utilisateurId]);
    return rows.map(ReservationHebergement.fromMap).toList();
  }

  /// Vue administrateur : tous les séjours avec le nom du client.
  /// [aTraiter] = arrivées possibles aujourd'hui et clients présents (check-in / check-out).
  Future<List<({ReservationHebergement sejour, String client})>> tousLesSejours(
      {bool aTraiter = false}) async {
    final db = await _db.database;
    final auj = dateIso(DateTime.now());
    final rows = await db.rawQuery('''
      SELECT r.*, h.nom AS nom_hebergement, h.type AS type_hebergement,
        h.photos AS photos_hebergement, vo.titre AS titre_voyage,
        u.prenom || ' ' || u.nom AS nom_client
      FROM reservation_hebergement r
      JOIN hebergement h ON h.id = r.hebergement_id
      JOIN voyage vo ON vo.id = r.voyage_id
      JOIN utilisateur u ON u.id = vo.utilisateur_id
      ${aTraiter ? "WHERE r.statut = 'check_in' OR (r.statut IN ('confirmee', 'en_cours') AND r.date_arrivee <= ? AND r.date_depart > ?)" : ''}
      ORDER BY r.date_arrivee DESC, r.id DESC
    ''', aTraiter ? [auj, auj] : const []);
    return [
      for (final r in rows)
        (sejour: ReservationHebergement.fromMap(r), client: r['nom_client'] as String),
    ];
  }

  /// Code d'arrivée à 6 chiffres (générateur cryptographique).
  static String genererCode([math.Random? alea]) {
    final g = alea ?? math.Random.secure();
    return List.generate(6, (_) => g.nextInt(10)).join();
  }

  /// Enregistre un séjour dans une transaction : établissement ouvert, capacité,
  /// chambres libres (fermetures comprises), prix = tarif dynamique x type de chambre
  /// x chambres, code d'arrivée généré à la création.
  /// Si [utilisateurId] est donné, le voyage (et le séjour modifié) doivent lui appartenir.
  /// Renvoie un message d'erreur, ou null si tout est correct.
  Future<String?> enregistrerSejour(ReservationHebergement s, {int? utilisateurId}) async {
    final dates = ReservationHebergement.verifierSejour(s.dateArrivee, s.dateDepart);
    if (dates != null) return dates;
    if (s.nbChambres < 1) return 'Au moins une chambre';
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      if (utilisateurId != null) {
        final voyage = await txn.query('voyage',
            columns: ['id'],
            where: 'id = ? AND utilisateur_id = ?',
            whereArgs: [s.voyageId, utilisateurId],
            limit: 1);
        if (voyage.isEmpty) return 'Ce voyage ne vous appartient pas';
        if (s.id != null) {
          final a = await txn.rawQuery('''
            SELECT 1 FROM reservation_hebergement r JOIN voyage vo ON vo.id = r.voyage_id
            WHERE r.id = ? AND vo.utilisateur_id = ? LIMIT 1
          ''', [s.id, utilisateurId]);
          if (a.isEmpty) return 'Séjour introuvable';
        }
      }
      if (s.id != null) {
        final existant = await txn.query('reservation_hebergement',
            columns: ['statut'], where: 'id = ?', whereArgs: [s.id], limit: 1);
        if (existant.isEmpty) return 'Séjour introuvable';
        final statut = StatutSejour.depuis(existant.first['statut'] as String?);
        if (statut != StatutSejour.confirmee && statut != StatutSejour.enAttente) {
          return 'Ce séjour ne se modifie plus (${statut.libelle.toLowerCase()})';
        }
      }

      final rows = await txn.query('hebergement',
          where: 'id = ?', whereArgs: [s.hebergementId], limit: 1);
      if (rows.isEmpty) return 'Hébergement introuvable';
      final h = Hebergement.fromMap(rows.first);
      if (!h.ouvert) {
        return 'Cet établissement ne prend pas de réservation (${h.statut.libelle.toLowerCase()})';
      }
      if (s.nbPersonnes > h.capacite * s.nbChambres) {
        return 'Trop de personnes : ${h.capacite} maximum par chambre '
            '(${h.capacite * s.nbChambres} pour ${s.nbChambres} chambre${s.nbChambres > 1 ? 's' : ''})';
      }
      final libres = await chambresLibres(s.hebergementId, s.dateArrivee, s.dateDepart,
          exclureId: s.id, executeur: txn);
      if (libres < s.nbChambres) {
        return libres <= 0
            ? 'Complet sur ces dates'
            : 'Il ne reste que $libres chambre${libres > 1 ? 's' : ''} sur ces dates';
      }

      final prix = ReservationHebergement.calculerPrix(
        regles: h.reglesTarif,
        prixParNuit: h.prixParNuit,
        typeChambre: s.typeChambre,
        nbChambres: s.nbChambres,
        arrivee: s.dateArrivee,
        depart: s.dateDepart,
      );
      final Map<String, Object?> valeurs = {...s.toMap(), 'prix_total': prix.total};
      if (s.id == null) {
        await txn.insert('reservation_hebergement', {...valeurs, 'code_checkin': genererCode()});
      } else {
        valeurs.remove('cree_le');
        valeurs.remove('statut');
        await txn.update('reservation_hebergement', valeurs,
            where: 'id = ?', whereArgs: [s.id]);
      }
      return null;
    });
  }

  /// Arrivée du client : le code doit correspondre, pendant le séjour, statut confirmé.
  Future<String?> validerCheckIn(int sejourId, String code) async {
    final db = await _db.database;
    return db.transaction<String?>((txn) async {
      final rows = await txn.query('reservation_hebergement',
          where: 'id = ?', whereArgs: [sejourId], limit: 1);
      if (rows.isEmpty) return 'Séjour introuvable';
      final s = ReservationHebergement.fromMap(rows.first);
      if (s.statut == StatutSejour.checkIn) return 'Le client est déjà arrivé';
      if (!s.peutCheckIn) {
        return 'Check-in possible seulement du ${dateCourte(s.dateArrivee)} '
            'à la veille du départ, pour un séjour confirmé';
      }
      if (s.codeCheckin == null || s.codeCheckin != code.trim()) {
        return 'Code d\'arrivée incorrect';
      }
      await txn.update('reservation_hebergement', {'statut': StatutSejour.checkIn.valeur},
          where: 'id = ?', whereArgs: [sejourId]);
      return null;
    });
  }

  /// Départ du client : la chambre est libérée immédiatement (même avant la date prévue).
  Future<String?> checkOut(int sejourId) async {
    final db = await _db.database;
    final n = await db.rawUpdate('''
      UPDATE reservation_hebergement SET statut = 'check_out'
      WHERE id = ? AND statut = 'check_in'
    ''', [sejourId]);
    return n > 0 ? null : 'Check-out possible uniquement après le check-in';
  }

  /// Annulation par le propriétaire : la ligne reste (historique), la chambre est libérée.
  Future<bool> annulerSejour(int id, int utilisateurId) async {
    final db = await _db.database;
    final n = await db.rawUpdate('''
      UPDATE reservation_hebergement SET statut = 'annulee'
      WHERE id = ? AND statut IN ('confirmee', 'en_attente')
        AND voyage_id IN (SELECT id FROM voyage WHERE utilisateur_id = ?)
    ''', [id, utilisateurId]);
    return n > 0;
  }

  Future<void> supprimerSejour(int id) async {
    final db = await _db.database;
    await db.delete('reservation_hebergement', where: 'id = ?', whereArgs: [id]);
  }
}
