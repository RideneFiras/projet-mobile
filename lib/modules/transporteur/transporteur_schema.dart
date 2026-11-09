/// MODULE TRANSPORTEUR — Abir Gamoudi (modèle de la base, version 3).
///
/// Tables :
///  - transporteur           : profil d'un compte transporteur (un seul par compte)
///  - trajet_transport       : trajets proposés (départ, arrivée, horaires, places, statut)
///  - commande_transport     : demande d'un voyageur (trajet, passagers, budget, statut)
///  - mise_en_relation       : commande proposée automatiquement à un transporteur
///  - reservation_transport  : réservation confirmée après acceptation
///  - historique_reservation : événements d'une réservation (historique)
///
/// Règles : départ <> arrivée ; prix, places et budgets >= 0 ; les coordonnées ne
/// sont partagées qu'après acceptation (requêtes du dépôt).
const List<String> transporteurTables = [
  '''
  CREATE TABLE IF NOT EXISTS transporteur (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    utilisateur_id INTEGER NOT NULL UNIQUE,
    nom TEXT NOT NULL,
    telephone TEXT NOT NULL,
    email TEXT NOT NULL,
    photo TEXT NOT NULL DEFAULT '',
    ville TEXT NOT NULL,
    zone_couverture TEXT NOT NULL DEFAULT '',
    type_transport TEXT NOT NULL
      CHECK (type_transport IN ('individuel', 'collectif', 'navette')),
    capacite INTEGER NOT NULL DEFAULT 1 CHECK (capacite > 0),
    description TEXT NOT NULL DEFAULT '',
    tarifs TEXT NOT NULL DEFAULT '',
    disponible INTEGER NOT NULL DEFAULT 1 CHECK (disponible IN (0, 1)),
    actif INTEGER NOT NULL DEFAULT 1 CHECK (actif IN (0, 1)),
    note_moyenne REAL NOT NULL DEFAULT 0 CHECK (note_moyenne BETWEEN 0 AND 5),
    cree_le TEXT NOT NULL,
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS trajet_transport (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transporteur_id INTEGER NOT NULL,
    ville_depart TEXT NOT NULL,
    destination TEXT NOT NULL,
    adresse_depart TEXT NOT NULL DEFAULT '',
    adresse_arrivee TEXT NOT NULL DEFAULT '',
    date_depart TEXT NOT NULL,
    date_arrivee_estimee TEXT NOT NULL,
    prix_par_personne REAL NOT NULL DEFAULT 0 CHECK (prix_par_personne >= 0),
    places_totales INTEGER NOT NULL CHECK (places_totales >= 0),
    type_transport TEXT NOT NULL
      CHECK (type_transport IN ('individuel', 'collectif', 'navette')),
    arrets TEXT NOT NULL DEFAULT '',
    statut TEXT NOT NULL DEFAULT 'planifie'
      CHECK (statut IN ('planifie', 'en_cours', 'termine', 'annule')),
    cree_le TEXT NOT NULL,
    CHECK (ville_depart <> destination),
    FOREIGN KEY (transporteur_id) REFERENCES transporteur (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS commande_transport (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reference TEXT NOT NULL UNIQUE,
    voyageur_id INTEGER NOT NULL,
    depart TEXT NOT NULL,
    arrivee TEXT NOT NULL,
    date_voyage TEXT NOT NULL,
    nombre_passagers INTEGER NOT NULL DEFAULT 1 CHECK (nombre_passagers > 0),
    prix_propose REAL NOT NULL DEFAULT 0 CHECK (prix_propose >= 0),
    commentaire TEXT NOT NULL DEFAULT '',
    statut TEXT NOT NULL DEFAULT 'EN_ATTENTE'
      CHECK (statut IN ('EN_ATTENTE', 'ACCEPTEE', 'REFUSEE', 'ANNULEE', 'termine')),
    cree_le TEXT NOT NULL,
    CHECK (depart <> arrivee),
    FOREIGN KEY (voyageur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS mise_en_relation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commande_id INTEGER NOT NULL,
    trajet_id INTEGER NOT NULL,
    transporteur_id INTEGER NOT NULL,
    statut TEXT NOT NULL DEFAULT 'proposee'
      CHECK (statut IN ('proposee', 'acceptee', 'refusee')),
    cree_le TEXT NOT NULL,
    repondu_le TEXT,
    UNIQUE (commande_id, trajet_id),
    FOREIGN KEY (commande_id) REFERENCES commande_transport (id) ON DELETE CASCADE,
    FOREIGN KEY (trajet_id) REFERENCES trajet_transport (id) ON DELETE CASCADE,
    FOREIGN KEY (transporteur_id) REFERENCES transporteur (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reservation_transport (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trajet_id INTEGER NOT NULL,
    voyageur_id INTEGER NOT NULL,
    commande_id INTEGER,
    nombre_places INTEGER NOT NULL CHECK (nombre_places > 0),
    statut TEXT NOT NULL DEFAULT 'confirmee'
      CHECK (statut IN ('confirmee', 'prise_en_charge', 'annulee')),
    motif_annulation TEXT NOT NULL DEFAULT '',
    cree_le TEXT NOT NULL,
    FOREIGN KEY (trajet_id) REFERENCES trajet_transport (id) ON DELETE CASCADE,
    FOREIGN KEY (voyageur_id) REFERENCES utilisateur (id) ON DELETE CASCADE,
    FOREIGN KEY (commande_id) REFERENCES commande_transport (id) ON DELETE SET NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS historique_reservation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reservation_id INTEGER NOT NULL,
    evenement TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    FOREIGN KEY (reservation_id) REFERENCES reservation_transport (id) ON DELETE CASCADE
  )
  ''',
];

/// Tables supprimées lors de la migration vers la version 3 (enfants d'abord).
/// La base les recrée ensuite avec [transporteurTables].
const List<String> transporteurTablesASupprimer = [
  'historique_reservation',
  'reservation_transport',
  'mise_en_relation',
  'commande_transport',
  'trajet_transport',
  'transporteur',
];
