/// MODULE VOYAGE — Mouhamed Dhia Dridi
/// Objet central : chaque réservation appartient à un voyage.
/// Règles : date_fin >= date_debut ; statut = planifie | actif | termine | annule.
///
/// Offre de vol : le voyage naît du choix d'une offre (destination + dates)
/// et d'une classe ; le prix est calculé, jamais saisi.
const List<String> voyageTables = [
  '''
  CREATE TABLE IF NOT EXISTS voyage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    titre TEXT NOT NULL,
    destination TEXT NOT NULL,
    date_debut TEXT NOT NULL,
    date_fin TEXT NOT NULL,
    budget REAL NOT NULL DEFAULT 0,
    statut TEXT NOT NULL DEFAULT 'planifie'
      CHECK (statut IN ('planifie','actif','termine','annule')),
    utilisateur_id INTEGER NOT NULL,
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
  // Catalogue des vols proposés (rempli une fois par VoyageVolRepository).
  '''
  CREATE TABLE IF NOT EXISTS offre_vol (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ville TEXT NOT NULL,
    pays TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    duree_minutes INTEGER NOT NULL,
    date_depart TEXT NOT NULL,
    date_retour TEXT NOT NULL,
    prix_base REAL NOT NULL
  )
  ''',
  // Le vol choisi pour un voyage : offre + classe + prix final.
  '''
  CREATE TABLE IF NOT EXISTS voyage_vol (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    voyage_id INTEGER NOT NULL UNIQUE,
    offre_id INTEGER NOT NULL,
    classe TEXT NOT NULL
      CHECK (classe IN ('eco','affaires','premiere')),
    prix REAL NOT NULL,
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE,
    FOREIGN KEY (offre_id) REFERENCES offre_vol (id)
  )
  ''',
  // Itinéraire généré par l'IA + niveau de séjour choisi (un seul par voyage).
  '''
  CREATE TABLE IF NOT EXISTS voyage_itineraire (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    voyage_id INTEGER NOT NULL UNIQUE,
    confort TEXT NOT NULL,
    contenu TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE
  )
  ''',
];
