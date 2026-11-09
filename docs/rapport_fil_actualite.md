# Rapport — Module Fil d'actualité (Travel Platform)

## 1. Périmètre de la tâche
Le fil d'actualité est notre tâche dédiée (distincte de la gestion des utilisateurs et des 5 autres modules). Principe directeur : **fil commun pour tous les utilisateurs connectés**, chacun publie, réagit, commente, et **ne modifie ou supprime que ses propres contenus** — comme Facebook.

## 2. Justification — 5 points d'évaluation

### 2.1 Interface / UX (UI/UX)
- En-tête en dégradé turquoise → orange, logo et cloche notifications avec pastille rouge (nombre de non-lues).
- Haut du fil inspiré Facebook : champ « Quoi de neuf, [prénom] ? » avec photo de profil + rangée de **stories** (cercles dégradés) des auteurs récents.
- Cartes : nom + rôle (pastille Client/Voyageur/Transporteur), photo de profil ronde, temps relatif (« il y a 5 min »), photo du post plein largeur, pastilles catégorie.
- Actions : J'aime + flèche ouvrant un mini-menu de 6 réactions **à côté du bouton** (sans recouvrir l'écran), Commentaires, Partager, Message.
- Sondage : boutons de vote + barres de progression (%); Annonce : bloc événement avec bouton « Participer ».
- Expérience : pull-to-refresh, appels API avec repli local, écrans vides explicites.

### 2.2 Métier (règles fonctionnelles)
| Règle | Implémentation |
|---|---|
| Tous les connectés peuvent publier | Formulaire accessible sans garde admin ; l'auteur est l'utilisateur en session |
| Seul l'auteur modifie/supprime ses posts et commentaires | Vérifié **dans le SQL** (`WHERE id=? AND auteur_id=?` → `false` sinon), pas seulement à l'écran |
| Un vote / une réaction / une participation par utilisateur et par post | Contraintes `UNIQUE(actualite_id, utilisateur_id)` + transaction (changer d'avis remplace) |
| Validation | Titre 3–120, contenu 10–2000 (sondage : question remplace le texte) — même sur serveur |
| Fil commun + recherche + catégories + épinglés en haut | `actualite_fil.dart` (logique pure, testée) |

### 2.3 Base de données locale SQLite
- Base `travel_platform.db` (sqflite), ouverte en singleton, `PRAGMA foreign_keys=ON`.
- Tables du fil : `actualite` (photo base64, épinglé, type_post, date/lieu, audience, catégorie), `commentaire_actualite` (cascade), `sondage_option`, `sondage_vote`, `reaction_actualite`, `participation_actualite`, `notification_fil`, `message_prive`, `utilisateur.photo`.
- **Migration légère** (`_migrerColonnesFil`) : les bases déjà créées (Chrome/IndexedDB, émulateur) reçoivent les colonnes manquantes au lieu de planter — pas de migration destructive.
- Index/constraints : clés étrangères CASCADE (commentaires/votes supprimés avec le post), CHECK sur les statuts/catégories.

### 2.4 Session
- `SessionService` (SharedPreferences) ne stocke que l'identifiant utilisateur.
- Le rôle et l'auteur sont relus en base à chaque ouverture (impossible de devenir admin en modifiant les préférences).
- Déconnexion = suppression de la session uniquement : **les données persistent** (testé : post du compte A visible par le compte B).

### 2.5 Q/A (questions/réponses du professeur)
- **Pourquoi fil commun plutôt que par rôle ?** Le cahier des charges décrit un fil d'actualité de la plateforme : un voyageur annonce, un client commente, un transporteur réagit — le rôle reste visible sur chaque post.
- **Pourquoi auteur seul ?** Confiance et pédagogie : on ne touche jamais aux contenus des autres (règle testée en base).
- **Pourquoi pas de serveur pour les posts ?** L'architecture du cours est SQLite locale ; l'API REST Node (`server/actualite_api.js`) est fournie en couche de synchronisation, avec repli local obligatoire (l'application reste fonctionnelle hors-ligne et sans clé).
- **Comment l'IA est-elle encadrée ?** Génération côté serveur uniquement (jamais depuis l'application), brouillon à valider par l'humain avant publication, sortie validée (JSON, longueurs), sans prix/date inventés, repli gabarit local en cas d'échec.

## 3. Valeur ajoutée (au-delà du cahier des charges)
1. **Notifications** (cloche + pastille) : commentaire/J'aime/vote/participation → l'auteur est notifié.
2. **Messenger privé** (conversations, bulles) relié aux posts.
3. **Réactions emoji type Facebook** (6 types, choix par menu à côté du bouton, compteurs par type).
4. **Sondages** (question à la place du texte, vote unique, résultats en %).
5. **Posts avec photo** (pseudo-Facebook, compression, base64) + **photo de profil** par compte.
6. **Post annonce** (date + lieu + « Participer » avec compteur).
7. **Épingler** ses posts en haut du fil.
8. **Brouillon IA** (serveur Node/Anthropic, §7.2 du cahier) + API REST complète des actualités (CRUD, validation, pagination, tests Node 31/31).
9. **Design moderne** : thème Material 3, dégradés, ombres, stories, temps relatif, animation « pop ».

## 4. Tests (preuves)
- Flutter : **50/50 réussis** (dont fil avancé, commentaires auteur-seul, sondage/réaction, logique pure).
- Serveur Node : **31/31 réussis** (13 transport existants + 18 actualités : validation, 403/404/405, sondage, réactions, pagination, brouillon IA avec faux service).
- `flutter analyze` : 0 erreur. Scénario cross-comptes validé en test : post de A visible par B, notification croisée, messenger persistant.

## 5. Structure des fichiers (notre module uniquement)
`lib/modules/user/` : `actualite.dart`, `actualite_fil.dart`, `actualite_api.dart`, `commentaire.dart`, `commentaire_repository.dart`, `sondage.dart`, `sondage_repository.dart`, `reaction_repository.dart`, `participation_repository.dart`, `notification.dart`, `notification_repository.dart`, `message_prive.dart`, `message_repository.dart`, `screens/actualites_tab.dart`, `actualite_form_screen.dart`, `notifications_screen.dart`, `messenger_screen.dart`, `user_schema.dart` (tables), `admin_repository.dart`/`user_repository.dart` (requêtes). Serveur : `server/actualite_api.js` + `server/test/actualite_api.test.js`. Aucun module collègue modifié (voyage, transporteur, location, hébergement, forum relancés OK).
