import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { decoderPolyligne, simplifierTrace, tracePourRoute } from '../itineraire.js';

// Exemple de référence du format « Google encoded polyline ».
const POLYLIGNE_REFERENCE = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

describe('trace : décodage des polylignes', () => {
  it('décode la polyligne de référence en couples [lat, lon]', () => {
    assert.deepEqual(decoderPolyligne(POLYLIGNE_REFERENCE), [
      [38.5, -120.2],
      [40.7, -120.95],
      [43.252, -126.453],
    ]);
  });

  it('renvoie une liste vide pour une chaîne vide', () => {
    assert.deepEqual(decoderPolyligne(''), []);
  });

  it('refuse une polyligne tronquée au milieu d’un nombre', () => {
    assert.throws(() => decoderPolyligne(POLYLIGNE_REFERENCE.slice(0, -1)));
  });
});

describe('trace : réduction', () => {
  it('garde une trace courte telle quelle', () => {
    const courte = [[1, 1], [2, 2]];
    assert.deepEqual(simplifierTrace(courte, 150), courte);
  });

  it('réduit une longue trace sans dépasser le maximum et garde le dernier point', () => {
    const longue = Array.from({ length: 1000 }, (_, i) => [i, i]);
    const reduite = simplifierTrace(longue, 150);
    assert.ok(reduite.length <= 150, `longueur ${reduite.length}`);
    assert.deepEqual(reduite[0], [0, 0]);
    assert.deepEqual(reduite.at(-1), [999, 999]);
  });
});

describe('trace : route ORS', () => {
  it('décode la géométrie d’une route', () => {
    assert.equal(tracePourRoute({ geometry: POLYLIGNE_REFERENCE }).length, 3);
  });

  it('renvoie une trace vide sans géométrie', () => {
    assert.deepEqual(tracePourRoute({ summary: { distance: 1, duration: 1 } }), []);
  });
});
