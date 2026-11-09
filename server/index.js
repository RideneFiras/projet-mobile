/**
 * Serveur applicatif des fonctions IA du module transporteur.
 *
 * Routes (préfixe /api, comme ApiService.baseUrl de l'application) :
 *   POST /api/transport/interpreter-commande
 *   POST /api/transport/classer-voyageurs
 *   POST /api/transport/resumer-trajet
 *
 * Variables d'environnement :
 *   ANTHROPIC_API_KEY  obligatoire pour appeler le modèle (sinon 503, l'application
 *                      bascule sur ses réponses locales)
 *   PORT               défaut 3000
 *   HOST               défaut 127.0.0.1 (émulateur Android : 10.0.2.2 atteint ce poste).
 *                      Mettre 0.0.0.0 seulement pour un téléphone réel sur le même réseau.
 *   ANTHROPIC_BASE_URL facultatif, pour tester contre un faux service
 */
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { cleApi, ErreurUpstream } from './anthropic.js';
import {
  classerVoyageurs,
  ErreurSortie,
  ErreurValidation,
  interpreterCommande,
  resumerTrajet,
} from './transport_ai.js';

const LIMITE_CORPS = 32 * 1024;

const ROUTES = new Map([
  ['/api/transport/interpreter-commande', interpreterCommande],
  ['/api/transport/classer-voyageurs', classerVoyageurs],
  ['/api/transport/resumer-trajet', resumerTrajet],
]);

class ErreurHttp extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function lireCorps(req) {
  return new Promise((resoudre, rejeter) => {
    const morceaux = [];
    let taille = 0;
    let depasse = false;
    req.on('data', (c) => {
      taille += c.length;
      if (taille > LIMITE_CORPS) {
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
    const action = ROUTES.get(chemin);
    if (!action) return { code: 404, corps: { erreur: 'Route inconnue' } };
    if (req.method !== 'POST') {
      return { code: 405, corps: { erreur: 'Méthode non autorisée' }, entetes: { Allow: 'POST' } };
    }
    const corps = await lireCorps(req);
    if (!options.cle) {
      return { code: 503, corps: { erreur: 'Assistant IA non configuré (ANTHROPIC_API_KEY absente)' } };
    }
    return { code: 200, corps: await action(corps, options) };
  } catch (e) {
    if (e instanceof ErreurHttp) return { code: e.code, corps: { erreur: e.message } };
    if (e instanceof ErreurValidation) return { code: 400, corps: { erreur: e.message } };
    if (e instanceof ErreurSortie || e instanceof ErreurUpstream) {
      // Le message ne contient ni clé ni texte du modèle : seulement le motif.
      console.error(`[assistant] ${e.message}`);
      return { code: 502, corps: { erreur: 'Réponse de l’assistant indisponible ou invalide' } };
    }
    console.error('[assistant] erreur inattendue :', e?.message ?? e);
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
 * @param {{cle?: string|null, base?: string, fetchImpl?: typeof fetch}} [opts]
 */
export function creerServeur({ cle = cleApi(), base, fetchImpl } = {}) {
  const options = { cle, base, fetchImpl };
  return http.createServer(async (req, res) => {
    const debut = Date.now();
    const chemin = new URL(req.url ?? '/', 'http://localhost').pathname;
    const { code, corps, entetes } = await reponsePour(req, chemin, options);
    envoyer(res, code, corps, entetes);
    console.log(`${req.method} ${chemin} -> ${code} (${Date.now() - debut} ms)`);
  });
}

// Démarrage uniquement si ce fichier est lancé directement (node index.js).
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const port = Number(process.env.PORT ?? 3000);
  const hote = process.env.HOST ?? '127.0.0.1';
  if (!cleApi()) {
    console.warn(
      'ANTHROPIC_API_KEY absente : les routes répondront 503 et l’application utilisera ses réponses locales.',
    );
  }
  creerServeur().listen(port, hote, () => {
    console.log(`Assistant transport prêt sur http://${hote}:${port}/api/transport`);
  });
}
