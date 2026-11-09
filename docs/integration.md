# Intégration des branches (schéma v5)

Branche : `integration/fil-actualite`, créée depuis `hebergement-module`.
Elle réunit trois lignes de travail qui n'avaient pas d'ancêtre commun utile
(`origin/main` ne contient que le README) :

| Source | Contenu repris |
| --- | --- |
| `hebergement-module` (base) | voyage, location, hébergement, forum, noyau `core/` |
| `origin/transporteur-module` (merge réel) | module transporteur « trajets / itinéraire / carte », serveur d'itinéraire |
| Archive « fil d'actualité » (sans `.git`) | module `user` complet, API Node des actualités, tests et docs du fil |

## Historique Git

```
chore(git)  .gitattributes
merge       origin/transporteur-module  + réconciliation du schéma et des requêtes
feat(user)  fil d'actualité complet
docs / test migration v5 et documentation
```

Le merge du transporteur est un vrai merge : les commits d'Abir sont ancêtres de la
branche, donc `git merge origin/transporteur-module` plus tard ne rejouera pas de conflits.
Aucun historique n'a été réécrit, rien n'a été poussé.

## Décisions de fusion

- **Transporteur** : la version de `transporteur-module` (6 tables) remplace l'ancienne
  version de `hebergement-module` (4 tables + assistant IA Claude). Les fichiers IA
  (`transport_ia.dart`, `voyageur_candidat.dart`, `server/transport_ai.js`,
  `server/anthropic.js`) ne sont plus dans l'arbre ; ils restent dans l'historique
  (`git show c6a83b1:server/transport_ai.js`). Aucun écran de la nouvelle version ne les appelle.
- **User / fil d'actualité** : la version du fil est un sur-ensemble (la version de l'autre
  branche n'avait aucune modification propre).
- **Voyage, location, hébergement, forum, `ui_kit`** : version de `hebergement-module`.
- **`pubspec.yaml`** : union des dépendances ; `pubspec.lock` du fil (le plus complet).
  `flutter pub get` le recalcule de toute façon.

## Corrections liées à la fusion

Deux requêtes utilisaient encore l'ancien schéma transport (déjà cassées sur
`transporteur-module`) :

- `forum_repository.dart` : le `SELECT` des avis lisait `reservation_transport.depart/arrivee`
  (colonnes disparues) et faisait échouer toute la liste des avis. Les avis « transport »
  visent maintenant `trajet_transport`.
- `dashboard_repository.dart` : `client_id`, `auteur_id` et les statuts en minuscules
  n'existent plus. (Cette classe n'est appelée par aucun écran pour l'instant.)

## Migration de base de données (v5)

Les deux branches utilisaient le même numéro de version pour des états différents
(v3 = transporteur recréé d'un côté, v3 = options de location de l'autre).
`DatabaseHelper` se fonde donc sur la **structure des tables** :

| Base installée avec… | Effet à l'ouverture |
| --- | --- |
| location/hébergement v4 (ancien transporteur) | tables transport recréées (données transport perdues), avis « transport » supprimés, colonnes du fil ajoutées |
| fil / transporteur v3 (location et hébergement v1) | étapes v2, v3 et v4 de location/hébergement appliquées, transport conservé |
| installation neuve | création directe |

Les données des autres modules sont conservées. Pour repartir de zéro : désinstaller
l'application de l'émulateur.

**Prochaine version de schéma : 6.** `CLAUDE.md` a été mis à jour en conséquence.

## Comment tester

```
flutter pub get
flutter analyze
flutter test                    # 119 tests, dont test/integration_migration_test.dart
cd server && npm test           # 42 tests Node
```

Application : `flutter run` (avec les `--dart-define` listés dans `CLAUDE.md`). Pour
l'itinéraire et la synchronisation des actualités : `cd server && npm start`.

Contrôle manuel en 5 étapes :
1. Se connecter avec `admin@travel.tn` / `Admin1234` (debug), ouvrir l'onglet Actualités.
2. Créer un compte client, publier un post avec photo, réagir et commenter depuis un autre compte.
3. Compte transporteur : créer un profil et un trajet, puis demander ce trajet côté voyageur.
4. Forum → Avis : l'onglet s'ouvre et propose les trajets comme cibles « Transport ».
5. Location et hébergement : réserver depuis un voyage ; Messenger : envoyer un vocal (mobile).

## Points ouverts

- `voyage_form_screen.dart` envoie l'e-mail de confirmation à une adresse codée en dur
  (`dhiadridi56@gmail.com`, commentaire « remplacez par votre e-mail de test ») : à remplacer
  par l'e-mail du compte connecté. Non modifié ici (module d'un autre membre).
- Les tests Dart n'ont pas pu être exécutés lors de l'intégration (pas de SDK Flutter dans
  l'environnement) : lancer `flutter analyze` et `flutter test` avant de pousser.
- Pour iOS, `permission_handler` demande en plus les macros de permission dans le `Podfile`
  (`PERMISSION_MICROPHONE`, `PERMISSION_CAMERA`) au premier build.
