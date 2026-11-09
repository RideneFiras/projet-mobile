# CLAUDE.md — Travel Platform (Flutter + SQLite)

Instructions pour Claude Code. À lire en entier avant toute modification.
Projet 5SAE3 ESPRIT : application mobile de voyage (transport, location de véhicules,
hébergement, forum, actualités). Je continue le travail sur les modules **location** et
**hébergement** dans VS Code, puis je reviens sur Android Studio : ne laisse rien qui
dépende de VS Code (pas de chemin absolu, pas de configuration propre à l'IDE dans le code).

---

## 1. Stack et commandes

- Flutter, Dart `^3.5.0`, Material 3. Base locale SQLite (`sqflite`) : fichier `travel_platform.db`.
- **Version actuelle du schéma : 5** (`lib/core/database/database_helper.dart`).
  Les clés étrangères sont désactivées pendant `onUpgrade` (reconstruction de tables en v4)
  et réactivées dans `onOpen`. Les migrations (`_migrerLocation`, `_migrerHebergement`,
  `_migrerTransporteur`) testent la STRUCTURE des tables, pas seulement le numéro :
  voir `docs/integration.md`.
- Packages présents : `sqflite`, `sqflite_common_ffi` (tests), `http`, `flutter_map` 7.0.2,
  `latlong2`, `shared_preferences`, `path`, `path_provider` (contrat PDF), `flutter_lints` 5.
- Commandes à lancer après CHAQUE fonctionnalité, dans cet ordre :
  ```
  flutter pub get
  flutter analyze        # doit afficher « No issues found »
  flutter test           # tous les tests doivent passer
  ```
- Lancement :
  ```
  flutter run --dart-define=GEMINI_API_KEY=... \
              --dart-define=HF_API_KEY=... \
              --dart-define=EMAILJS_SERVICE_ID=... \
              --dart-define=EMAILJS_TEMPLATE_LOCATION=... \
              --dart-define=EMAILJS_PUBLIC_KEY=...
  ```
  Facultatifs : `GEMINI_MODELE`, `HF_API_URL`, `HF_MODELE_DOMMAGES`, `HF_MODELE_FAUSSES_PHOTOS`.
  ```
  ```
- Compte admin (debug uniquement) : `admin@travel.tn` / `Admin1234`.

## 2. Architecture

```
lib/
  core/        database_helper.dart, services/session_service.dart, utils/ (dates, montants,
               validators, json_listes), widgets/ (ui_kit, galerie_photos, carte_emplacement),
               routes/, theme/ (AppColors : teal #0F7B83, orange #F68B3F)
  modules/
    user/          comptes, rôles, admin, fil d'actualité, messenger (Abdeslem Kessentini)
    voyage/        voyages, vols, itinéraire IA Gemini  (Mouhamed Dhia Dridi)
    transporteur/  transport (trajets, itinéraire) + serveur Node  (Abir Gamoudi)
    location/      location de véhicules                (Roua Dhafer)
    hebergement/   hébergement                          (Oussema Mrayah)
    forum/         forum + table avis                   (Sirine Hamzaoui)
test/            sqflite_common_ffi, une base neuve par test (DatabaseHelper.reinitialiser())
```
Flux : écran (`screens/`) → repository (`*_repository.dart`) → `DatabaseHelper` (SQLite).
Les écrans n'écrivent jamais de SQL. Les services réseau sont des classes à part
(`geocodage_service.dart`, `location_email_service.dart`, `voyage_ia_service.dart`).

## 3. Règles OBLIGATOIRES

1. **Style du projet** : tout en français (classes, méthodes, variables, messages, commentaires
   `///`). Modèles avec `fromMap` / `toMap` / `copyWith`. Enums avec `valeur` (stockée en base)
   + `libelle` (affiché) + `static depuis(String?)`. Règles métier dans `verifier()` (renvoie
   un message ou null) et revérifiées dans le repository. Widgets du `ui_kit` (EcranModule,
   CarteModule, ChampTexte, ChampChoix, BoutonPrincipal, Pastille, couleursStatut,
   EtatVideModule, GrilleAdaptative, afficherMessage, confirmer).
2. **Périmètre** : ne modifie que le module sur lequel je te demande de travailler.
   `lib/core/` et `pubspec.yaml` : seulement si nécessaire, en me le signalant.
   Ne touche jamais aux autres modules ni à `lib/modules/voyage/email_service.dart`.
3. **Schéma** : toute modification = nouvelle version de base (prochaine : **6** ; la v5 est
   l'intégration des branches fil d'actualité + transporteur).
   - Ajoute `locationMigrationV6` / `hebergementMigrationV6` (ALTER TABLE ... ADD COLUMN avec
     DEFAULT, ou CREATE TABLE IF NOT EXISTS), appelées dans `_migrerLocation` /
     `_migrerHebergement` avec un test de présence de colonne (comme pour v2 à v4).
   - Pour modifier une contrainte CHECK : reconstruire la table comme `hebergementMigrationV4`.
   - Mets AUSSI à jour les `CREATE TABLE` de `locationTables` / `hebergementTables`.
   - Ne casse jamais les données existantes ; ajoute un test de migration.
   - Ne renomme pas une colonne existante (SQLite ne le permet pas proprement).
4. **SQL** : requêtes paramétrées (`?`) uniquement ; écritures multi-étapes dans `db.transaction`.
5. **Réseau** : timeout 10 s, try/catch, l'appli continue hors connexion avec un message clair.
   **Aucune clé API dans le code** : `String.fromEnvironment('...')` (--dart-define).
   Client `http.Client` injectable pour tester avec `MockClient` (package:http/testing.dart).
6. **Packages** : aucun ajout sans mon accord. Avant d'en ajouter un, explique pourquoi,
   vérifie sa compatibilité Dart 3.5 / flutter_map 7, et les permissions Android nécessaires
   (`android/app/src/main/AndroidManifest.xml`).
7. **Tests** : toute nouvelle règle métier a son test dans `test/location_hebergement_test.dart`.
   `flutter analyze` sans aucune remarque (lints actifs : `prefer_const_constructors`,
   `prefer_single_quotes`, `avoid_print`).
8. **Méthode** : une fonctionnalité à la fois. Avant de coder, lis les fichiers concernés et
   annonce la liste des fichiers que tu vas toucher. Après : lance analyze + test, corrige,
   puis résume (fichiers modifiés, migration, comment tester à la main en 5 étapes).
   Propose un message de commit, mais ne fais pas de commit ni de push sans que je le demande.

## 4. État actuel (version 5 — déjà fait, ne pas refaire)

### Commun (`lib/core/`)
- `services/` : `GeminiService` (JSON, 10 s, IaException), `HuggingFaceService` (vision),
  `GeocodageService` (Nominatim, 1 req/s).
- `utils/` : `tarification.dart` (week-end, juillet-août, remise >= 7 unités), `geo.dart`
  (distance, regroupement de marqueurs), `pdf_simple.dart` (PDF sans package), `json_listes.dart`.
- `widgets/` : `CalendrierDisponibilite`, `ZoneSignature`, `ChoisirPositionScreen`,
  `CarteEmplacement`, `GaleriePhotos`.

### Location (`lib/modules/location/`)
- `vehicule` : type, année, couleur, immatriculation unique, carburant, boîte, places,
  kilométrage + révision (km_derniere_revision, intervalle_revision), tarifs dynamiques (%),
  photos, position, statut, propriétaire. `estElectrique`, `revisionDue`.
- `location_vehicule` : options (JSON), lieux, notes, clôture (retour, km, pénalité x1,5),
  numéro de permis, contrat signé (date + tracé). `blocage_vehicule` : dates bloquées.
- Repository : filtres (`FiltresVehicule` : prix, année, carburant, boîte, places,
  disponibilité, tri prix / popularité / distance), blocages, révision, contrat, avis,
  `toutesLesLocations`, `statistiques()` (actives, CA, top, occupation, revenus par type,
  maintenance, révisions dues).
- IA (`location_ia_service.dart`) : texte libre -> filtres, recommandation, description,
  résumé d'avis, prix juste, chatbot, contrôle des photos (Hugging Face). Repli local.
- Écrans : liste (filtres, carte, assistant IA), carte regroupée, fiche (calendrier +
  réservation rapide, avis, entretien, blocages, photos), formulaire (géocodage, carte, IA,
  tarifs), réservation (calendrier, lieux, options, permis, détail du prix, e-mail),
  contrat (signature, PDF), suivi simulé + géorepérage, admin Flotte / Réservations.

### Hébergement (`lib/modules/hebergement/`)
- `hebergement` : types (dont riad), étoiles, règles, superficie, capacité, chambres,
  équipements, photos, position, tarifs dynamiques, note (avis du forum), statut, propriétaire.
- `reservation_hebergement` : type de chambre (coefficient de prix), statuts check_in /
  check_out, code d'arrivée à 6 chiffres. `blocage_hebergement` : fermetures.
- Repository : filtres (`FiltresHebergement` : prix, étoiles, note, voyageurs, équipements,
  disponibilité, tri popularité / distance), nuits complètes, fermetures, check-in / check-out,
  `tousLesSejours`, répartition des notes.
- IA (`hebergement_ia_service.dart`) : recherche libre, recommandation par profil, description
  SEO, résumé d'avis, prix conseillé, concierge, itinéraire + hébergement, photos IA.
- Écrans : liste (filtres, carte avec prix, assistant, comparateur 2-3), fiche (calendrier,
  répartition des notes, résumé IA, concierge, fermetures, photos), formulaire, réservation
  (type de chambre, détail du prix), Mes séjours (code d'arrivée), admin Établissements / Séjours.

## 5. Ce qui reste (non fait volontairement)

- Upload de photos / permis depuis la galerie (`image_picker`) : photos par URL pour l'instant.
- Position réelle de l'utilisateur (`geolocator`) : « proche de moi » via un point choisi sur la carte.
- Partage / impression du PDF (`printing`, `share_plus`) : PDF enregistré dans le dossier de l'app.
- QR code du check-in (`qr_flutter`) : code à 6 chiffres affiché.
- Vidéo, visite 360°, AR : non commencés.
- Tout nouveau package : accord du groupe + permissions Android.

## 6. Points connus à ne pas oublier
- `README.md` s'arrête à la section 3 (sections 4 à 16 manquantes). `docs/integration.md` décrit la fusion des branches.
- `CONTRIBUTING.md` et `docs/repartition_modules.md` décrivent encore l'ancien template.
- `core/utils/dates.dart` : `nombreDeJours` utilise `difference().inDays` en heure locale
  (peut perdre un jour au passage heure d'été/hiver) ; la location utilise
  `LocationVehicule.ecartJours` (UTC). Ne pas corriger dans core sans accord du groupe.
- Écrans admin protégés par `GardeAdmin` (route dans `core/routes/app_routes.dart`).
- EmailJS côté compte : activer « Allow EmailJS API for non-browser applications ».
