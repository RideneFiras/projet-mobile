import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../modules/forum/forum_schema.dart';
import '../../modules/hebergement/hebergement_schema.dart';
import '../../modules/location/location_schema.dart';
import '../../modules/transporteur/transporteur_schema.dart';
import '../../modules/user/user_schema.dart';
import '../../modules/voyage/voyage_schema.dart';
import '../utils/password_hasher.dart';

/// Base SQLite unique de l'application (pattern Singleton).
///
/// Chaque module déclare ses tables dans `modules/<module>/<module>_schema.dart`.
/// Toutes les tables sont créées au démarrage si elles n'existent pas
/// ("CREATE TABLE IF NOT EXISTS") : aucun membre n'a besoin de modifier ce fichier.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String nomBase = 'travel_platform.db';

  /// v2 : véhicules (voiture/moto/bicyclette) et hébergements enrichis.
  /// v3 : location — options payantes, clôture (retour, kilométrage, pénalité).
  /// v4 : location (entretien, tarifs, blocages, contrat) ; hébergement reconstruit
  ///      (riad, règles, superficie, tarifs, type de chambre, check-in, blocages).
  /// v5 : intégration des branches. Le module transporteur passe à la version
  ///      « trajets / réservations / historique » (tables recréées) et le fil
  ///      d'actualité reçoit ses nouvelles colonnes et tables.
  ///
  /// Historique : la branche transporteur numérotait sa propre « version 3 »
  /// (recréation des tables transport) alors que la branche location/hébergement
  /// utilisait les numéros 2 à 4 pour d'autres tables. Un même numéro pouvait donc
  /// désigner deux états différents : les migrations ci-dessous se fondent sur la
  /// STRUCTURE réelle des tables (colonnes présentes) et non sur le numéro seul.
  static const int _version = 5;
  static Database? _database;

  /// "utilisateur" en premier (clés étrangères).
  static List<String> get _toutesLesTables => [
        ...userTables,
        ...voyageTables,
        ...transporteurTables,
        ...locationTables,
        ...hebergementTables,
        ...forumTables,
      ];

  Future<Database> get database async {
    _database ??= await _ouvrir();
    return _database!;
  }

  /// Chemin de la base. Sur le web, sqflite ne fournit pas de dossier
  /// (getDatabasesPath lève une exception) : la base est identifiée par son nom.
  static Future<String> _cheminBase() async {
    if (kIsWeb) return nomBase;
    return join(await getDatabasesPath(), nomBase);
  }

  Future<Database> _ouvrir() async {
    final chemin = await _cheminBase();
    return openDatabase(
      chemin,
      version: _version,
      // Clés étrangères activées, SAUF pendant une migration : la v4 reconstruit des tables
      // et la suppression d'une ancienne table déclencherait des suppressions en cascade.
      // Elles sont réactivées dans onOpen, une fois la migration terminée.
      onConfigure: (db) async {
        final versionActuelle = await db.getVersion();
        if (versionActuelle == 0 || versionActuelle >= _version) {
          await db.execute('PRAGMA foreign_keys = ON');
        }
      },
      onCreate: (db, version) async {
        await _creerTables(db);
        await _donneesDeDepart(db);
      },
      onUpgrade: (db, ancienne, nouvelle) async {
        await _migrerLocation(db);
        await _migrerHebergement(db);
        await _migrerTransporteur(db);
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await _creerTables(db);
      },
    );
  }

  Future<void> _creerTables(Database db) async {
    for (final sql in _toutesLesTables) {
      await db.execute(sql);
    }
  }

  // ------------------------------------------------------------------
  // Migrations (appelées uniquement quand la base existe déjà)
  // ------------------------------------------------------------------

  Future<bool> _tableExiste(Database db, String table) async {
    final lignes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return lignes.isNotEmpty;
  }

  Future<bool> _aColonne(Database db, String table, String colonne) async {
    final infos = await db.rawQuery('PRAGMA table_info($table)');
    return infos.any((ligne) => ligne['name'] == colonne);
  }

  Future<void> _executer(Database db, List<String> instructions) async {
    for (final sql in instructions) {
      await db.execute(sql);
    }
  }

  /// Location : applique uniquement les étapes (v2, v3, v4) pas encore présentes.
  /// Si la table n'existe pas encore, [_creerTables] la créera directement
  /// dans sa forme actuelle.
  Future<void> _migrerLocation(Database db) async {
    if (!await _tableExiste(db, 'vehicule') ||
        !await _tableExiste(db, 'location_vehicule')) {
      return;
    }
    if (!await _aColonne(db, 'vehicule', 'immatriculation')) {
      await _executer(db, locationMigrationV2);
    }
    if (!await _aColonne(db, 'vehicule', 'kilometrage')) {
      await _executer(db, locationMigrationV3);
    }
    if (!await _aColonne(db, 'vehicule', 'km_derniere_revision')) {
      await _executer(db, locationMigrationV4);
    }
  }

  /// Hébergement : v2 (colonnes enrichies) puis v4 (tables reconstruites),
  /// chacune seulement si elle n'est pas déjà appliquée.
  Future<void> _migrerHebergement(Database db) async {
    if (!await _tableExiste(db, 'hebergement') ||
        !await _tableExiste(db, 'reservation_hebergement')) {
      return;
    }
    if (!await _aColonne(db, 'hebergement', 'description')) {
      await _executer(db, hebergementMigrationV2);
    }
    if (!await _aColonne(db, 'reservation_hebergement', 'type_chambre')) {
      await _executer(db, hebergementMigrationV4);
    }
  }

  /// Transporteur : l'ancienne forme (transporteur / reservation_transport /
  /// commande_transport / mise_en_relation) est remplacée par la forme « trajets ».
  /// Les deux formes portent les mêmes noms de tables avec des colonnes différentes :
  /// on les supprime, puis [_creerTables] recrée la nouvelle forme à l'ouverture.
  /// Une base déjà à la nouvelle forme (présence de trajet_transport) n'est pas touchée.
  Future<void> _migrerTransporteur(Database db) async {
    if (await _tableExiste(db, 'trajet_transport')) return;
    for (final table in transporteurTablesASupprimer) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    // Les avis « transport » visaient l'ancienne table reservation_transport :
    // leurs cibles n'existent plus (les identifiants pointeraient vers d'autres lignes).
    if (await _tableExiste(db, 'avis')) {
      await db.delete('avis', where: 'cible_type = ?', whereArgs: ['transport']);
    }
  }

  /// Données insérées une seule fois, à la création de la base.
  Future<void> _donneesDeDepart(Database db) async {
    final maintenant = DateTime.now().toUtc().toIso8601String();
    int? adminId;

    // Compte administrateur de TEST, créé seulement en mode debug
    // (jamais dans l'APK de production).
    if (kDebugMode) {
      final sel = PasswordHasher.genererSel();
      adminId = await db.insert('utilisateur', {
        'nom': 'Admin',
        'prenom': 'Admin',
        'email': 'admin@travel.tn',
        'telephone': '+21600000000',
        'role': 'admin',
        'mot_de_passe_hash': PasswordHasher.hacher('Admin1234', sel),
        'sel': sel,
        'cree_le': maintenant,
      });
    }

    await db.insert('actualite', {
      'titre': 'Bienvenue sur Travel Platform',
      'contenu': 'Planifiez vos voyages et vos commandes au même endroit : '
          'transport, location de voiture et hébergement.',
      'date_publication': maintenant,
      'auteur_id': adminId,
    });
    await db.insert('actualite', {
      'titre': 'Comment passer sa première commande',
      'contenu': "Indiquez la ville d'achat, la ville de livraison et votre "
          'budget : un voyageur sur le même trajet pourra la prendre en charge.',
      'date_publication': maintenant,
      'auteur_id': adminId,
    });
  }

  /// Développement / tests : supprime la base pour la recréer.
  Future<void> reinitialiser() async {
    final chemin = await _cheminBase();
    await _database?.close();
    _database = null;
    await deleteDatabase(chemin);
  }
}
