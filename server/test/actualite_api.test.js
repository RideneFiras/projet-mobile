/**
 * Tests de l'API des actualités, sans réseau réel : un faux service Anthropic
 * répond à la place de api.anthropic.com. Lancer avec : npm test
 */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { creerServeur } from '../index.js';
import { creerMagasin, filtrerActualites, validerActualite } from '../actualite_api.js';

const CLE = 'cle-de-test';

let faux;
let urlFaux;
let reponseFaux = { status: 200, corps: '' };
let serveur;
let urlServeur;

function repondre(texte) {
  reponseFaux = {
    status: 200,
    corps: JSON.stringify({ content: [{ type: 'text', text: texte }] }),
  };
}

async function appeler(methode, chemin, corps, { entetes = {} } = {}) {
  const r = await fetch(`${urlServeur}${chemin}`, {
    method: methode,
    headers: { 'content-type': 'application/json', ...entetes },
    body: corps === undefined ? undefined : JSON.stringify(corps),
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
      res.writeHead(reponseFaux.status, { 'content-type': 'application/json' });
      res.end(reponseFaux.corps);
    });
  });
  urlFaux = await demarrer(faux);
  serveur = creerServeur({ cle: CLE, base: urlFaux, magasin: creerMagasin() });
  urlServeur = await demarrer(serveur);
});

after(() => {
  serveur.close();
  faux.close();
});

// --- Logique pure ---

test('validerActualite : mêmes règles que l’application', () => {
  assert.equal(validerActualite({ titre: 'Un titre', contenu: 'Un contenu assez long' }), null);
  assert.match(validerActualite({ titre: 'ab', contenu: 'Un contenu assez long' }), /titre/);
  assert.match(validerActualite({ titre: 'Un titre', contenu: 'court' }), /contenu/);
});

test('filtrerActualites : fil commun, recherche sans accents, pagination', () => {
  const liste = [
    { id: 1, titre: 'Bonne année', contenu: 'x', date_publication: '2026-01-01', auteur_id: 10, categorie: 'general' },
    { id: 2, titre: 'Commande', contenu: 'x', date_publication: '2026-11-08', auteur_id: 20, categorie: 'commande' },
    { id: 3, titre: 'Voyage', contenu: 'x', date_publication: '2026-11-09', auteur_id: 10, categorie: 'voyage' },
  ];
  // Fil commun : tout le monde voit tout, quel que soit le rôle.
  assert.deepEqual(filtrerActualites(liste, { role: 'client' }).resultats.map((a) => a.id), [3, 2, 1]);
  assert.deepEqual(filtrerActualites(liste, { role: 'client', recherche: 'annee' }).resultats.map((a) => a.id), [1]);
  assert.equal(filtrerActualites(liste, { role: 'admin' }).total, 3);
  assert.equal(filtrerActualites(liste, { role: 'client', limite: 1 }).resultats.length, 1);
});

// --- REST ---

test('GET /api/actualites : fil commun, toutes visibles', async () => {
  const r = await appeler('GET', '/api/actualites?role=client');
  assert.equal(r.code, 200);
  assert.equal(r.corps.total, 2); // les deux annonces de bienvenue
});

test('GET /api/actualites/{id} : 404 si absente', async () => {
  const r = await appeler('GET', '/api/actualites/9999');
  assert.equal(r.code, 404);
});

test('POST /api/actualites : 403 sans rôle, 201 pour tout utilisateur connecté', async () => {
  const refuse = await appeler('POST', '/api/actualites', {
    titre: 'Offre', contenu: 'Contenu assez long pour passer.',
  });
  assert.equal(refuse.code, 403);

  const cree = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 42, titre: 'Nouvelle offre', contenu: 'Location à prix réduit ce mois-ci.',
    audience: 'traveller', categorie: 'voyage',
  });
  assert.equal(cree.code, 201);
  assert.equal(cree.corps.auteur_id, 42);

  const invalide = await appeler('POST', '/api/actualites', {
    role: 'admin', titre: 'ab', contenu: 'court',
  });
  assert.equal(invalide.code, 400);
});

test('PUT puis DELETE /api/actualites/{id} : auteur ou admin seulement', async () => {
  const cree = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 42, titre: 'À modifier', contenu: 'Contenu assez long pour passer.',
  });
  const id = cree.corps.id;

  // Un autre utilisateur ne peut pas modifier.
  const refuse = await appeler('PUT', `/api/actualites/${id}`, {
    role: 'traveller', auteur_id: 99, titre: 'Piratée', contenu: 'Contenu mis à jour et assez long.',
  });
  assert.equal(refuse.code, 403);

  // L'auteur peut modifier.
  const modifie = await appeler('PUT', `/api/actualites/${id}`, {
    role: 'client', auteur_id: 42, titre: 'Modifiée', contenu: 'Contenu mis à jour et assez long.',
  });
  assert.equal(modifie.code, 200);
  assert.equal(modifie.corps.titre, 'Modifiée');

  // DELETE n'a pas de corps : rôle et auteur passent en paramètres (comme ApiService.delete).
  const supprime = await appeler('DELETE', `/api/actualites/${id}?role=client&auteur_id=42`);
  assert.equal(supprime.code, 200);
  const absent = await appeler('GET', `/api/actualites/${id}`);
  assert.equal(absent.code, 404);
});

test('POST /api/actualites : photo avec le texte (comme Facebook)', async () => {
  const photo = Buffer.from('fausse-image').toString('base64');
  const cree = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 11, titre: 'Photo du voyage', contenu: 'Regardez cette photo de Djerba, magnifique !',
    photo,
  });
  assert.equal(cree.code, 201);
  assert.equal(cree.corps.photo, photo);

  const relu = await appeler('GET', `/api/actualites/${cree.corps.id}`);
  assert.equal(relu.corps.photo, photo);

  // Photo invalide (pas une chaîne) : 400. Une photo > 32 Ko ne passe même
  // pas la limite de corps du serveur (413) : les images sont réduites côté app.
  const invalide = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 11, titre: 'Photo invalide', contenu: 'Contenu assez long pour passer.',
    photo: 123,
  });
  assert.equal(invalide.code, 400);
});

test('méthode non autorisée : 405', async () => {
  const r = await appeler('PATCH', '/api/actualites', {});
  assert.equal(r.code, 405);
});

// --- Commentaires (type Facebook : l'auteur seul modifie/supprime) ---

test('commentaires : publier, lister, modifier et supprimer le sien', async () => {
  const cree = await appeler('POST', '/api/actualites/1/commentaires', {
    role: 'traveller', auteur_id: 7, auteur_nom: 'Karim M.', contenu: 'Super annonce, merci !',
  });
  assert.equal(cree.code, 201);
  const cid = cree.corps.id;

  const liste = await appeler('GET', '/api/actualites/1/commentaires');
  assert.equal(liste.code, 200);
  assert.equal(liste.corps.length, 1);

  // Un autre utilisateur : 403.
  const refuse = await appeler('PUT', `/api/actualites/1/commentaires/${cid}`, {
    role: 'client', auteur_id: 8, contenu: 'Je modifie le commentaire des autres',
  });
  assert.equal(refuse.code, 403);

  // L'auteur modifie puis supprime.
  const modifie = await appeler('PUT', `/api/actualites/1/commentaires/${cid}`, {
    role: 'traveller', auteur_id: 7, contenu: 'Merci pour cette annonce !',
  });
  assert.equal(modifie.code, 200);
  assert.equal(modifie.corps.contenu, 'Merci pour cette annonce !');

  const supprime = await appeler('DELETE', `/api/actualites/1/commentaires/${cid}?auteur_id=7`);
  assert.equal(supprime.code, 200);
  const apres = await appeler('GET', '/api/actualites/1/commentaires');
  assert.equal(apres.corps.length, 0);
});

test('commentaires : 403 sans rôle, 400 si trop court, 404 si post absent', async () => {
  const refuse = await appeler('POST', '/api/actualites/1/commentaires', {
    auteur_id: 7, contenu: 'Un commentaire assez long.',
  });
  assert.equal(refuse.code, 403);

  const court = await appeler('POST', '/api/actualites/1/commentaires', {
    role: 'client', auteur_id: 7, contenu: 'a',
  });
  assert.equal(court.code, 400);

  const absent = await appeler('GET', '/api/actualites/9999/commentaires');
  assert.equal(absent.code, 404);
});

// --- Sondage et J'aime ---

test('sondage seul : la question remplace le texte du post (contenu vide accepté)', async () => {
  const cree = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 7, titre: 'Quelle destination ?', contenu: '',
    options: ['Djerba', 'Tozeur'],
  });
  assert.equal(cree.code, 201, cree.texte);
  assert.equal(cree.corps.titre, 'Quelle destination ?');

  // Sans sondage, le contenu vide reste refusé.
  const refuse = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 7, titre: 'Sans sondage', contenu: '',
  });
  assert.equal(refuse.code, 400);
});

test('sondage : création avec le post, un vote par utilisateur, résultats', async () => {
  const cree = await appeler('POST', '/api/actualites', {
    role: 'traveller', auteur_id: 7, titre: 'Quel voyage ?', contenu: 'Votez pour votre prochaine destination.',
    options: ['Djerba', 'Tozeur'],
  });
  assert.equal(cree.code, 201);
  const id = cree.corps.id;

  const avant = await appeler('GET', `/api/actualites/${id}/sondage`);
  assert.equal(avant.code, 200);
  assert.equal(avant.corps.length, 2);
  const choix = avant.corps.find((o) => o.libelle === 'Djerba');

  assert.equal((await appeler('POST', `/api/actualites/${id}/sondage`, { auteur_id: 7, option_id: choix.id })).code, 200);
  // Même utilisateur, autre choix : remplace le précédent (total reste 1).
  const autre = avant.corps.find((o) => o.libelle === 'Tozeur');
  assert.equal((await appeler('POST', `/api/actualites/${id}/sondage`, { auteur_id: 7, option_id: autre.id })).code, 200);
  let resultats = await appeler('GET', `/api/actualites/${id}/sondage?auteur_id=7`);
  assert.equal(resultats.corps.reduce((s, o) => s + o.votes, 0), 1);
  assert.equal(resultats.corps.find((o) => o.libelle === 'Tozeur').choisi, true);

  // Deuxième utilisateur : total 2, pourcentages 50/50.
  await appeler('POST', `/api/actualites/${id}/sondage`, { auteur_id: 8, option_id: choix.id });
  resultats = await appeler('GET', `/api/actualites/${id}/sondage`);
  assert.deepEqual(resultats.corps.map((o) => o.pourcentage), [50, 50]);
});

test('réaction : choix emoji, changement et retrait', async () => {
  // J'aime par défaut.
  assert.equal((await appeler('POST', '/api/actualites/1/reaction', { auteur_id: 7 })).corps.type, 'like');
  // Même utilisateur, autre type : remplace (total inchangé).
  const adore = await appeler('POST', '/api/actualites/1/reaction', { auteur_id: 7, type: 'love' });
  assert.equal(adore.corps.type, 'love');
  assert.equal(adore.corps.total, 1);
  assert.deepEqual(adore.corps.parType, { love: 1 });
  // Deuxième utilisateur : J'adore aussi.
  await appeler('POST', '/api/actualites/1/reaction', { auteur_id: 8, type: 'love' });
  const etat = await appeler('GET', '/api/actualites/1/reaction?auteur_id=7');
  assert.deepEqual(etat.corps, { total: 2, aime: true });
  // Même type : retire.
  const retire = await appeler('POST', '/api/actualites/1/reaction', { auteur_id: 7, type: 'love' });
  assert.equal(retire.corps.aime, false);
  assert.equal(retire.corps.total, 1);
});

// --- Épingler et participation ---

test('épingler : auteur seul, puis le post remonte', async () => {
  const cree = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 7, titre: 'À épingler', contenu: 'Contenu assez long pour passer.',
  });
  const id = cree.corps.id;
  // Un autre ne peut pas épingler.
  assert.equal((await appeler('PUT', `/api/actualites/${id}`, {
    role: 'client', auteur_id: 8,
  })).code, 403);
  // L'auteur épingle (PUT sans titre : seul l'épingle change).
  const epingle = await appeler('PUT', `/api/actualites/${id}`, {
    role: 'client', auteur_id: 7, epingle: true,
    titre: 'À épingler', contenu: 'Contenu assez long pour passer.',
  });
  assert.equal(epingle.code, 200);
  assert.equal(epingle.corps.epingle, true);
});

test('participation : bascule Participer, un seul par utilisateur', async () => {
  const cree = await appeler('POST', '/api/actualites', {
    role: 'client', auteur_id: 7, titre: 'Sortie', contenu: 'Sortie organisée ce week-end.',
  });
  const id = cree.corps.id;
  assert.deepEqual((await appeler('POST', `/api/actualites/${id}/participation`, { auteur_id: 8 })).corps,
    { participe: true, total: 1 });
  assert.deepEqual((await appeler('POST', `/api/actualites/${id}/participation`, { auteur_id: 8 })).corps,
    { participe: false, total: 0 });
  const etat = await appeler('GET', `/api/actualites/${id}/participation?auteur_id=8`);
  assert.deepEqual(etat.corps, { total: 0, participe: false });
});

// --- IA : brouillon (nécessite anthropic.js, absent de ce serveur : 503 + repli local) ---

test('POST /api/actualites/brouillon : sans client IA, 503 (repli local côté application)', async () => {
  const r = await appeler('POST', '/api/actualites/brouillon', {
    theme: 'nouvelles destinations de voyage', audience: 'traveller', categorie: 'voyage',
  });
  assert.equal(r.code, 503);
});

test('sans ANTHROPIC_API_KEY, le brouillon répond 503 (repli local côté application)', async () => {
  const sansCle = creerServeur({ cle: null, magasin: creerMagasin() });
  const url = await demarrer(sansCle);
  try {
    const r = await fetch(`${url}/api/actualites/brouillon`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ theme: 'nouvelles destinations' }),
    });
    assert.equal(r.status, 503);
  } finally {
    sansCle.close();
  }
});
