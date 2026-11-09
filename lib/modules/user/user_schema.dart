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
    photo TEXT,
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
    photo TEXT,
    epingle INTEGER NOT NULL DEFAULT 0,
    type_post TEXT NOT NULL DEFAULT 'standard'
      CHECK (type_post IN ('standard','annonce')),
    date_evenement TEXT,
    lieu TEXT,
    date_publication TEXT NOT NULL,
    auteur_id INTEGER,
    audience TEXT NOT NULL DEFAULT 'tous'
      CHECK (audience IN ('tous','client','traveller','transporter')),
    categorie TEXT NOT NULL DEFAULT 'general'
      CHECK (categorie IN ('general','voyage','commande','transport','annonce')),
    FOREIGN KEY (auteur_id) REFERENCES utilisateur (id) ON DELETE SET NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS commentaire_actualite (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL REFERENCES actualite (id) ON DELETE CASCADE,
    parent_id INTEGER REFERENCES commentaire_actualite (id) ON DELETE CASCADE,
    auteur_id INTEGER REFERENCES utilisateur (id) ON DELETE SET NULL,
    auteur_nom TEXT NOT NULL,
    contenu TEXT NOT NULL,
    cree_le TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS sondage_option (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL REFERENCES actualite (id) ON DELETE CASCADE,
    libelle TEXT NOT NULL,
    ordre INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS sondage_vote (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL REFERENCES actualite (id) ON DELETE CASCADE,
    option_id INTEGER NOT NULL REFERENCES sondage_option (id) ON DELETE CASCADE,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    cree_le TEXT NOT NULL,
    UNIQUE (actualite_id, utilisateur_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reaction_actualite (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL REFERENCES actualite (id) ON DELETE CASCADE,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'like'
      CHECK (type IN ('like','love','wow','haha','sad','angry')),
    cree_le TEXT NOT NULL,
    UNIQUE (actualite_id, utilisateur_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS participation_actualite (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL REFERENCES actualite (id) ON DELETE CASCADE,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    cree_le TEXT NOT NULL,
    UNIQUE (actualite_id, utilisateur_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS notification_fil (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    destinataire_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    acteur_id INTEGER REFERENCES utilisateur (id) ON DELETE SET NULL,
    acteur_nom TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('commentaire','reaction','sondage','participation')),
    actualite_id INTEGER REFERENCES actualite (id) ON DELETE CASCADE,
    texte TEXT NOT NULL,
    lue INTEGER NOT NULL DEFAULT 0,
    cree_le TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS message_prive (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    expediteur_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    destinataire_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    contenu TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'texte'
      CHECK (type IN ('texte','image','vocal')),
    cree_le TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS historique_post (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL,
    titre TEXT NOT NULL,
    contenu TEXT NOT NULL,
    auteur_id INTEGER,
    action TEXT NOT NULL CHECK (action IN ('creation','modification','suppression')),
    cree_le TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reaction_commentaire (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commentaire_id INTEGER NOT NULL REFERENCES commentaire_actualite (id) ON DELETE CASCADE,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'like',
    cree_le TEXT NOT NULL,
    UNIQUE (commentaire_id, utilisateur_id)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS partage_post (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actualite_id INTEGER NOT NULL REFERENCES actualite (id) ON DELETE CASCADE,
    utilisateur_id INTEGER NOT NULL REFERENCES utilisateur (id) ON DELETE CASCADE,
    cree_le TEXT NOT NULL,
    UNIQUE (actualite_id, utilisateur_id)
  )
  ''',
];
