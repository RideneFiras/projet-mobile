# Travel Platform – application mobile Flutter + SQLite

Projet 5SAE3 – ESPRIT. Application mobile de voyage organisée autour du voyage : transport (commandes clients et trajets de transporteurs), location de voiture, hébergement, forum et avis, actualités. L'interface suit le UI Kit Travel Platform (turquoise #0F7B83, orange #F68B3F, police Plus Jakarta Sans).

## En bref

| Élément | Valeur |
| :--- | :--- |
| **Version de l'application** | 1.0.0+1 (`pubspec.yaml`) |
| **Framework** | Flutter, Dart ^3.5.0, Material 3 |
| **Base de données** | SQLite locale, fichier `travel_platform.db`, version de schéma 1, 16 tables |
| **Rôles** | Client, Voyageur (`traveller`), Transporteur (`transporter`), Administrateur |
| **Modules** | 6 dossiers dans `lib/modules/` |
| **Tests Flutter** | 31 tests dans `test/` (4 fichiers) |
| **Services IA & API** | Google Gemini 1.5-flash REST API, EmailJS REST API, Serveur transport Node.js (itinéraire OpenRouteService) |

---

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
| `lib/modules/user` | Comptes, rôles, accueil, actualités, admin | Abdeslem Kessentini | `utilisateur`, `actualite` | `/onboarding`, `/login`, `/signup`, `/home`, `/admin/...` |
| `lib/modules/voyage` | Voyage & Réservation de Vol (IA & Carte) | Mouhamed Dhia Dridi | `voyage`, `voyage_vol`, `voyage_itineraire` | `/voyage/liste`, `/voyage/nouveau`, `/voyage/detail` |
| `lib/modules/transporteur` | Transport (commandes, trajets, réservations, itinéraire et carte) | Abir Gamoudi | `transporteur`, `trajet_transport`, `commande_transport`, `mise_en_relation`, `reservation_transport`, `historique_reservation` | `/transport/...` |
| `lib/modules/location` | Location de voiture | Roua Dhafer | `vehicule`, `location_vehicule` | `/location`, `/location/gestion` |
| `lib/modules/hebergement` | Hébergement | Oussema Mrayah | `hebergement`, `reservation_hebergement` | `/hebergement`, `/hebergement/gestion` |
| `lib/modules/forum` | Forum et avis | Sirine Hamzaoui | `forum_sujet`, `forum_reponse`, `avis` | `/forum`, `/forum/avis` |

---

## 2. Fonctionnalités détaillées

### 2.1 Comptes, accueil et administration (`user` – Abdeslem Kessentini)
- **Démarrage** : écran Splash (~1,4 s), puis parcours d'accueil en 3 écrans si aucune session n'est ouverte.
- **Inscription & Connexion** : rôles Client, Voyageur et Transporteur. Mot de passe haché avec sel aléatoire.
- **Administration** : publication/suppression d'actualités, gestion de la liste des utilisateurs.

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
- **Itinéraire & carte** : Distance et durée routières entre deux villes, calculées par OpenRouteService via le serveur `server/`. Sans clé ou si le service est indisponible, une estimation est affichée. Un tracé A → B est dessiné dans la feuille d'itinéraire, sans fond de carte.
- **Actualisation** : Les listes se rafraîchissent toutes les 10 secondes et au retour dans l'application.
- **Serveur** : dans le dossier `server`, lancer `node index.js`. La clé OpenRouteService se met dans `server/.env` (voir `server/README.md`).
- Le module ne comprend plus de QR code, d'assistant IA ni de météo.

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
                                  └──► ApiService ───────────► Serveur transport (Node.js, OpenRouteService)