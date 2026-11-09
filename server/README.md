# Serveur du module transporteur

Ce serveur applicatif fournit l'itinéraire routier d'un trajet à l'application Flutter. Il n'appelle aucun modèle d'IA.

| Route | Rôle | Entrée | Sortie |
|---|---|---|---|
| `POST /api/transport/itineraire` | Itinéraire routier d'un trajet | `depart`, `arrivee` | `recommande` (avec `trace`, liste de `[lat, lon]` pour la carte), `alternatives`, `points` (`depart`, `arrivee` en `[lat, lon]`), `source` (`openrouteservice` ou `estimation`) |
| `GET /api/transport/sante` | État du serveur, sans afficher de secret | — | `statut`, `openrouteservice` |

## Règles appliquées

- **Clé dans `server/.env`** (ligne `OPENROUTESERVICE_API_KEY=`), fichier exclu de Git. Une variable d'environnement définie dans PowerShell est prioritaire. Elle n'est ni dans le code, ni dans l'application, ni dans les journaux.
- **Validation des entrées** : une entrée incorrecte renvoie 400, sans appel externe.
- **Erreurs externes neutres** : si OpenRouteService échoue, l'application reçoit un message sans détail technique (503). Le détail reste dans le journal du serveur.
- **Cache temporaire** : géocodage 24 h, itinéraire 6 h.
- **Sans clé OpenRouteService** : l'itinéraire est estimé à partir des coordonnées.

## Lancer le serveur (Windows, PowerShell)

Prérequis : Node.js 18.17 ou plus récent (version LTS recommandée). Aucun paquet à installer.

```powershell
cd C:\Users\ABIR\Downloads\projet-mobile-gestion-voyage\server
node index.js
```

Laissez cette fenêtre ouverte pendant l'utilisation de l'application. Le serveur écoute sur `http://127.0.0.1:3000`. L'émulateur Android atteint ce poste à l'adresse `10.0.2.2:3000`, qui correspond déjà à `ApiService.baseUrl`.

**Mise à jour automatique** : `npm run dev` lance le même serveur, mais le relance seul à chaque modification de ses fichiers, y compris `.env`. Après avoir collé la clé dans `.env` et enregistré, attendez la ligne `Restarting 'index.js'` : aucun Ctrl+C n'est nécessaire.

Vérification : ouvrez `http://127.0.0.1:3000/api/transport/sante` dans un navigateur. Une réponse `{"statut":"ok",...}` confirme que le serveur tourne.

Pour un téléphone réel sur le même Wi-Fi :

```powershell
$env:HOST = "0.0.0.0"
node index.js
```

Il faut alors changer `ApiService.baseUrl` dans l'application pour l'adresse IP locale du PC (par exemple `http://192.168.1.10:3000/api`). Le serveur n'a pas d'authentification : ne l'exposez pas sur un réseau que vous ne contrôlez pas.

## Dépannage de l'itinéraire

Le message affiché dans l'application indique la cause :

- **« Serveur injoignable »** : le serveur n'est pas lancé. Lancez `node index.js` dans le dossier `server`, puis ouvrez `http://127.0.0.1:3000/api/transport/sante`.
- **« Itinéraire introuvable sur le serveur »** : une ancienne version du serveur répond encore sur le port 3000. Fermez son ancienne fenêtre (Ctrl+C), puis relancez `node index.js`.
- **« Le port 3000 est déjà utilisé »** (dans le terminal) : une autre fenêtre du serveur est ouverte. Fermez-la. Pour voir quel programme utilise le port : `netstat -ano`, puis cherchez `:3000` dans la liste.
- **« ville inconnue (...) »** : sans clé OpenRouteService, seules les villes de la liste intégrée sont reconnues. Ajoutez la clé, ou choisissez une ville de la liste.
- **« Service d'itinéraire indisponible : distance et durée estimées »** : OpenRouteService a refusé la demande ou ne répond pas. La cause est écrite dans la fenêtre du serveur, par exemple `a refusé la requête (HTTP 403) : vérifiez la clé`. Vérifiez la clé, ou régénérez-la si elle a été partagée.

Sans `npm run dev`, le serveur ne relit pas le code ni `.env` : arrêtez-le (Ctrl+C), puis relancez-le.

## Tests

```powershell
cd C:\Users\ABIR\Downloads\projet-mobile-gestion-voyage\server
npm test
```

L'itinéraire est testé avec un faux `fetch` : aucun appel à OpenRouteService, et aucune clé n'est nécessaire.

## Variables d'environnement

| Variable | Obligatoire | Défaut | Rôle |
|---|---|---|---|
| `OPENROUTESERVICE_API_KEY` | non | — | Clé gratuite OpenRouteService : itinéraires routiers réels. Sans elle, distance estimée |
| `OPENROUTESERVICE_URL` | non | `https://api.openrouteservice.org` | Base de l'API OpenRouteService, à changer si le service migre |
| `PORT` | non | `3000` | Port d'écoute |
| `HOST` | non | `127.0.0.1` | Interface d'écoute (`0.0.0.0` pour un téléphone réel) |
