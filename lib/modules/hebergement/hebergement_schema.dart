/// MODULE HÉBERGEMENT — Oussema Mrayah
/// Règles : date_depart > date_arrivee ;
/// prix_total = tarif dynamique (prix par nuit, week-end, saison, remise) x chambres ;
/// nb_personnes <= capacite x chambres réservées ;
/// chambres réservées sur une période <= nb_chambres de l'établissement ;
/// note_moyenne / nb_avis recalculés depuis la table "avis" (module forum).
/// v4 : riad, règles, superficie, propriétaire, tarification dynamique, type de chambre,
///      check-in / check-out (code à 6 chiffres), dates bloquées.

/// Colonnes de la table hebergement (création et reconstruction v4).
const String _colonnesHebergement = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'hotel'
      CHECK (type IN ('hotel','auberge','appartement','maison_hotes','villa','riad','camping')),
    description TEXT,
    regles TEXT,
    adresse TEXT NOT NULL,
    ville TEXT,
    latitude REAL CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    longitude REAL CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    etoiles INTEGER CHECK (etoiles IS NULL OR etoiles BETWEEN 1 AND 5),
    prix_par_nuit REAL NOT NULL CHECK (prix_par_nuit >= 0),
    majoration_weekend REAL NOT NULL DEFAULT 0,
    majoration_saison REAL NOT NULL DEFAULT 0,
    remise_longue_duree REAL NOT NULL DEFAULT 0,
    capacite INTEGER NOT NULL DEFAULT 2 CHECK (capacite BETWEEN 1 AND 20),
    nb_chambres INTEGER NOT NULL DEFAULT 1 CHECK (nb_chambres BETWEEN 1 AND 500),
    superficie REAL CHECK (superficie IS NULL OR superficie > 0),
    equipements TEXT NOT NULL DEFAULT '[]',
    photos TEXT NOT NULL DEFAULT '[]',
    telephone TEXT,
    heure_arrivee TEXT NOT NULL DEFAULT '15:00',
    heure_depart TEXT NOT NULL DEFAULT '11:00',
    note_moyenne REAL NOT NULL DEFAULT 0,
    nb_avis INTEGER NOT NULL DEFAULT 0,
    statut TEXT NOT NULL DEFAULT 'actif'
      CHECK (statut IN ('actif','travaux','ferme')),
    proprietaire_id INTEGER REFERENCES utilisateur (id) ON DELETE SET NULL,
    cree_le TEXT
''';

/// Colonnes de la table reservation_hebergement (création et reconstruction v4).
const String _colonnesReservation = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hebergement_id INTEGER NOT NULL,
    voyage_id INTEGER,
    date_arrivee TEXT NOT NULL,
    date_depart TEXT NOT NULL,
    nb_personnes INTEGER NOT NULL DEFAULT 1 CHECK (nb_personnes BETWEEN 1 AND 50),
    nb_chambres INTEGER NOT NULL DEFAULT 1 CHECK (nb_chambres BETWEEN 1 AND 50),
    type_chambre TEXT NOT NULL DEFAULT 'double'
      CHECK (type_chambre IN ('single','double','suite','familiale')),
    prix_total REAL NOT NULL CHECK (prix_total >= 0),
    statut TEXT NOT NULL DEFAULT 'confirmee'
      CHECK (statut IN ('en_attente','confirmee','en_cours','check_in','check_out',
                        'terminee','annulee')),
    code_checkin TEXT,
    demandes TEXT,
    cree_le TEXT,
    CHECK (date_depart > date_arrivee),
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE,
    FOREIGN KEY (hebergement_id) REFERENCES hebergement (id) ON DELETE CASCADE
''';

const String _tableBlocageHebergement = '''
  CREATE TABLE IF NOT EXISTS blocage_hebergement (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hebergement_id INTEGER NOT NULL,
    date_debut TEXT NOT NULL,
    date_fin TEXT NOT NULL,
    motif TEXT,
    CHECK (date_fin >= date_debut),
    FOREIGN KEY (hebergement_id) REFERENCES hebergement (id) ON DELETE CASCADE
  )
''';

const List<String> hebergementTables = [
  'CREATE TABLE IF NOT EXISTS hebergement ($_colonnesHebergement)',
  'CREATE TABLE IF NOT EXISTS reservation_hebergement ($_colonnesReservation)',
  '''
  CREATE INDEX IF NOT EXISTS idx_reservation_hebergement_periode
    ON reservation_hebergement (hebergement_id, date_arrivee, date_depart)
  ''',
  _tableBlocageHebergement,
];

/// Migration version 1 -> 2 (bases déjà installées).
/// Les anciens types (« Hôtel », « Auberge »…) sont convertis en codes ;
/// les établissements existants reçoivent 10 chambres pour ne pas bloquer les réservations.
const List<String> hebergementMigrationV2 = [
  'ALTER TABLE hebergement ADD COLUMN description TEXT',
  'ALTER TABLE hebergement ADD COLUMN ville TEXT',
  'ALTER TABLE hebergement ADD COLUMN latitude REAL',
  'ALTER TABLE hebergement ADD COLUMN longitude REAL',
  'ALTER TABLE hebergement ADD COLUMN etoiles INTEGER '
      'CHECK (etoiles IS NULL OR etoiles BETWEEN 1 AND 5)',
  'ALTER TABLE hebergement ADD COLUMN capacite INTEGER NOT NULL DEFAULT 2',
  'ALTER TABLE hebergement ADD COLUMN nb_chambres INTEGER NOT NULL DEFAULT 10',
  "ALTER TABLE hebergement ADD COLUMN equipements TEXT NOT NULL DEFAULT '[]'",
  "ALTER TABLE hebergement ADD COLUMN photos TEXT NOT NULL DEFAULT '[]'",
  'ALTER TABLE hebergement ADD COLUMN telephone TEXT',
  "ALTER TABLE hebergement ADD COLUMN heure_arrivee TEXT NOT NULL DEFAULT '15:00'",
  "ALTER TABLE hebergement ADD COLUMN heure_depart TEXT NOT NULL DEFAULT '11:00'",
  'ALTER TABLE hebergement ADD COLUMN note_moyenne REAL NOT NULL DEFAULT 0',
  'ALTER TABLE hebergement ADD COLUMN nb_avis INTEGER NOT NULL DEFAULT 0',
  "ALTER TABLE hebergement ADD COLUMN statut TEXT NOT NULL DEFAULT 'actif' "
      "CHECK (statut IN ('actif','travaux','ferme'))",
  'ALTER TABLE hebergement ADD COLUMN cree_le TEXT',
  '''
  UPDATE hebergement SET type = CASE type
    WHEN 'Hôtel' THEN 'hotel'
    WHEN 'Auberge' THEN 'auberge'
    WHEN 'Appartement' THEN 'appartement'
    WHEN 'Maison d''hôtes' THEN 'maison_hotes'
    ELSE 'hotel' END
  WHERE type NOT IN ('hotel','auberge','appartement','maison_hotes','villa','camping')
  ''',
  'ALTER TABLE reservation_hebergement ADD COLUMN nb_chambres INTEGER NOT NULL DEFAULT 1',
  "ALTER TABLE reservation_hebergement ADD COLUMN statut TEXT NOT NULL DEFAULT 'confirmee' "
      "CHECK (statut IN ('en_attente','confirmee','en_cours','terminee','annulee'))",
  'ALTER TABLE reservation_hebergement ADD COLUMN demandes TEXT',
  'ALTER TABLE reservation_hebergement ADD COLUMN cree_le TEXT',
];

/// Migration version 3 -> 4. Les contraintes CHECK de "type" et "statut" doivent accepter
/// de nouvelles valeurs (riad, check_in, check_out) : SQLite ne sait pas modifier une
/// contrainte, les deux tables sont donc RECONSTRUITES (création, copie, suppression,
/// renommage). DatabaseHelper désactive les clés étrangères pendant cette migration
/// (sinon la suppression de l'ancienne table effacerait les séjours en cascade)
/// et les réactive à l'ouverture. Toutes les données sont recopiées.
const List<String> hebergementMigrationV4 = [
  'CREATE TABLE hebergement_v4 ($_colonnesHebergement)',
  '''
  INSERT INTO hebergement_v4 (id, nom, type, description, adresse, ville, latitude, longitude,
    etoiles, prix_par_nuit, capacite, nb_chambres, equipements, photos, telephone,
    heure_arrivee, heure_depart, note_moyenne, nb_avis, statut, cree_le)
  SELECT id, nom, type, description, adresse, ville, latitude, longitude,
    etoiles, prix_par_nuit, capacite, nb_chambres, equipements, photos, telephone,
    heure_arrivee, heure_depart, note_moyenne, nb_avis, statut, cree_le
  FROM hebergement
  ''',
  'CREATE TABLE reservation_hebergement_v4 ($_colonnesReservation)',
  '''
  INSERT INTO reservation_hebergement_v4 (id, hebergement_id, voyage_id, date_arrivee,
    date_depart, nb_personnes, nb_chambres, prix_total, statut, demandes, cree_le)
  SELECT id, hebergement_id, voyage_id, date_arrivee,
    date_depart, nb_personnes, nb_chambres, prix_total, statut, demandes, cree_le
  FROM reservation_hebergement
  ''',
  'DROP TABLE reservation_hebergement',
  'DROP TABLE hebergement',
  'ALTER TABLE hebergement_v4 RENAME TO hebergement',
  'ALTER TABLE reservation_hebergement_v4 RENAME TO reservation_hebergement',
  _tableBlocageHebergement,
];
