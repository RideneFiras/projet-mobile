/**
 * Serveur applicatif du module transporteur : itinéraire d'un trajet.
 *
 * Routes (préfixe /api, comme ApiService.baseUrl de l'application) :
 *   POST /api/transport/itineraire   itinéraire routier : OpenRouteService si clé, sinon estimation
 *   GET  /api/transport/sante        état du serveur, sans afficher de secret
 *
 * Variables d'environnement :
 *   OPENROUTESERVICE_API_KEY  facultative : itinéraires réels. Sans elle, estimation.
 *   OPENROUTESERVICE_URL      facultative : base de l'API OpenRouteService (migration du service)
 *   PORT                      défaut 3000
 *   HOST                      défaut 127.0.0.1 (émulateur Android : 10.0.2.2 atteint ce poste).
 *                             Mettre 0.0.0.0 seulement pour un téléphone réel sur le même réseau.
 */
import http from 'node:http';
import { dirname, join, resolve } from 'node:path';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  CacheTemporaire,
  ErreurServiceExterne,
  ErreurValidation,
  itineraire,
  orsCleApi,
  orsUrlApi,
} from './itineraire.js';
import { traiterActualites } from './actualite_api.js';

const LIMITE_CORPS = 32 * 1024;
/** Les posts photo (base64) des actualités ont besoin d'un corps plus grand. */
const LIMITE_CORPS_PHOTO = 2 * 1024 * 1024;

const ROUTES = new Map([
  ['/api/transport/itineraire', itineraire],
]);

class ErreurHttp extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function lireCorps(req, limite = LIMITE_CORPS) {
  return new Promise((resoudre, rejeter) => {
    const morceaux = [];
    let taille = 0;
    let depasse = false;
    req.on('data', (c) => {
      taille += c.length;
      if (taille > limite) {
        depasse = true;
        return;
      }
      morceaux.push(c);
    });
    req.on('end', () => {
      if (depasse) return rejeter(new ErreurHttp(413, 'corps trop volumineux'));
      try {
        resoudre(JSON.parse(Buffer.concat(morceaux).toString('utf8') || '{}'));
      } catch {
        rejeter(new ErreurHttp(400, 'JSON invalide'));
      }
    });
    req.on('error', rejeter);
  });
}

async function reponsePour(req, chemin, options) {
  try {
    // API des actualités (module user) : toutes les méthodes HTTP, pas seulement POST.
    if (chemin === '/api/actualites' || chemin.startsWith('/api/actualites/')) {
      const url = new URL(req.url ?? '/', 'http://localhost');
      const corps = req.method === 'POST' || req.method === 'PUT'
        ? await lireCorps(req, LIMITE_CORPS_PHOTO)
        : {};
      return await traiterActualites({
        methode: req.method,
        chemin,
        requete: url.searchParams,
        corps,
        options,
      });
    }
    if (chemin === '/api/transport/sante') {
      if (req.method !== 'GET') {
        return { code: 405, corps: { erreur: 'Méthode non autorisée' }, entetes: { Allow: 'GET' } };
      }
      return {
        code: 200,
        corps: { statut: 'ok', openrouteservice: Boolean(options.orsCle) },
      };
    }
    const action = ROUTES.get(chemin);
    if (!action) return { code: 404, corps: { erreur: 'Route inconnue' } };
    if (req.method !== 'POST') {
      return { code: 405, corps: { erreur: 'Méthode non autorisée' }, entetes: { Allow: 'POST' } };
    }
    const corps = await lireCorps(req);
    return { code: 200, corps: await action(corps, options) };
  } catch (e) {
    if (e instanceof ErreurHttp) return { code: e.code, corps: { erreur: e.message } };
    if (e instanceof ErreurValidation) return { code: 400, corps: { erreur: e.message } };
    if (e?.name === 'ErreurValidation') return { code: 400, corps: { erreur: e.message } };
    if (e instanceof ErreurServiceExterne) {
      // Détail gardé dans le journal du serveur ; l'application reçoit un message neutre.
      console.error(`[externe] ${e.message}`);
      return {
        code: 503,
        corps: { erreur: 'Service externe indisponible pour le moment. Réessayez dans un instant.' },
      };
    }
    console.error('[serveur] erreur inattendue :', e?.message ?? e);
    return { code: 500, corps: { erreur: 'Erreur interne' } };
  }
}

function envoyer(res, code, corps, entetes = {}) {
  const texte = JSON.stringify(corps);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(texte),
    ...entetes,
  });
  res.end(texte);
}

/**
 * Crée le serveur HTTP. Les options servent aux tests : clé, URL de base, fetch.
 * @param {{fetchImpl?: typeof fetch, orsCle?: string|null, orsBase?: string, cache?: CacheTemporaire}} [opts]
 */
export function creerServeur({
  fetchImpl,
  orsCle = orsCleApi(),
  orsBase = orsUrlApi(),
  cache = new CacheTemporaire(),
  cle = null,
  base,
  magasin,
} = {}) {
  const options = { fetchImpl, orsCle, orsBase, cache, cle, base, magasin };
  return http.createServer(async (req, res) => {
    const debut = Date.now();
    const chemin = new URL(req.url ?? '/', 'http://localhost').pathname;
    const { code, corps, entetes } = await reponsePour(req, chemin, options);
    envoyer(res, code, corps, entetes);
    console.log(`${req.method} ${chemin} -> ${code} (${Date.now() - debut} ms)`);
  });
}

// Démarrage seulement si ce fichier est le point d'entrée : `node index.js`, `npm start`
// ou `node .` dans le dossier server. Importé par les tests, il ne lance rien.
const fichierCourant = fileURLToPath(import.meta.url);
const entree = process.argv[1] ? resolve(process.argv[1]) : '';
if (entree === fichierCourant || entree === dirname(fichierCourant)) {
  demarrer();
}

/**
 * Lit un fichier KEY=valeur (server/.env). Une variable déjà définie dans le shell
 * (par exemple $env:OPENROUTESERVICE_API_KEY) est prioritaire et n'est pas remplacée.
 */
function chargerFichierEnv(chemin, env = process.env) {
  if (!existsSync(chemin)) return;
  for (const ligne of readFileSync(chemin, 'utf8').split(/\r?\n/)) {
    const m = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(ligne);
    if (!m) continue;
    const valeur = m[2].replace(/^(["'])(.*)\1$/, '$2');
    if (env[m[1]] === undefined) env[m[1]] = valeur;
  }
}

function demarrer() {
  chargerFichierEnv(join(dirname(fichierCourant), '.env'));
  const port = Number(process.env.PORT ?? 3000);
  const hote = process.env.HOST ?? '127.0.0.1';
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error(`PORT invalide : « ${process.env.PORT} ». Indiquez un nombre entre 1 et 65535.`);
    process.exit(1);
  }
  if (orsCleApi()) {
    console.log(`OpenRouteService : ${orsUrlApi()}`);
  } else {
    console.warn('OPENROUTESERVICE_API_KEY absente : itinéraires estimés à partir des coordonnées.');
  }
  const serveur = creerServeur();
  serveur.on('error', (e) => {
    if (e.code === 'EADDRINUSE') {
      console.error(
        `Le port ${port} est déjà utilisé : une ancienne fenêtre du serveur est encore ouverte.\n` +
          `Fermez-la (Ctrl+C), puis relancez « node index.js ».\n` +
          `Pour voir quel programme utilise le port (PowerShell) : netstat -ano | findstr :${port}`,
      );
    } else {
      console.error(`Démarrage impossible : ${e.message}`);
    }
    process.exit(1);
  });
  serveur.listen(port, hote, () => {
    console.log(`Serveur transport prêt sur http://${hote}:${port}/api/transport`);
  });
}
