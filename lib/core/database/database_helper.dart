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
  static const int _version = 4;
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
        if (ancienne < 2) {
          for (final sql in [...locationMigrationV2, ...hebergementMigrationV2]) {
            await db.execute(sql);
          }
        }
        if (ancienne < 3) {
          for (final sql in locationMigrationV3) {
            await db.execute(sql);
          }
        }
        if (ancienne < 4) {
          for (final sql in [...locationMigrationV4, ...hebergementMigrationV4]) {
            await db.execute(sql);
          }
        }
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
