/// MODULE TRANSPORTEUR — Abir Gamoudi
/// Tables :
///  - transporteur            : fiche d'un transporteur (nom, type, contact)
///  - reservation_transport   : trajet proposé par un transporteur (prix, statut)
///  - commande_transport      : commande passée par un client (trajet souhaité, budget)
///  - mise_en_relation        : proposition d'un voyageur pour une commande,
///                              acceptée ou refusée par le voyageur
/// Règles : depart <> arrivee ; prix et budget >= 0 ;
/// les coordonnées ne sont échangées qu'après acceptation.
const List<String> transporteurTables = [
  '''
  CREATE TABLE IF NOT EXISTS transporteur (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL,
    type TEXT NOT NULL,
    contact TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reservation_transport (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    depart TEXT NOT NULL,
    arrivee TEXT NOT NULL,
    date_depart TEXT NOT NULL,
    prix REAL NOT NULL DEFAULT 0,
    statut TEXT NOT NULL DEFAULT 'en_attente',
    voyage_id INTEGER,
    transporteur_id INTEGER,
    CHECK (depart <> arrivee),
    FOREIGN KEY (voyage_id) REFERENCES voyage (id) ON DELETE CASCADE,
    FOREIGN KEY (transporteur_id) REFERENCES transporteur (id) ON DELETE SET NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS commande_transport (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    depart TEXT NOT NULL,
    arrivee TEXT NOT NULL,
    date_souhaitee TEXT NOT NULL,
    budget REAL NOT NULL DEFAULT 0 CHECK (budget >= 0),
    description TEXT NOT NULL DEFAULT '',
    statut TEXT NOT NULL DEFAULT 'ouverte'
      CHECK (statut IN ('ouverte','acceptee','annulee')),
    voyageur_id INTEGER,
    cree_le TEXT NOT NULL,
    CHECK (depart <> arrivee),
    FOREIGN KEY (client_id) REFERENCES utilisateur (id) ON DELETE CASCADE,
    FOREIGN KEY (voyageur_id) REFERENCES utilisateur (id) ON DELETE SET NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS mise_en_relation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commande_id INTEGER NOT NULL,
    auteur_id INTEGER NOT NULL,
    voyageur_id INTEGER NOT NULL,
    transporteur_id INTEGER,
    statut TEXT NOT NULL DEFAULT 'proposee'
      CHECK (statut IN ('proposee','acceptee','refusee')),
    cree_le TEXT NOT NULL,
    FOREIGN KEY (commande_id) REFERENCES commande_transport (id) ON DELETE CASCADE,
    FOREIGN KEY (auteur_id) REFERENCES utilisateur (id) ON DELETE CASCADE,
    FOREIGN KEY (voyageur_id) REFERENCES utilisateur (id) ON DELETE CASCADE,
    FOREIGN KEY (transporteur_id) REFERENCES transporteur (id) ON DELETE SET NULL
  )
  ''',
];
