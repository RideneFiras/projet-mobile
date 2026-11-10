/// MODULE USER — Abdeslem Kessentini
/// Tables : utilisateur, actualite.
const List<String> userTables = [
  '''
  CREATE TABLE IF NOT EXISTS utilisateur (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nom TEXT NOT NULL,
    prenom TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    telephone TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('client','traveller','transporter','admin')),
    mot_de_passe_hash TEXT NOT NULL,
    sel TEXT NOT NULL,
    cree_le TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS actualite (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    titre TEXT NOT NULL,
    contenu TEXT NOT NULL,
    date_publication TEXT NOT NULL,
    auteur_id INTEGER,
    FOREIGN KEY (auteur_id) REFERENCES utilisateur (id) ON DELETE SET NULL
  )
  ''',
  // Vérification faciale (2FA) : descripteur de 128 nombres en JSON.
  // Une ligne = la vérification faciale est activée pour ce compte.
  '''
  CREATE TABLE IF NOT EXISTS visage_utilisateur (
    utilisateur_id INTEGER PRIMARY KEY,
    descripteur TEXT NOT NULL,
    active_le TEXT NOT NULL,
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateur (id) ON DELETE CASCADE
  )
  ''',
];
