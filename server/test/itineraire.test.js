import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  CacheTemporaire,
  ErreurServiceExterne,
  itineraire,
  orsUrlApi,
  ErreurValidation,
} from '../itineraire.js';
import { creerServeur } from '../index.js';

/** Faux fetch : enregistre les appels et répond avec la fonction donnée. */
function fauxFetch(repondre) {
  const appels = [];
  const fetchImpl = async (url, init = {}) => {
    appels.push({ url: String(url), init });
    const { status = 200, corps } = repondre(String(url), init);
    return { ok: status >= 200 && status < 300, status, json: async () => corps };
  };
  return { fetchImpl, appels };
}

describe('itinéraire : estimation sans clé OpenRouteService', () => {
  it('estime distance et durée entre deux villes connues, sans aucun appel réseau', async () => {
    const { fetchImpl, appels } = fauxFetch(() => {
      throw new Error('aucun appel attendu');
    });
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, { orsCle: null, fetchImpl });
    assert.equal(r.source, 'estimation');
    assert.ok(r.recommande.distance_km > 250 && r.recommande.distance_km < 400, `distance ${r.recommande.distance_km}`);
    assert.ok(r.recommande.duree_min > 180 && r.recommande.duree_min < 400, `durée ${r.recommande.duree_min}`);
    assert.deepEqual(r.alternatives, []);
    assert.match(r.avertissement, /OPENROUTESERVICE_API_KEY absente/);
    assert.equal(appels.length, 0);
  });

  it('accepte les variantes de nom (accents, casse, article « Le »)', async () => {
    const r = await itineraire({ depart: '  TUNIS ', arrivee: 'le kef' }, { orsCle: null });
    assert.equal(r.arrivee, 'Le Kef');
  });

  it('refuse une ville inconnue quand aucune clé ne permet de la géocoder', async () => {
    await assert.rejects(
      () => itineraire({ depart: 'Tunis', arrivee: 'Hammamet' }, { orsCle: null }),
      (e) => e instanceof ErreurValidation && /ville inconnue/.test(e.message),
    );
  });
});

describe('itinéraire : OpenRouteService', () => {
  it('appelle directions/driving-car, classe les routes par durée et renvoie la plus rapide', async () => {
    const { fetchImpl, appels } = fauxFetch(() => ({
      corps: {
        routes: [
          { summary: { distance: 340_000, duration: 14_400 } },
          { summary: { distance: 360_000, duration: 13_200 } },
        ],
      },
    }));
    const r = await itineraire(
      { depart: 'Tunis', arrivee: 'Sfax' },
      { orsCle: 'cle-test', fetchImpl },
    );
    assert.equal(r.source, 'openrouteservice');
    assert.deepEqual(r.recommande, { distance_km: 360, duree_min: 220, trace: [] });
    assert.deepEqual(r.alternatives, [{ distance_km: 340, duree_min: 240 }]);
    assert.equal(r.avertissement, null);

    assert.equal(appels.length, 1);
    assert.equal(appels[0].url, 'https://api.openrouteservice.org/v2/directions/driving-car');
    assert.equal(appels[0].init.method, 'POST');
    assert.equal(appels[0].init.headers.Authorization, 'cle-test');
    const corps = JSON.parse(appels[0].init.body);
    // ORS attend [longitude, latitude].
    assert.deepEqual(corps.coordinates, [
      [10.1815, 36.8065],
      [10.7603, 34.7406],
    ]);
  });

  it('bascule sur une estimation si le service répond en erreur', async () => {
    const { fetchImpl } = fauxFetch(() => ({ status: 500 }));
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sousse' }, { orsCle: 'cle-test', fetchImpl });
    assert.equal(r.source, 'estimation');
    assert.match(r.avertissement, /indisponible/);
    assert.ok(r.recommande.distance_km > 0);
  });

  it('redemande sans routes alternatives si le service refuse la demande', async () => {
    const { fetchImpl, appels } = fauxFetch((url, init) => {
      const corps = JSON.parse(init.body);
      if (corps.alternative_routes) return { status: 400 };
      return { corps: { routes: [{ summary: { distance: 269_000, duration: 10_700 } }] } };
    });
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, { orsCle: 'cle-test', fetchImpl });
    assert.equal(r.source, 'openrouteservice');
    assert.deepEqual(r.recommande, { distance_km: 269, duree_min: 178, trace: [] });
    assert.deepEqual(r.alternatives, []);
    assert.equal(appels.length, 2);
    assert.equal(JSON.parse(appels[1].init.body).alternative_routes, undefined);
  });

  it('géocode une ville hors liste avant de calculer le trajet', async () => {
    const { fetchImpl, appels } = fauxFetch((url) =>
      url.includes('/geocode/search')
        ? { corps: { features: [{ geometry: { coordinates: [10.6167, 36.4] } }] } }
        : { corps: { routes: [{ summary: { distance: 90_000, duration: 4_500 } }] } },
    );
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Hammamet' }, { orsCle: 'cle-test', fetchImpl });
    assert.equal(r.arrivee, 'Hammamet');
    assert.equal(r.source, 'openrouteservice');
    assert.match(appels[0].url, /geocode\/search\?text=Hammamet&boundary\.country=TN/);
  });
});

describe('routes HTTP', () => {
  it('répond à itinéraire, et refuse les méthodes autres que POST', async () => {
    const { fetchImpl } = fauxFetch(() => ({ corps: {} }));
    const serveur = creerServeur({ orsCle: null, fetchImpl });
    await new Promise((r) => serveur.listen(0, '127.0.0.1', r));
    const base = `http://127.0.0.1:${serveur.address().port}/api/transport`;
    try {
      const ok = await fetch(`${base}/itineraire`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ depart: 'Tunis', arrivee: 'Sousse' }),
      });
      assert.equal(ok.status, 200);
      const corps = await ok.json();
      assert.equal(corps.source, 'estimation');

      const mauvaise = await fetch(`${base}/itineraire`, { method: 'GET' });
      assert.equal(mauvaise.status, 405);

      // L'ancienne route IA n'existe plus.
      const retiree = await fetch(`${base}/resumer-trajet`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{}',
      });
      assert.equal(retiree.status, 404);
    } finally {
      await new Promise((r) => serveur.close(r));
    }
  });
});

describe('services externes : erreurs, cache et relance', () => {
  const routeRapide = () => ({
    corps: { routes: [{ summary: { distance: 340_000, duration: 14_400 } }] },
  });

  it('met le trajet en cache : une seule requête pour deux demandes identiques', async () => {
    const cache = new CacheTemporaire();
    const { fetchImpl, appels } = fauxFetch(routeRapide);
    const options = { orsCle: 'cle-test', fetchImpl, cache };
    const premiere = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, options);
    const seconde = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, options);
    assert.equal(appels.length, 1);
    assert.deepEqual(premiere.recommande, seconde.recommande);
  });

  it('ne relance pas après une erreur 500 : un seul appel, puis estimation', async () => {
    const { fetchImpl, appels } = fauxFetch(() => ({ status: 500 }));
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, { orsCle: 'cle-test', fetchImpl });
    assert.equal(appels.length, 1);
    assert.equal(r.source, 'estimation');
  });

  it('ne relance pas non plus quand la clé est refusée (401)', async () => {
    const { fetchImpl, appels } = fauxFetch(() => ({ status: 401 }));
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, { orsCle: 'mauvaise', fetchImpl });
    assert.equal(appels.length, 1);
    assert.equal(r.source, 'estimation');
  });

  it('un géocodage en échec signale un service indisponible, pas une ville inconnue', async () => {
    const { fetchImpl } = fauxFetch(() => ({ status: 503 }));
    await assert.rejects(
      () => itineraire({ depart: 'Tunis', arrivee: 'Hammamet' }, { orsCle: 'cle-test', fetchImpl }),
      (e) => e instanceof ErreurServiceExterne && e.statut === 503,
    );
  });

  it('interroge la base OpenRouteService configurée', async () => {
    const { fetchImpl, appels } = fauxFetch(routeRapide);
    await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, {
      orsCle: 'cle-test',
      orsBase: orsUrlApi({ OPENROUTESERVICE_URL: 'https://ors.exemple.test/' }),
      fetchImpl,
    });
    assert.ok(appels[0].url.startsWith('https://ors.exemple.test/v2/directions/driving-car'), appels[0].url);
  });

  it('orsUrlApi revient à l’adresse par défaut quand la variable est absente', () => {
    assert.equal(orsUrlApi({}), 'https://api.openrouteservice.org');
  });

  it('HTTP : une panne du service externe répond 503 avec un message neutre', async () => {
    const { fetchImpl } = fauxFetch(() => ({ status: 500 }));
    const serveur = creerServeur({ orsCle: 'cle-test', fetchImpl });
    await new Promise((r) => serveur.listen(0, '127.0.0.1', r));
    const base = `http://127.0.0.1:${serveur.address().port}/api/transport`;
    try {
      const rep = await fetch(`${base}/itineraire`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ depart: 'Tunis', arrivee: 'Hammamet' }),
      });
      assert.equal(rep.status, 503);
      const corps = await rep.json();
      assert.match(corps.erreur, /indisponible/);
      assert.doesNotMatch(corps.erreur, /500|openrouteservice|cle-test/i);
    } finally {
      await new Promise((r) => serveur.close(r));
    }
  });

  it('HTTP : la route de santé indique la configuration sans révéler de secret', async () => {
    const { fetchImpl } = fauxFetch(() => ({ corps: {} }));
    const serveur = creerServeur({ orsCle: 'cle-secrete-test', fetchImpl });
    await new Promise((r) => serveur.listen(0, '127.0.0.1', r));
    const base = `http://127.0.0.1:${serveur.address().port}/api/transport`;
    try {
      const rep = await fetch(`${base}/sante`);
      assert.equal(rep.status, 200);
      const texte = await rep.text();
      assert.doesNotMatch(texte, /cle-secrete-test/);
      assert.deepEqual(JSON.parse(texte), { statut: 'ok', openrouteservice: true });
      const mauvaise = await fetch(`${base}/sante`, { method: 'POST' });
      assert.equal(mauvaise.status, 405);
    } finally {
      await new Promise((r) => serveur.close(r));
    }
  });
});

describe('itinéraire : tracé de carte', () => {
  it('renvoie le tracé OpenRouteService et les points de départ et d’arrivée', async () => {
    const { fetchImpl } = fauxFetch(() => ({
      corps: {
        routes: [
          {
            summary: { distance: 300_000, duration: 14_000 },
            geometry: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
          },
        ],
      },
    }));
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, { orsCle: 'cle-test', fetchImpl });
    assert.equal(r.recommande.trace.length, 3);
    assert.deepEqual(r.recommande.trace[0], [38.5, -120.2]);
    assert.deepEqual(r.points, { depart: [36.8065, 10.1815], arrivee: [34.7406, 10.7603] });
  });

  it('trace une ligne droite entre les deux villes en mode estimation', async () => {
    const r = await itineraire({ depart: 'Tunis', arrivee: 'Sfax' }, { orsCle: null });
    assert.equal(r.source, 'estimation');
    assert.equal(r.recommande.trace.length, 2);
    assert.deepEqual(r.recommande.trace[0], r.points.depart);
    assert.deepEqual(r.recommande.trace[1], r.points.arrivee);
  });
});
