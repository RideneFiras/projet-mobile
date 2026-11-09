# Module transporteur — « Transport »

Responsable du module : **Abir Gamoudi**. Ce dossier contient le module « Transport — Commandes, trajets et itinéraire ».

Le module n'inclut pas la location de véhicules : elle relève du module location, sous la responsabilité d'une autre personne.

## 1. Ce que fait le module

| Besoin | Où | Table |
|---|---|---|
| Profil transporteur : créer, consulter, modifier, désactiver (pas de suppression) | `TransporteursScreen`, `TransporteurFormScreen` | `transporteur` |
| Trajets : CRUD, statuts Planifié / En cours / Terminé / Annulé, duplication | `ReservationsScreen` (section Trajets), `TrajetFormScreen` | `trajet_transport` |
| Commandes du voyageur : référence, passagers, budget, statuts | `VoyageurScreen`, `CommandeFormScreen`, `MesCommandesScreen` | `commande_transport` |
| Matching automatique : la demande est proposée aux transporteurs compatibles | `CommandesOuvertesScreen`, `RelationsScreen` | `mise_en_relation` |
| Réservations confirmées : passagers, places, prise en charge, annulation avec motif, historique | `ReservationsScreen` (section Réservations), `MesCommandesScreen` | `reservation_transport`, `historique_reservation` |
| Itinéraire d'un trajet (distance et durée) | `VoyageurScreen` (bouton « Itinéraire »), `transport_itineraire_sheet.dart` | — (serveur `server/`) |

### Matching (sens de la proposition)

Une demande du voyageur est proposée automatiquement à chaque transporteur dont un trajet correspond :

- même ville de départ et même ville d'arrivée (sans tenir compte de la casse ni des accents) ;
- même jour que le trajet ;
- au moins autant de places libres que de passagers ;
- prix total du trajet (prix par personne × passagers) inférieur ou égal au budget, si un budget est indiqué ;
- trajet planifié, profil actif et disponible.

Le transporteur reçoit la proposition dans **Mises en relation** (ou **Commandes ouvertes**), puis accepte ou refuse. Accepter crée la réservation, passe la commande en « Acceptée », refuse les autres propositions et révèle le téléphone du voyageur. Refuser toutes les propositions refuse la commande.

Une proposition refusée apparaît dans **Réservations**, section **Demandes annulées**.

## 2. Règles métier

- **Un profil par compte transporteur.** Seul ce compte modifie ses trajets et ses réservations.
- **Coordonnées.** Le téléphone du voyageur n'est visible par le transporteur qu'après acceptation, et inversement. La règle est appliquée dans les requêtes SQL, pas seulement à l'écran.
- **Places.** Une acceptation ne dépasse jamais les places libres. Un trajet ne peut pas être réduit sous ses places déjà réservées.
- **Statuts de trajet.** Planifié → en cours ou annulé ; en cours → terminé. Annuler un trajet annule ses réservations ; le terminer clôt les commandes acceptées.
- **Annulation par le voyageur.** Libre tant que la demande est en attente. Une réservation s'annule au plus tard **24 h avant le départ**, avec un **motif obligatoire**.
- **Annulation par le transporteur.** À tout moment, avec un motif. Le motif est inscrit dans l'historique.
- **Prise en charge.** Le transporteur la confirme à l'arrivée du voyageur.

## 3. Écrans

| Fichier | Classe | Rôle |
|---|---|---|
| `screens/transporteurs_screen.dart` | `TransporteursScreen` | Profil du transporteur : fiche, modifier, désactiver ou réactiver |
| `screens/transporteur_form_screen.dart` | `TransporteurFormScreen` | Création ou modification du profil, photo ou logo facultative |
| `screens/reservations_screen.dart` | `ReservationsScreen` | Deux sections : **Trajets** (recherche, filtre par statut, tri, actions) et **Réservations** (passagers, prise en charge, annulation, historique, demandes annulées) |
| `screens/trajet_form_screen.dart` | `TrajetFormScreen` | Création ou modification d'un trajet, avec contrôles de dates et d'horaires |
| `screens/commandes_ouvertes_screen.dart` | `CommandesOuvertesScreen` | Propositions reçues : accepter ou refuser |
| `screens/relations_screen.dart` | `RelationsScreen` | Mises en relation : propositions en attente à accepter ou refuser, et historique filtré par réponse |
| `screens/voyageur_screen.dart` | `VoyageurScreen` | Recherche d'un trajet, tri (date, prix, places libres), pagination de 10 résultats, « Itinéraire », « Demander ce trajet » |
| `screens/commande_form_screen.dart` | `CommandeFormScreen` | Nouvelle demande ou modification |
| `screens/mes_commandes_screen.dart` | `MesCommandesScreen` | Suivi des demandes, modification, annulation, historique |

Les routes (`TransportRoutes`) n'ont pas changé.

## 4. Fichiers

- `transporteur_schema.dart` : création des six tables, avec leurs contraintes (CHECK, clés étrangères, unicité).
- `transport_repository.dart` : toutes les règles métier ci-dessus. Les écrans n'écrivent jamais en base directement.
- `transport_format.dart` : saisie et formatage (montants en centimes, heures HH:mm, dates ISO, contrôles de formulaire).
- `transport_trajet_api.dart` : itinéraire (`/transport/itineraire`) d'un trajet. L'application ne transmet aucune clé ; en cas de panne, un message d'erreur s'affiche sans bloquer le reste de l'écran.
- `transport_itineraire_sheet.dart` : feuille « Itinéraire » ouverte depuis un résultat de recherche (départ, arrivée, distance, durée).
- `transport_widgets.dart` : composants partagés sur l'UI Kit, dont le motif d'annulation et l'historique.
- `models/` : profil, trajet, commande, réservation, mise en relation, statuts.

## 5. Base de données — version 3

La version de la base passe de 2 à 3 (`DatabaseHelper`). La colonne `qr_code` disparaît de `reservation_transport`. La migration (`DatabaseHelper._mettreAJour`) supprime les six tables du module transporteur, puis `_creerTables` les recrée dans leur nouvelle forme.

- **Conséquence :** les données de test du module transporteur sont effacées. Les autres modules, et la table `utilisateur`, ne sont pas touchés.

## 6. Dépendances

- `image_picker` (^1.1.2) : choix de la photo ou du logo depuis la galerie.

## 7. Mise en route et vérification

À lancer sur le PC, dans l'ordre :

```bash
flutter pub get        # met à jour pubspec.lock (qr_flutter retiré)
flutter analyze
flutter test test/transport_test.dart
```

Ce travail a été écrit sans SDK Flutter disponible : la syntaxe Dart a été vérifiée, mais le projet n'a **pas** été compilé ni testé. Le premier `flutter analyze` peut donc signaler des erreurs à corriger.

Fichiers supprimés : `models/voyageur_candidat.dart`, la météo (écran, client, route et Open-Meteo), puis l'assistant IA (`transport_ia.dart`) et les routes IA du serveur (`interpreter-commande`, `resumer-trajet`, `classer-voyageurs`).

## 8. Limites connues

- **Photo :** choix depuis la galerie uniquement. La caméra n'est pas proposée (Windows, web).
- **Heures :** les horaires sont enregistrés sans fuseau horaire, à la minute, dans l'heure locale de l'appareil.
- **Options hors cahier des charges** (non développées) : prédiction de la demande.
- **Core et pubspec :** les modifications de `database_helper.dart` (version 3) et de `pubspec.yaml` (dépendance `qr_flutter` retirée) touchent du code partagé. Elles ne concernent que le module transporteur.
