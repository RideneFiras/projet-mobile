/// MODULE FORUM — Sirine Hamzaoui
/// Règle : un avis porte sur UN service (location, hebergement ou transport).
const List<String> forumTables = [
  '''
  CREATE TABLE IF NOT EXISTS forum_sujet (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    titre TEXT NOT NULL,
    contenu TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    auteur_id INTEGER NOT NULL,
    FOREIGN KEY (auteur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS forum_reponse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contenu TEXT NOT NULL,
    cree_le TEXT NOT NULL,
    sujet_id INTEGER NOT NULL,
    auteur_id INTEGER NOT NULL,
    FOREIGN KEY (sujet_id) REFERENCES forum_sujet (id) ON DELETE CASCADE,
    FOREIGN KEY (auteur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS avis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cible_type TEXT NOT NULL CHECK (cible_type IN ('location','hebergement','transport')),
    cible_id INTEGER NOT NULL,
    note INTEGER NOT NULL CHECK (note BETWEEN 1 AND 5),
    commentaire TEXT,
    cree_le TEXT NOT NULL,
    auteur_id INTEGER NOT NULL,
    FOREIGN KEY (auteur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
];
