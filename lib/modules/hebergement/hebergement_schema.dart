/// MODULE HÉBERGEMENT — Oussema Mrayah
/// Règles : date_depart > date_arrivee ; prix_total = prix_par_nuit x nuits.
const List<String> hebergementTables = [
  '''
  CREATE TABLE IF NOT EXISTS hebergement (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL,
    type TEXT NOT NULL,
    adresse TEXT NOT NULL,
    prix_par_nuit REAL NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reservation_hebergement (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date_arrivee TEXT NOT NULL,
    date_depart TEXT NOT NULL,
    nb_personnes INTEGER NOT NULL DEFAULT 1,
    prix_total REAL NOT NULL,
    voyage_id INTEGER,
    hebergement_id INTEGER NOT NULL,
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE,
    FOREIGN KEY (hebergement_id) REFERENCES hebergement (id) ON DELETE CASCADE
  )
  ''',
];
