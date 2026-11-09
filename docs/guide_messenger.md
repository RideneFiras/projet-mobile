# Guide Messenger — exemple pas à pas (méthode SyrWriteHub)

## 1. Principe SyrWriteHub (C:\projects1\syrwritehub-mobile)
Leur écran `chat_screen.dart` suit ce flux :
`_loadRooms` (liste) → `_startConversation(userId)` → `_loadMsgs(roomId)`
→ saisie (`_send`, `_pickPhoto`, `_showEmojiPicker`, `_toggleVoice`/`_sendVoice`)
→ appels (`_startCall(video)`).

Chez nous, le backend Spring Boot est remplacé par **SQLite local** (même écran, mêmes boutons) :
la conversation se crée à la première frappe, sans serveur.

## 2. Exemple complet (2 comptes, même appareil Android)

| Étape | Qui | Action |
|---|---|---|
| 1 | **Sarra** (Voyageur) | `Créer un compte` `sarra@test.tn` / `Abcd1234` |
| 2 | Sarra | Publier un post → onglet Actualités → **Publier** |
| 3 | Sarra | Profil → **Se déconnecter** |
| 4 | **Karim** (Client) | `Créer un compte` `karim@test.tn` / `Abcd1234` |
| 5 | Karim | Onglet Actualités → post de Sarra → **Message** |
| 6 | Karim | Conversation avec Sarra ouverte → écrire « Bonjour » → **Envoyer** |
| 7 | Karim | 😀 emoji → choisir · 📷 photo · 🎙 vocal (1 clic = enregistre, 2e = envoie) |
| 8 | Karim | 📞 / 🎥 → appeler |
| 9 | Déconnexion | retour à la connexion |
| 10 | **Sarra** | Messenger (💬 en haut du fil) → conversation Karim → lit « Bonjour » → répond |

## 3. Équivalence des méthodes
| SyrWriteHub | Travel (nous) |
|---|---|
| `_loadRooms()` | `MessageRepository.conversations(moiId)` (liste SQL) |
| `_searchUsers()` | bouton ✏️ → `UserRepository.tousLesUtilisateurs()` |
| `_startConversation(userId)` | bouton **Message** d'un post → conversation directe |
| `_loadMsgs(roomId)` | `MessageRepository.conversation(moi, autre)` |
| `_send()` | `MessageRepository.envoyer(type texte)` |
| `_pickPhoto()` | `ImagePicker` → bulle image (base64) |
| `_toggleVoice()` / `_sendVoice()` | `AudioRecorder` (AAC, fichier temporaire) |
| `_playVoice()` | `AudioPlayer` (BytesSource) |
| `_startCall(video)` | `AppelScreen` (WebRTC boucle locale) |
| notifications push (Firebase) | cloche 🔔 locale (`notification_fil`) |

## 4. Points à retenir
- Tout est **stocké en local** : les messages survivent aux déconnexions et changements de compte.
- Un utilisateur ne peut modifier/supprimer que **ses propres** commentaires (SQL auteur seul).
- **Vocal et appels : Android uniquement** (autorisation micro requise).
