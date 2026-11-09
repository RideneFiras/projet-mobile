# Travel Platform – application mobile Flutter + SQLite

Projet 5SAE3 – ESPRIT. Application mobile de voyage organisée autour du voyage : transport (commandes clients et trajets de transporteurs), location de voiture, hébergement, forum et avis, actualités. L'interface suit le UI Kit Travel Platform (turquoise #0F7B83, orange #F68B3F, police Plus Jakarta Sans).

## En bref

| Élément | Valeur |
| :--- | :--- |
| **Version de l'application** | 1.0.0+1 (`pubspec.yaml`) |
| **Framework** | Flutter, Dart ^3.5.0, Material 3 |
| **Base de données** | SQLite locale, fichier `travel_platform.db`, version de schéma 5, 31 tables |
| **Rôles** | Client, Voyageur (`traveller`), Transporteur (`transporter`), Administrateur |
| **Modules** | 6 dossiers dans `lib/modules/` |
| **Tests** | 119 tests Flutter dans `test/` (15 fichiers) + 42 tests Node dans `server/test/` |
| **Services IA & API** | Google Gemini (voyage, location, hébergement), Hugging Face (contrôle des photos), EmailJS, Nominatim (géocodage), serveur Node `server/` (itinéraire OpenRouteService + API REST des actualités) |

---

> **Branches fusionnées** : fil d'actualité + transporteur + location/hébergement/voyage. Voir `docs/integration.md` (décisions, migration v5, comment tester).

## Sommaire
1. Modules et responsables
2. Fonctionnalités détaillées
3. Architecture
4. Base de données
5. API REST et serveur IA
6. Intelligence artificielle
7. Installation (Windows 10 / 11)
8. Lancer l'application
9. Tests
10. Comptes et données de départ
11. Règles de saisie et de validation
12. Sécurité
13. Dépannage et journaux
14. Workflow d'équipe
15. État d'avancement et points ouverts
16. Structure du projet

---

## 1. Modules et responsables

| Dossier | Module | Responsable | Tables | Routes principales |
| :--- | :--- | :--- | :--- | :--- |
| `lib/modules/user` | Comptes, rôles, accueil, fil d'actualité, messenger, admin | Abdeslem Kessentini | `utilisateur`, `actualite`, `commentaire_actualite`, `reaction_actualite`, `sondage_option`, `sondage_vote`, `participation_actualite`, `notification_fil`, `message_prive`, `historique_post`, `reaction_commentaire`, `partage_post` | `/onboarding`, `/login`, `/signup`, `/home`, `/admin/...` |
| `lib/modules/voyage` | Voyage & Réservation de Vol (IA & Carte) | Mouhamed Dhia Dridi | `voyage`, `voyage_vol`, `voyage_itineraire` | `/voyage/liste`, `/voyage/nouveau`, `/voyage/detail` |
| `lib/modules/transporteur` | Transport (commandes, trajets, réservations, itinéraire et carte) | Abir Gamoudi | `transporteur`, `trajet_transport`, `commande_transport`, `mise_en_relation`, `reservation_transport`, `historique_reservation` | `/transport/...` |
| `lib/modules/location` | Location de voiture | Roua Dhafer | `vehicule`, `location_vehicule`, `blocage_vehicule` | `/location`, `/location/gestion` |
| `lib/modules/hebergement` | Hébergement | Oussema Mrayah | `hebergement`, `reservation_hebergement`, `blocage_hebergement` | `/hebergement`, `/hebergement/gestion` |
| `lib/modules/forum` | Forum et avis | Sirine Hamzaoui | `forum_sujet`, `forum_reponse`, `avis` | `/forum`, `/forum/avis` |

---

## 2. Fonctionnalités détaillées

### 2.1 Comptes, accueil et administration (`user` – Abdeslem Kessentini)
- **Démarrage** : écran Splash (~1,4 s), puis parcours d'accueil en 3 écrans si aucune session n'est ouverte.
- **Inscription & Connexion** : rôles Client, Voyageur et Transporteur. Mot de passe haché avec sel aléatoire.
- **Administration** : gestion de la liste des utilisateurs et des actualités.
- **Fil d'actualité commun** : tout utilisateur connecté publie (texte, photo, sondage, annonce avec « Participer »), réagit (6 réactions), commente et répond, partage, épingle ses posts ; il ne modifie ou supprime que ses propres contenus (règle appliquée dans le SQL). Notifications (cloche), historique des modifications, API REST `server/actualite_api.js` avec repli local. Détails : `docs/rapport_fil_actualite.md`.
- **Messenger** : conversations privées (texte, image, message vocal) et appels audio/vidéo (`docs/guide_messenger.md`). Permissions micro/caméra déclarées pour Android et iOS.

### 2.2 Voyage (`voyage` – Mouhamed Dhia Dridi)
- **Moteur de réservation de vols & carte** : Sélection interactive sur carte OpenStreetMap (`flutter_map`) avec pins de tarifs par destination. Sélection multi-classes (**Économique**, **Affaires**, **Première**) avec calcul dynamique du coût et ajustement automatique du budget.
- **Générateur d'itinéraires IA** : Intégration native de **Google Gemini 1.5-flash** (`voyage_ia_service.dart`) produisant un programme de voyage jour par jour selon la durée et la gamme de confort (**Économe**, **Confortable**, **Premium**).
- **Confirmation par e-mail silencieuse** : Déclenchement automatique d'e-mails de confirmation via l'API REST **EmailJS** (`email_service.dart`) lors de la validation du voyage.
- **Gestion du statut** : Recalcul dynamique en temps réel (`Planifié`, `Actif`, `Terminé`, `Annulé`) selon les dates de séjour.
- **Stockage hors-ligne** : Persistance complète SQLite (`voyage`, `voyage_vol`, `voyage_itineraire`).

### 2.3 Transport (`transporteur` – Abir Gamoudi)
- **Transporteurs & Trajets** : Fiches de transporteurs (Bus, Train, Avion, Bateau, Covoiturage), création, modification et duplication des trajets, recherche triée par date ou prix.
- **Commandes client** : Publication de commandes de transport. Une commande est proposée automatiquement aux trajets compatibles : même jour, places disponibles et budget total (prix × passagers) respecté.
- **Mises en relation** : Proposition de voyageurs par les transporteurs et masquage des coordonnées jusqu'à acceptation.
- **Réservations** : Accepter une proposition crée une réservation et refuse les autres propositions de la même commande. Le voyageur ne peut annuler qu'au moins 24 h avant le départ, avec un motif ; le transporteur annule également avec un motif. Un historique est tenu pour chaque réservation.
- **Itinéraire ** : Distance et durée routières entre deux villes, calculées par OpenRouteService via le serveur `server/`. Sans clé ou si le service est indisponible, une estimation est affichée. Un tracé A → B est dessiné dans la feuille d'itinéraire, sans fond de carte.

### 2.4 Location de voiture (`location` – Roua Dhafer)
- **Flotte & Réservations** : Gestion des véhicules et réservation par plage de dates avec contrôle anti-chevauchement.

### 2.5 Hébergement (`hebergement` – Oussema Mrayah)
- **Établissements & Séjours** : Réservation d'hôtels/hébergements avec calcul du prix par nuitée.

### 2.6 Forum et avis (`forum` – Sirine Hamzaoui)
- **Espace communautaire** : Publication de sujets, réponses et avis notés (1 à 5 étoiles) sur les prestations.

---

## 3. Architecture

```text
Écrans (screens/)  ──►  Repositories (*_repository.dart)  ──►  DatabaseHelper (SQLite)
                                  │
                                  ├──► VoyageIaService ──────► Google Gemini API
                                  ├──► EmailService ─────────► EmailJS API
                                  └──► ApiService ───────────► Serveur Node (itinéraire OpenRouteService, API actualités)