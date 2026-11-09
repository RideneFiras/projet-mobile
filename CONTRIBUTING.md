# Règles de travail en équipe

## 1. Qui touche à quoi

| Fichier / dossier | Qui le modifie |
|---|---|
| `lib/features/membreX/` (tout le dossier) | **Uniquement** le membre X |
| `lib/features/membreX/membreX_schema.dart` | Le membre X (ses tables SQLite) |
| `lib/core/routes/app_routes.dart` | Chacun ajoute **ses** lignes de route, rien d'autre |
| `lib/features/home/home_screen.dart` | Chacun renomme **sa** tuile, rien d'autre |
| `lib/core/`, `pubspec.yaml`, `auth/` | Le responsable, après accord du groupe |

Besoin d'un nouveau package (ex : `image_picker`) ? Prévenez le groupe : un seul membre l'ajoute au `pubspec.yaml`.

## 2. Branches Git

- `main` : version qui marche toujours. **Personne ne pousse directement dessus.**
- `feature/membre1`, `feature/membre2`... : une branche par membre.

### Au quotidien

```powershell
git checkout feature/membre1
git pull origin main             # récupérer le travail des autres
# ... coder ...
flutter analyze                  # 0 erreur avant de pousser
flutter test
git add .
git commit -m "membre1: ajout du formulaire de réservation"
git push origin feature/membre1
```

Puis sur GitHub : **Pull Request** `feature/membre1` → `main`. Un autre membre relit puis fusionne (Merge).

### En cas de conflit

```powershell
git pull origin main
# ouvrir les fichiers marqués en conflit dans VS Code -> "Accept Both" le plus souvent
git add .
git commit -m "résolution conflit"
git push
```

## 3. Base de données SQLite

- Vos tables vont dans **votre** `membreX_schema.dart`, avec `CREATE TABLE IF NOT EXISTS`.
- Une nouvelle table est créée automatiquement au prochain lancement.
- Vous avez **modifié** une table existante (nouvelle colonne) ? Désinstallez l'app de l'émulateur (appui long sur l'icône → Désinstaller), puis relancez `flutter run`.
- Les données SQLite restent sur chaque téléphone / émulateur : elles ne sont **pas** partagées par GitHub (seul le code l'est).

## 4. Conventions de code

- Fichiers en `snake_case.dart`, classes en `PascalCase`.
- Un modèle = `toMap()` / `fromMap()` (voir `exemple_crud/item.dart`).
- Accès à la base uniquement via un *repository* (voir `exemple_crud/item_repository.dart`), jamais directement dans un écran.
- Toujours `if (!mounted) return;` après un `await` dans un écran.
- Ne jamais committer de mot de passe, clé d'API ou fichier `.env`.
