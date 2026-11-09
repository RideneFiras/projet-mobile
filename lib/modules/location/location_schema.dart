/// MODULE LOCATION DE VÉHICULES — Roua Dhafer
/// Types : voiture, moto, bicyclette.
/// Règles : prix_total = prix_par_jour x nombre de jours (bornes comprises) ;
/// pas de chevauchement entre deux locations non annulées du même véhicule ;
/// immatriculation unique (absente pour une bicyclette).
/// v3 : options payantes (JSON), clôture (date de retour réelle, kilométrage, pénalité).
/// v4 : propriétaire, entretien (révision), tarification dynamique, dates bloquées,
///      numéro de permis et signature du contrat.
const List<String> locationTables = [
  '''
  CREATE TABLE IF NOT EXISTS vehicule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL DEFAULT 'voiture'
      CHECK (type IN ('voiture','moto','bicyclette')),
    marque TEXT NOT NULL,
    modele TEXT NOT NULL,
    annee INTEGER CHECK (annee IS NULL OR annee BETWEEN 1950 AND 2100),
    couleur TEXT,
    immatriculation TEXT,
    carburant TEXT NOT NULL DEFAULT 'essence'
      CHECK (carburant IN ('essence','diesel','electrique','hybride','aucun')),
    boite TEXT CHECK (boite IS NULL OR boite IN ('manuelle','automatique')),
    places INTEGER NOT NULL DEFAULT 1 CHECK (places BETWEEN 1 AND 9),
    kilometrage INTEGER CHECK (kilometrage IS NULL OR kilometrage >= 0),
    km_derniere_revision INTEGER,
    intervalle_revision INTEGER NOT NULL DEFAULT 10000,
    prix_par_jour REAL NOT NULL CHECK (prix_par_jour >= 0),
    majoration_weekend REAL NOT NULL DEFAULT 0,
    majoration_saison REAL NOT NULL DEFAULT 0,
    remise_longue_duree REAL NOT NULL DEFAULT 0,
    proprietaire_id INTEGER REFERENCES utilisateur (id) ON DELETE SET NULL,
    caution REAL NOT NULL DEFAULT 0 CHECK (caution >= 0),
    photos TEXT NOT NULL DEFAULT '[]',
    latitude REAL CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    longitude REAL CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    adresse TEXT,
    description TEXT,
    statut TEXT NOT NULL DEFAULT 'disponible'
      CHECK (statut IN ('disponible','maintenance','hors_service')),
    cree_le TEXT
  )
  ''',
  '''
  CREATE UNIQUE INDEX IF NOT EXISTS idx_vehicule_immatriculation
    ON vehicule (immatriculation) WHERE immatriculation IS NOT NULL
  ''',
  '''
  CREATE TABLE IF NOT EXISTS location_vehicule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicule_id INTEGER NOT NULL,
    voyage_id INTEGER,
    date_debut TEXT NOT NULL,
    date_fin TEXT NOT NULL,
    prix_total REAL NOT NULL CHECK (prix_total >= 0),
    caution REAL NOT NULL DEFAULT 0 CHECK (caution >= 0),
    statut TEXT NOT NULL DEFAULT 'confirmee'
      CHECK (statut IN ('en_attente','confirmee','en_cours','terminee','annulee')),
    lieu_prise TEXT,
    lieu_retour TEXT,
    notes TEXT,
    options TEXT NOT NULL DEFAULT '[]',
    date_retour_reelle TEXT,
    km_depart INTEGER CHECK (km_depart IS NULL OR km_depart >= 0),
    km_retour INTEGER CHECK (km_retour IS NULL OR km_retour >= 0),
    penalite REAL NOT NULL DEFAULT 0 CHECK (penalite >= 0),
    numero_permis TEXT,
    contrat_signe_le TEXT,
    signature TEXT,
    cree_le TEXT,
    CHECK (date_fin >= date_debut),
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE,
    FOREIGN KEY (vehicule_id) REFERENCES vehicule (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_location_vehicule_periode
    ON location_vehicule (vehicule_id, date_debut, date_fin)
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_location_vehicule_statut
    ON location_vehicule (statut, date_debut)
  ''',
  _tableBlocageVehicule,
];

/// Dates bloquées par l'administrateur (entretien, réservation hors application…).
const String _tableBlocageVehicule = '''
  CREATE TABLE IF NOT EXISTS blocage_vehicule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicule_id INTEGER NOT NULL,
    date_debut TEXT NOT NULL,
    date_fin TEXT NOT NULL,
    motif TEXT,
    CHECK (date_fin >= date_debut),
    FOREIGN KEY (vehicule_id) REFERENCES vehicule (id) ON DELETE CASCADE
  )
''';

/// Migration version 1 -> 2 (bases déjà installées).
/// SQLite n'autorise que ADD COLUMN : l'ancienne colonne "disponible" reste en base
/// mais n'est plus lue ; son contenu est recopié dans "statut".
const List<String> locationMigrationV2 = [
  "ALTER TABLE vehicule ADD COLUMN type TEXT NOT NULL DEFAULT 'voiture' "
      "CHECK (type IN ('voiture','moto','bicyclette'))",
  'ALTER TABLE vehicule ADD COLUMN annee INTEGER',
  'ALTER TABLE vehicule ADD COLUMN couleur TEXT',
  'ALTER TABLE vehicule ADD COLUMN immatriculation TEXT',
  "ALTER TABLE vehicule ADD COLUMN carburant TEXT NOT NULL DEFAULT 'essence' "
      "CHECK (carburant IN ('essence','diesel','electrique','hybride','aucun'))",
  "ALTER TABLE vehicule ADD COLUMN boite TEXT DEFAULT 'manuelle'",
  'ALTER TABLE vehicule ADD COLUMN places INTEGER NOT NULL DEFAULT 5',
  'ALTER TABLE vehicule ADD COLUMN caution REAL NOT NULL DEFAULT 0',
  "ALTER TABLE vehicule ADD COLUMN photos TEXT NOT NULL DEFAULT '[]'",
  'ALTER TABLE vehicule ADD COLUMN latitude REAL',
  'ALTER TABLE vehicule ADD COLUMN longitude REAL',
  'ALTER TABLE vehicule ADD COLUMN adresse TEXT',
  'ALTER TABLE vehicule ADD COLUMN description TEXT',
  "ALTER TABLE vehicule ADD COLUMN statut TEXT NOT NULL DEFAULT 'disponible' "
      "CHECK (statut IN ('disponible','maintenance','hors_service'))",
  'ALTER TABLE vehicule ADD COLUMN cree_le TEXT',
  "UPDATE vehicule SET statut = CASE WHEN disponible = 1 THEN 'disponible' "
      "ELSE 'hors_service' END",
  'ALTER TABLE location_vehicule ADD COLUMN caution REAL NOT NULL DEFAULT 0',
  "ALTER TABLE location_vehicule ADD COLUMN statut TEXT NOT NULL DEFAULT 'confirmee' "
      "CHECK (statut IN ('en_attente','confirmee','en_cours','terminee','annulee'))",
  'ALTER TABLE location_vehicule ADD COLUMN lieu_prise TEXT',
  'ALTER TABLE location_vehicule ADD COLUMN lieu_retour TEXT',
  'ALTER TABLE location_vehicule ADD COLUMN notes TEXT',
  'ALTER TABLE location_vehicule ADD COLUMN cree_le TEXT',
];

/// Migration version 2 -> 3 : kilométrage du véhicule, options payantes,
/// clôture de la location (retour réel, kilométrage, pénalité de retard).
/// Uniquement des ADD COLUMN avec valeur par défaut : aucune donnée existante n'est modifiée.
const List<String> locationMigrationV3 = [
  'ALTER TABLE vehicule ADD COLUMN kilometrage INTEGER '
      'CHECK (kilometrage IS NULL OR kilometrage >= 0)',
  "ALTER TABLE location_vehicule ADD COLUMN options TEXT NOT NULL DEFAULT '[]'",
  'ALTER TABLE location_vehicule ADD COLUMN date_retour_reelle TEXT',
  'ALTER TABLE location_vehicule ADD COLUMN km_depart INTEGER '
      'CHECK (km_depart IS NULL OR km_depart >= 0)',
  'ALTER TABLE location_vehicule ADD COLUMN km_retour INTEGER '
      'CHECK (km_retour IS NULL OR km_retour >= 0)',
  'ALTER TABLE location_vehicule ADD COLUMN penalite REAL NOT NULL DEFAULT 0 '
      'CHECK (penalite >= 0)',
  '''
  CREATE INDEX IF NOT EXISTS idx_location_vehicule_statut
    ON location_vehicule (statut, date_debut)
  ''',
];

/// Migration version 3 -> 4 : ADD COLUMN avec valeurs par défaut (tarifs inchangés : 0 %)
/// et nouvelle table blocage_vehicule. La révision part du kilométrage actuel.
const List<String> locationMigrationV4 = [
  'ALTER TABLE vehicule ADD COLUMN km_derniere_revision INTEGER',
  'ALTER TABLE vehicule ADD COLUMN intervalle_revision INTEGER NOT NULL DEFAULT 10000',
  'ALTER TABLE vehicule ADD COLUMN majoration_weekend REAL NOT NULL DEFAULT 0',
  'ALTER TABLE vehicule ADD COLUMN majoration_saison REAL NOT NULL DEFAULT 0',
  'ALTER TABLE vehicule ADD COLUMN remise_longue_duree REAL NOT NULL DEFAULT 0',
  'ALTER TABLE vehicule ADD COLUMN proprietaire_id INTEGER '
      'REFERENCES utilisateur (id) ON DELETE SET NULL',
  'UPDATE vehicule SET km_derniere_revision = kilometrage WHERE kilometrage IS NOT NULL',
  'ALTER TABLE location_vehicule ADD COLUMN numero_permis TEXT',
  'ALTER TABLE location_vehicule ADD COLUMN contrat_signe_le TEXT',
  'ALTER TABLE location_vehicule ADD COLUMN signature TEXT',
  _tableBlocageVehicule,
];
