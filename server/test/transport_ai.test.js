/**
 * Tests du serveur IA transporteur, sans réseau réel : un faux service Anthropic
 * répond à la place de api.anthropic.com. Lancer avec : npm test
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { creerServeur } from '../index.js';
import { extraireJson } from '../transport_ai.js';

const CLE = 'cle-de-test';

let faux; // faux service Anthropic
let urlFaux;
let reponseFaux = { status: 200, corps: '' }; // ce que le faux service renvoie ensuite
let derniere; // dernière requête reçue par le faux service

let serveur;
let urlServeur;

function repondre(texte) {
  reponseFaux = {
    status: 200,
    corps: JSON.stringify({ content: [{ type: 'text', text: texte }] }),
  };
}

async function appeler(chemin, corps) {
  const r = await fetch(`${urlServeur}/api/transport${chemin}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(corps),
  });
  const texte = await r.text();
  return { code: r.status, texte, corps: texte ? JSON.parse(texte) : null };
}

function demarrer(serveurHttp) {
  return new Promise((resoudre) =>
    serveurHttp.listen(0, '127.0.0.1', () =>
      resoudre(`http://127.0.0.1:${serveurHttp.address().port}`),
    ),
  );
}

before(async () => {
  faux = http.createServer((req, res) => {
    let donnees = '';
    req.on('data', (c) => (donnees += c));
    req.on('end', () => {
      derniere = {
        url: req.url,
        entetes: req.headers,
        corps: JSON.parse(donnees),
      };
      res.writeHead(reponseFaux.status, { 'content-type': 'application/json' });
      res.end(reponseFaux.corps);
    });
  });
  urlFaux = await demarrer(faux);
  serveur = creerServeur({ cle: CLE, base: urlFaux });
  urlServeur = await demarrer(serveur);
});

after(() => {
  serveur.close();
  faux.close();
});

test('sans ANTHROPIC_API_KEY, les routes répondent 503 sans appeler le modèle', async () => {
  const sansCle = creerServeur({ cle: null, base: urlFaux });
  const url = await demarrer(sansCle);
  derniere = undefined;
  try {
    const r = await fetch(`${url}/api/transport/resumer-trajet`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{}',
    });
    assert.equal(r.status, 503);
    assert.equal(derniere, undefined);
  } finally {
    sansCle.close();
  }
});

test('interpréter : le JSON du modèle est validé, la date relative est résolue', async () => {
  repondre(
    '```json\n{"depart":"Tunis","arrivee":"Sfax","date":"2026-11-03","budget":50}\n```',
  );
  const r = await appeler('/interpreter-commande', {
    texte: 'De Tunis à Sfax demain, budget 50 DT',
    date_reference: '2026-11-02T09:00:00',
  });
  assert.equal(r.code, 200);
  assert.deepEqual(r.corps, {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    budget: 50,
  });
});

test('requête vers Anthropic : modèle, en-têtes, et aucun paramètre interdit', async () => {
  repondre('{"depart":"Tunis","arrivee":"Sfax","date":null,"budget":null}');
  derniere = undefined;
  await appeler('/interpreter-commande', {
    texte: 'Tunis vers Sfax',
    date_reference: '2026-11-02',
  });
  assert.equal(derniere.url, '/v1/messages');
  assert.equal(derniere.entetes['x-api-key'], CLE);
  assert.equal(derniere.entetes['anthropic-version'], '2023-06-01');
  assert.equal(derniere.corps.model, 'claude-haiku-5-5');
  assert.equal(derniere.corps.max_tokens, 300);
  for (const interdit of ['temperature', 'top_p', 'top_k']) {
    assert.equal(interdit in derniere.corps, false, `${interdit} ne doit pas être envoyé`);
  }
});

test('date impossible et budget négatif renvoyés par le modèle : ignorés', async () => {
  repondre('{"depart":"Tunis","arrivee":"Sfax","date":"2026-02-31","budget":"-4"}');
  const r = await appeler('/interpreter-commande', {
    texte: 'Tunis vers Sfax',
    date_reference: '2026-11-02',
  });
  assert.equal(r.code, 200);
  assert.deepEqual(r.corps, { depart: 'Tunis', arrivee: 'Sfax', date: null, budget: null });
});

test('réponse du modèle sans JSON : 502', async () => {
  repondre('Désolé, je ne peux pas traiter cette demande.');
  const r = await appeler('/interpreter-commande', {
    texte: 'quelque chose',
    date_reference: '2026-11-02',
  });
  assert.equal(r.code, 502);
});

test("erreur Anthropic : 502, et le corps d'erreur n'est pas transmis", async () => {
  reponseFaux = { status: 500, corps: 'détail interne confidentiel' };
  const r = await appeler('/resumer-trajet', {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    prix: 50,
    statut: 'confirmee',
    transporteur: 'Bus Express',
  });
  assert.equal(r.code, 502);
  assert.equal(r.texte.includes('confidentiel'), false);
});

test('classement : identifiants inconnus ignorés, score borné, tri décroissant', async () => {
  repondre(
    JSON.stringify([
      { voyageur_id: 1, score: 40, raison: 'Voyage à venir' },
      { voyageur_id: 99, score: 90, raison: 'Candidat inventé' },
      { voyageur_id: 2, score: 150, raison: 'Va à Sfax' },
    ]),
  );
  const r = await appeler('/classer-voyageurs', {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    candidats: [
      { id: 1, voyages: [] },
      { id: 2, voyages: [] },
      { id: 3, voyages: [] },
    ],
  });
  assert.equal(r.code, 200);
  assert.deepEqual(r.corps, [
    { voyageur_id: 2, score: 100, raison: 'Va à Sfax' },
    { voyageur_id: 1, score: 40, raison: 'Voyage à venir' },
    { voyageur_id: 3, score: 0, raison: "Non classé par l'assistant" },
  ]);
});

test('classement : noms et contacts des voyageurs non transmis au modèle', async () => {
  repondre('[{"voyageur_id": 1, "score": 10, "raison": "ok"}]');
  derniere = undefined;
  await appeler('/classer-voyageurs', {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    candidats: [
      {
        id: 1,
        nom: 'Ahmed Secret',
        contact: '22334455',
        voyages: [{ destination: 'Sfax', date_debut: '2026-11-03', date_fin: '2026-11-04' }],
      },
    ],
  });
  const envoye = JSON.stringify(derniere.corps);
  assert.equal(envoye.includes('Secret'), false);
  assert.equal(envoye.includes('22334455'), false);
});

test('classement sans candidat : tableau vide, aucun appel au modèle', async () => {
  derniere = undefined;
  const r = await appeler('/classer-voyageurs', {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    candidats: [],
  });
  assert.deepEqual(r.corps, []);
  assert.equal(derniere, undefined);
});

test('résumé : texte renvoyé, prix et statut transmis tels quels', async () => {
  repondre(
    '{"resume": "Trajet Tunis → Sfax le 3 novembre 2026, pour 50 DT. Confirmez l\'horaire auprès du transporteur."}',
  );
  derniere = undefined;
  const r = await appeler('/resumer-trajet', {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    prix: 50,
    statut: 'confirmee',
    transporteur: 'Bus Express',
  });
  assert.equal(r.code, 200);
  assert.match(r.corps.resume, /Tunis/);
  const donneesEnvoyees = JSON.parse(derniere.corps.messages[0].content);
  assert.equal(donneesEnvoyees.prix, 50);
  assert.equal(donneesEnvoyees.statut, 'confirmee');
});

test('entrées invalides : 400, aucun appel au modèle', async () => {
  derniere = undefined;
  const mauvaisPrix = await appeler('/resumer-trajet', {
    depart: 'Tunis',
    arrivee: 'Sfax',
    date: '2026-11-03',
    prix: 'abc',
    statut: 'confirmee',
    transporteur: null,
  });
  const texteManquant = await appeler('/interpreter-commande', { date_reference: '2026-11-02' });
  assert.equal(mauvaisPrix.code, 400);
  assert.equal(texteManquant.code, 400);
  assert.equal(derniere, undefined);
});

test('route inconnue : 404 ; méthode GET : 405', async () => {
  const inconnue = await fetch(`${urlServeur}/api/transport/inconnue`, { method: 'POST' });
  const enGet = await fetch(`${urlServeur}/api/transport/resumer-trajet`);
  assert.equal(inconnue.status, 404);
  assert.equal(enGet.status, 405);
});

test('extraireJson : accepte un JSON entouré de texte', () => {
  assert.deepEqual(extraireJson('Voici la réponse : {"a": 1} merci'), { a: 1 });
});
