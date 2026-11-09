# Serveur IA du module transporteur

Ce serveur applicatif exécute les trois tâches IA d'Abir Gamoudi (cahier des charges, §7.2) :

| Route | Tâche | Entrée | Sortie |
|---|---|---|---|
| `POST /api/transport/interpreter-commande` | Interprétation de commande | `texte`, `date_reference` | `depart`, `arrivee`, `date`, `budget` |
| `POST /api/transport/classer-voyageurs` | Classement des voyageurs | `depart`, `arrivee`, `date`, `candidats` | liste `{voyageur_id, score, raison}` triée |
| `POST /api/transport/resumer-trajet` | Résumé d'un trajet | `depart`, `arrivee`, `date`, `prix`, `statut`, `transporteur` | `{resume}` |

Le modèle est `claude-haiku-5-5`, appelé via l'API Messages d'Anthropic. Le serveur n'envoie jamais `temperature`, `top_p` ni `top_k`.

## Règles appliquées

- **Clé dans l'environnement uniquement** : `ANTHROPIC_API_KEY`. Elle n'est ni dans le code, ni dans l'application, ni dans les journaux.
- **Appels depuis le serveur uniquement** : l'application Flutter ne contacte jamais le modèle.
- **Validation des entrées** : une entrée incorrecte renvoie 400, sans appel au modèle.
- **Validation des sorties** : seul le JSON attendu est renvoyé. Les identifiants de voyageurs inconnus sont ignorés, les scores sont bornés à 0-100, les dates impossibles sont mises à `null`.
- **Données minimales** : le classement n'envoie au modèle que l'identifiant et les voyages d'un voyageur, sans nom ni contact.
- **Prix non calculés par le modèle** : le prix est transmis tel quel, et le résumé ne doit pas le modifier.
- **Repli côté application** : sans clé (503), en erreur (502) ou en cas de délai, l'application utilise ses règles locales. L'utilisateur n'est jamais bloqué.

## Lancer le serveur (Windows, PowerShell)

Prérequis : Node.js 18.17 ou plus récent (version LTS recommandée).

```powershell
cd C:\Users\ABIR\Projects\projet_mobile\server
$env:ANTHROPIC_API_KEY = "sk-ant-..."   # votre clé, saisie à chaque session, jamais dans un fichier
node index.js
```

Le serveur écoute sur `http://127.0.0.1:3000`. L'émulateur Android atteint ce poste à l'adresse `10.0.2.2:3000`, qui correspond déjà à `ApiService.baseUrl`.

Pour un téléphone réel sur le même Wi-Fi :

```powershell
$env:HOST = "0.0.0.0"
node index.js
```

Il faut alors changer `ApiService.baseUrl` dans l'application pour l'adresse IP locale du PC (par exemple `http://192.168.1.10:3000/api`). Le serveur n'a pas d'authentification : ne l'exposez pas sur un réseau que vous ne contrôlez pas.

Sans clé, le serveur démarre quand même et répond 503. L'application fonctionne alors avec ses règles locales.

## Tests

```powershell
cd C:\Users\ABIR\Projects\projet_mobile\server
npm test
```

Les tests utilisent un faux service Anthropic local : aucun appel réseau réel et aucune clé nécessaire. Ils vérifient la validation, le format de la requête (modèle, en-têtes, absence de `temperature`/`top_p`/`top_k`), le filtrage des identifiants inconnus, le fait que noms et contacts ne partent pas vers le modèle, et les codes 400, 404, 405, 502 et 503.

## Variables d'environnement

| Variable | Obligatoire | Défaut | Rôle |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | oui, pour l'IA | — | Clé API Anthropic |
| `PORT` | non | `3000` | Port d'écoute |
| `HOST` | non | `127.0.0.1` | Interface d'écoute (`0.0.0.0` pour un téléphone réel) |
| `ANTHROPIC_BASE_URL` | non | `https://api.anthropic.com` | URL de base (tests, proxy d'entreprise) |
