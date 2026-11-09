/// MODULE LOCATION DE VOITURE — Roua Dhafer
/// Règles : prix_total = prix_par_jour x nombre de jours ;
/// pas de réservation sur des dates qui se chevauchent.
const List<String> locationTables = [
  '''
  CREATE TABLE IF NOT EXISTS vehicule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    marque TEXT NOT NULL,
    modele TEXT NOT NULL,
    prix_par_jour REAL NOT NULL,
    disponible INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS location_vehicule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date_debut TEXT NOT NULL,
    date_fin TEXT NOT NULL,
    prix_total REAL NOT NULL,
    voyage_id INTEGER,
    vehicule_id INTEGER NOT NULL,
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE,
    FOREIGN KEY (vehicule_id) REFERENCES vehicule (id) ON DELETE CASCADE
  )
  ''',
];
