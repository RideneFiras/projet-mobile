/**
 * Itinéraire routier du module transporteur.
 *
 *   POST /api/transport/itineraire  { depart, arrivee }  -> distance, durée, itinéraires
 *
 * Itinéraire : OpenRouteService si OPENROUTESERVICE_API_KEY est définie (clé gratuite).
 * Sans clé, ou si le service ne répond pas, l'application reçoit une estimation calculée
 * à partir des coordonnées des villes, signalée comme telle (source "estimation").
 *
 * Les villes connues sont dans VILLES. Une autre ville n'est acceptée que si
 * OpenRouteService peut la géocoder. Un service externe en panne donne une
 * ErreurServiceExterne (le serveur répond 503), jamais un détail technique.
 *
 * Cache : fourni par le serveur (CacheTemporaire) pour économiser le quota gratuit.
 * Sans cache, chaque appel interroge le service.
 */
/** Entrée invalide : réponse HTTP 400, message destiné à l'application. */
export class ErreurValidation extends Error {}

const URL_ORS_DEFAUT = 'https://api.openrouteservice.org';
const DELAI_MS = 15_000;
const FACTEUR_ROUTE = 1.25; // distance routière / distance à vol d'oiseau (estimation)
const VITESSE_MOYENNE_KMH = 70; // vitesse moyenne retenue pour l'estimation
const TTL_GEOCODAGE_MS = 24 * 3600_000;
const TTL_ITINERAIRE_MS = 6 * 3600_000;
const POINTS_TRACE_MAX = 150; // nombre maximal de points renvoyés pour dessiner le tracé
/** Codes HTTP pour lesquels une nouvelle demande sans options peut réussir (forme refusée). */
const CODES_RELANCE = [400, 404, 422];

/** Coordonnées approximatives des villes courantes (clé : nom normalisé, sans accent). */
export const VILLES = {
  tunis: { nom: 'Tunis', lat: 36.8065, lon: 10.1815 },
  ariana: { nom: 'Ariana', lat: 36.8625, lon: 10.1956 },
  'ben arous': { nom: 'Ben Arous', lat: 36.7531, lon: 10.2189 },
  manouba: { nom: 'Manouba', lat: 36.8089, lon: 10.0972 },
  bizerte: { nom: 'Bizerte', lat: 37.2744, lon: 9.8739 },
  beja: { nom: 'Béja', lat: 36.7256, lon: 9.1817 },
  jendouba: { nom: 'Jendouba', lat: 36.5011, lon: 8.7802 },
  kef: { nom: 'Le Kef', lat: 36.1675, lon: 8.7049 },
  siliana: { nom: 'Siliana', lat: 36.0844, lon: 9.3708 },
  nabeul: { nom: 'Nabeul', lat: 36.4513, lon: 10.7353 },
  zaghouan: { nom: 'Zaghouan', lat: 36.4029, lon: 10.1429 },
  sousse: { nom: 'Sousse', lat: 35.8256, lon: 10.6369 },
  monastir: { nom: 'Monastir', lat: 35.7643, lon: 10.8113 },
  mahdia: { nom: 'Mahdia', lat: 35.5047, lon: 11.0622 },
  kairouan: { nom: 'Kairouan', lat: 35.6781, lon: 10.0963 },
  kasserine: { nom: 'Kasserine', lat: 35.1676, lon: 8.8365 },
  'sidi bouzid': { nom: 'Sidi Bouzid', lat: 35.0382, lon: 9.4849 },
  sfax: { nom: 'Sfax', lat: 34.7406, lon: 10.7603 },
  gafsa: { nom: 'Gafsa', lat: 34.425, lon: 8.7842 },
  tozeur: { nom: 'Tozeur', lat: 33.9197, lon: 8.1335 },
  kebili: { nom: 'Kébili', lat: 33.705, lon: 8.969 },
  gabes: { nom: 'Gabès', lat: 33.8815, lon: 10.0982 },
  medenine: { nom: 'Médenine', lat: 33.3549, lon: 10.5055 },
  mednine: { nom: 'Médenine', lat: 33.3549, lon: 10.5055 }, // orthographe sans accent
  tataouine: { nom: 'Tataouine', lat: 32.9297, lon: 10.4518 },
  djerba: { nom: 'Djerba (Houmt Souk)', lat: 33.8756, lon: 10.8575 },
};

/** Service externe en échec : réseau, délai, réponse HTTP d'erreur ou réponse inattendue. */
export class ErreurServiceExterne extends Error {
  constructor(message, statut = null) {
    super(message);
    this.name = 'ErreurServiceExterne';
    this.statut = statut;
  }
}

/** Cache en mémoire à durée limitée. Les entrées expirées sont retirées à la lecture. */
export class CacheTemporaire {
  constructor(max = 500) {
    this.max = max;
    this.entrees = new Map();
  }

  lire(cle) {
    const entree = this.entrees.get(cle);
    if (!entree) return undefined;
    if (Date.now() > entree.expire) {
      this.entrees.delete(cle);
      return undefined;
    }
    return entree.valeur;
  }

  ecrire(cle, valeur, ttlMs) {
    if (this.entrees.size >= this.max && !this.entrees.has(cle)) {
      this.entrees.delete(this.entrees.keys().next().value);
    }
    this.entrees.set(cle, { valeur, expire: Date.now() + ttlMs });
  }
}

/** Clé lue dans l'environnement, ou null si elle est absente. */
export function orsCleApi(env = process.env) {
  const cle = (env.OPENROUTESERVICE_API_KEY ?? '').trim();
  return cle === '' ? null : cle;
}

/** URL de base d'OpenRouteService. OPENROUTESERVICE_URL permet de suivre une migration du service. */
export function orsUrlApi(env = process.env) {
  const url = (env.OPENROUTESERVICE_URL ?? '').trim().replace(/\/+$/, '');
  return url === '' ? URL_ORS_DEFAUT : url;
}

function normaliser(texte) {
  return texte
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function villeConnue(nom) {
  const cle = normaliser(nom).replace(/^(le|la|les) /, '');
  return VILLES[cle] ?? null;
}

function arrondi(n) {
  return Math.round(n * 10) / 10;
}

function chaineRequise(v, champ) {
  if (typeof v !== 'string' || v.trim() === '' || v.trim().length > 80) {
    throw new ErreurValidation(`${champ} : texte requis (80 caractères au maximum)`);
  }
  return v.trim();
}

function objetRequis(corps) {
  if (corps === null || typeof corps !== 'object' || Array.isArray(corps)) {
    throw new ErreurValidation('corps JSON attendu (objet)');
  }
  return corps;
}

function distanceVolOiseauKm(a, b) {
  const rayon = 6371;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLon = rad(b.lon - a.lon);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * rayon * Math.asin(Math.sqrt(h));
}

/** Options communes : valeurs par défaut pour les services externes. */
function contexte(options) {
  return {
    orsCle: options.orsCle ?? null,
    orsBase: options.orsBase ?? URL_ORS_DEFAUT,
    fetchImpl: options.fetchImpl ?? fetch,
    cache: options.cache ?? null,
  };
}

/** Renvoie la valeur gardée en cache, sinon la calcule et la garde. Sans cache : calcul direct. */
async function avecCache(cache, cle, ttlMs, produire) {
  if (!cache) return produire();
  const dejaLa = cache.lire(cle);
  if (dejaLa !== undefined) return dejaLa;
  const valeur = await produire();
  cache.ecrire(cle, valeur, ttlMs);
  return valeur;
}

/** Appel HTTP en JSON. Le détail de l'erreur externe n'est jamais transmis à l'application. */
async function appelJson(url, { methode = 'GET', entetes = {}, corps } = {}, fetchImpl = fetch) {
  let reponse;
  try {
    reponse = await fetchImpl(url, {
      method: methode,
      headers: {
        Accept: 'application/json',
        ...(corps === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...entetes,
      },
      body: corps === undefined ? undefined : JSON.stringify(corps),
      signal: AbortSignal.timeout(DELAI_MS),
    });
  } catch {
    throw new ErreurServiceExterne('service externe injoignable (réseau ou délai dépassé)');
  }
  if (!reponse.ok) {
    if (reponse.status === 401 || reponse.status === 403) {
      console.error(
        `[externe] ${new URL(url).host} a refusé la requête (HTTP ${reponse.status}) : vérifiez la clé.`,
      );
    }
    throw new ErreurServiceExterne(`service externe a répondu ${reponse.status}`, reponse.status);
  }
  try {
    return await reponse.json();
  } catch {
    throw new ErreurServiceExterne('réponse du service externe non JSON');
  }
}

/** Trouve les coordonnées d'une ville : liste connue d'abord, puis géocodage OpenRouteService. */
async function localiser(nom, champ, ctx) {
  const connue = villeConnue(nom);
  if (connue) return connue;
  if (!ctx.orsCle) {
    throw new ErreurValidation(`${champ} : ville inconnue (${nom})`);
  }
  const geo = await avecCache(ctx.cache, `geo|${normaliser(nom)}`, TTL_GEOCODAGE_MS, async () => {
    const url =
      `${ctx.orsBase}/geocode/search?text=${encodeURIComponent(nom)}` +
      '&boundary.country=TN&size=1';
    const rep = await appelJson(url, { entetes: { Authorization: ctx.orsCle } }, ctx.fetchImpl);
    const coords = rep?.features?.[0]?.geometry?.coordinates;
    if (!Array.isArray(coords) || coords.length < 2) {
      throw new ErreurValidation(`${champ} : ville inconnue (${nom})`);
    }
    return { lat: Number(coords[1]), lon: Number(coords[0]) };
  });
  return { nom, ...geo };
}

/**
 * Décode une polyligne encodée (format Google, utilisé par OpenRouteService).
 * Renvoie une liste de couples [latitude, longitude].
 */
export function decoderPolyligne(texte, precision = 5) {
  const facteur = 10 ** precision;
  const points = [];
  let index = 0;
  let lat = 0;
  let lon = 0;

  // Chaque caractère porte 5 bits ; le sixième bit indique qu'un autre caractère suit.
  const lireNombre = () => {
    let resultat = 0;
    let decalage = 0;
    let octet;
    do {
      if (index >= texte.length) throw new Error('polyligne tronquée');
      octet = texte.charCodeAt(index++) - 63;
      resultat |= (octet & 0x1f) << decalage;
      decalage += 5;
    } while (octet >= 0x20);
    return resultat & 1 ? ~(resultat >> 1) : resultat >> 1;
  };

  while (index < texte.length) {
    lat += lireNombre();
    lon += lireNombre();
    points.push([lat / facteur, lon / facteur]);
  }
  return points;
}

/** Réduit une trace à au plus `max` points, en gardant toujours le dernier. */
export function simplifierTrace(points, max = POINTS_TRACE_MAX) {
  if (points.length <= max) return points;
  const pas = Math.ceil((points.length - 1) / (max - 1));
  const reduit = [];
  for (let i = 0; i < points.length - 1; i += pas) reduit.push(points[i]);
  reduit.push(points[points.length - 1]);
  return reduit;
}

/** Trace d'une route ORS, décodée et réduite. Vide si la géométrie est absente ou illisible. */
export function tracePourRoute(route) {
  if (typeof route?.geometry !== 'string') return [];
  try {
    return simplifierTrace(decoderPolyligne(route.geometry));
  } catch {
    return [];
  }
}

/** Ne garde que la distance et la durée, pour les routes alternatives. */
const sansTrace = ({ distance_km, duree_min }) => ({ distance_km, duree_min });

function estimation(a, b) {
  const routeKm = distanceVolOiseauKm(a, b) * FACTEUR_ROUTE;
  return {
    distance_km: arrondi(routeKm),
    duree_min: Math.round((routeKm / VITESSE_MOYENNE_KMH) * 60),
    trace: [
      [a.lat, a.lon],
      [b.lat, b.lon],
    ],
  };
}

/** Itinéraires renvoyés par OpenRouteService, du plus rapide au plus lent. */
async function itinerairesOrs(a, b, ctx) {
  const cle = `dir|${a.lat.toFixed(4)},${a.lon.toFixed(4)}|${b.lat.toFixed(4)},${b.lon.toFixed(4)}`;
  return avecCache(ctx.cache, cle, TTL_ITINERAIRE_MS, async () => {
    const url = `${ctx.orsBase}/v2/directions/driving-car`;
    const coordonnees = [
      [a.lon, a.lat],
      [b.lon, b.lat],
    ];
    const demande = (corps) =>
      appelJson(url, { methode: 'POST', entetes: { Authorization: ctx.orsCle }, corps }, ctx.fetchImpl);
    let rep;
    try {
      // Routes alternatives d'abord. ORS peut les refuser sur les longs trajets.
      rep = await demande({
        coordinates: coordonnees,
        alternative_routes: { target_count: 2, share_factor: 0.6, weight_factor: 1.4 },
      });
    } catch (e) {
      // Relance sans alternatives seulement si le service a refusé la forme de la demande.
      // Une erreur 500, un quota dépassé ou une clé refusée ne justifient pas une seconde demande.
      if (!(e instanceof ErreurServiceExterne) || !CODES_RELANCE.includes(e.statut)) throw e;
      rep = await demande({ coordinates: coordonnees });
    }
    const routes = Array.isArray(rep?.routes) ? rep.routes : [];
    const itineraires = routes
      .map((r) => ({
        distance_km: arrondi(Number(r?.summary?.distance) / 1000),
        duree_min: Math.round(Number(r?.summary?.duration) / 60),
        trace: tracePourRoute(r),
      }))
      .filter((r) => Number.isFinite(r.distance_km) && Number.isFinite(r.duree_min) && r.distance_km > 0);
    if (itineraires.length === 0) {
      throw new ErreurServiceExterne('itinéraire absent de la réponse OpenRouteService');
    }
    return itineraires.sort((x, y) => x.duree_min - y.duree_min);
  });
}

/**
 * @param {object} corps     { depart, arrivee }
 * @param {object} options   { orsCle?, orsBase?, fetchImpl?, cache? }
 */
export async function itineraire(corps, options = {}) {
  objetRequis(corps);
  const departNom = chaineRequise(corps.depart, 'depart');
  const arriveeNom = chaineRequise(corps.arrivee, 'arrivee');
  const ctx = contexte(options);

  const depart = await localiser(departNom, 'depart', ctx);
  const arrivee = await localiser(arriveeNom, 'arrivee', ctx);

  const base = {
    depart: depart.nom,
    arrivee: arrivee.nom,
    points: {
      depart: [depart.lat, depart.lon],
      arrivee: [arrivee.lat, arrivee.lon],
    },
  };

  if (!ctx.orsCle) {
    return {
      ...base,
      source: 'estimation',
      recommande: estimation(depart, arrivee),
      alternatives: [],
      avertissement:
        'OPENROUTESERVICE_API_KEY absente : distance et durée estimées à partir des coordonnées.',
    };
  }

  try {
    const [recommande, ...alternatives] = await itinerairesOrs(depart, arrivee, ctx);
    return {
      ...base,
      source: 'openrouteservice',
      recommande,
      alternatives: alternatives.map(sansTrace),
      avertissement: null,
    };
  } catch (e) {
    if (!(e instanceof ErreurServiceExterne)) throw e;
    console.error(`[itineraire] ${e.message}`);
    return {
      ...base,
      source: 'estimation',
      recommande: estimation(depart, arrivee),
      alternatives: [],
      avertissement:
        'Service d’itinéraire indisponible : distance et durée estimées. '
        + 'Vérifiez la clé OpenRouteService dans la fenêtre du serveur.',
    };
  }
}
