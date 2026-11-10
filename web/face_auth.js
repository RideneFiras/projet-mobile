// =====================================================================
//  MODULE USER — Vérification faciale (2FA) côté navigateur
//
//  Utilise face-api.js (réseau de reconnaissance issu de dlib, comme la
//  librairie Python face_recognition) : chaque visage devient un vecteur
//  de 128 nombres. La COMPARAISON des vecteurs est faite en Dart
//  (lib/modules/user/visage/comparateur_visage.dart).
//
//  Exposé à Flutter : window.faceAuthCapturer(titre, sousTitre)
//    -> Promise<string|null>
//       null                       : l'utilisateur a annulé
//       '{"descripteur":[...128]}' : visage capturé (moyenne de 3 images)
//       '{"erreur":"..."}'         : caméra refusée, délai dépassé, etc.
//
//  La librairie et les modèles (~12 Mo) sont chargés depuis le CDN au
//  premier usage seulement : rien à installer sur le PC.
// =====================================================================
(function () {
  'use strict';

  const CDN = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.15';
  const NB_ECHANTILLONS = 3; // images moyennées pour un vecteur plus stable
  const SCORE_MIN = 0.8; // confiance minimale de la détection
  const DELAI_MAX_MS = 30000;

  let modeles = null;

  function chargerScript() {
    if (window.faceapi) return Promise.resolve();
    return new Promise((ok, ko) => {
      const s = document.createElement('script');
      s.src = CDN + '/dist/face-api.js';
      s.onload = ok;
      s.onerror = () => ko(new Error('Impossible de charger face-api (connexion Internet ?)'));
      document.head.appendChild(s);
    });
  }

  function chargerModeles() {
    if (!modeles) {
      modeles = chargerScript()
        .then(() =>
          Promise.all([
            faceapi.nets.ssdMobilenetv1.loadFromUri(CDN + '/model'),
            faceapi.nets.faceLandmark68Net.loadFromUri(CDN + '/model'),
            faceapi.nets.faceRecognitionNet.loadFromUri(CDN + '/model'),
          ])
        )
        .catch((e) => {
          modeles = null; // nouvel essai au prochain appel
          throw e;
        });
    }
    return modeles;
  }

  function moyenne(vecteurs) {
    const n = vecteurs[0].length;
    const m = new Array(n).fill(0);
    for (const v of vecteurs) for (let i = 0; i < n; i++) m[i] += v[i];
    return m.map((x) => x / vecteurs.length);
  }

  // ----- Fenêtre (overlay HTML au-dessus de l'application Flutter) -----
  function creerFenetre(titre, sousTitre) {
    const fond = document.createElement('div');
    fond.style.cssText =
      'position:fixed;inset:0;z-index:99999;background:rgba(19,38,59,.72);' +
      'display:flex;align-items:center;justify-content:center;padding:16px;' +
      'font-family:"Plus Jakarta Sans",Roboto,Arial,sans-serif;';

    const carte = document.createElement('div');
    carte.style.cssText =
      'background:#fff;border-radius:24px;padding:24px;width:100%;max-width:380px;' +
      'box-shadow:0 20px 50px rgba(0,0,0,.3);text-align:center;';

    const h = document.createElement('div');
    h.textContent = titre;
    h.style.cssText = 'font-size:20px;font-weight:800;color:#13263B;';

    const st = document.createElement('div');
    st.textContent = sousTitre;
    st.style.cssText = 'font-size:14px;color:#5B6B7B;margin:6px 0 16px;';

    const cadre = document.createElement('div');
    cadre.style.cssText =
      'position:relative;width:240px;height:240px;margin:0 auto;border-radius:50%;' +
      'overflow:hidden;border:4px solid #E2E8EE;background:#13263B;transition:border-color .2s;';

    const video = document.createElement('video');
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;
    video.style.cssText =
      'width:100%;height:100%;object-fit:cover;transform:scaleX(-1);';
    cadre.appendChild(video);

    const statut = document.createElement('div');
    statut.textContent = 'Chargement des modèles…';
    statut.style.cssText = 'font-size:15px;font-weight:700;color:#0F7B83;margin-top:16px;min-height:22px;';

    const annuler = document.createElement('button');
    annuler.textContent = 'Annuler';
    annuler.style.cssText =
      'margin-top:18px;width:100%;height:48px;border-radius:999px;border:1.5px solid #0F7B83;' +
      'background:#fff;color:#0F7B83;font-size:16px;font-weight:700;cursor:pointer;';

    carte.append(h, st, cadre, statut, annuler);
    fond.appendChild(carte);
    document.body.appendChild(fond);

    return {
      video,
      annuler,
      statut(texte, couleur) {
        statut.textContent = texte;
        statut.style.color = couleur || '#0F7B83';
      },
      bordure(couleur) {
        cadre.style.borderColor = couleur;
      },
      fermer() {
        fond.remove();
      },
    };
  }

  window.faceAuthCapturer = function (titre, sousTitre) {
    return new Promise((resoudre) => {
      const ui = creerFenetre(titre || 'Vérification faciale', sousTitre || '');
      let flux = null;
      let fini = false;

      function terminer(resultat) {
        if (fini) return;
        fini = true;
        if (flux) flux.getTracks().forEach((t) => t.stop());
        ui.fermer();
        resoudre(resultat === null ? null : JSON.stringify(resultat));
      }

      ui.annuler.onclick = () => terminer(null);

      (async () => {
        try {
          flux = await navigator.mediaDevices.getUserMedia({
            video: { width: 640, height: 480, facingMode: 'user' },
            audio: false,
          });
        } catch (e) {
          return terminer({
            erreur:
              e && e.name === 'NotAllowedError'
                ? "Accès à la caméra refusé. Autorisez la caméra dans le navigateur."
                : 'Caméra indisponible : ' + (e && e.message ? e.message : e),
          });
        }
        if (fini) return terminer(null);
        ui.video.srcObject = flux;

        try {
          await chargerModeles();
        } catch (e) {
          return terminer({ erreur: e.message || String(e) });
        }
        if (fini) return;

        const echantillons = [];
        const debut = Date.now();
        const options = new faceapi.SsdMobilenetv1Options({ minConfidence: 0.5 });

        while (!fini) {
          if (Date.now() - debut > DELAI_MAX_MS) {
            return terminer({ erreur: 'Aucun visage détecté (délai dépassé).' });
          }
          if (ui.video.readyState < 2) {
            await new Promise((r) => setTimeout(r, 150));
            continue;
          }
          const visages = await faceapi
            .detectAllFaces(ui.video, options)
            .withFaceLandmarks()
            .withFaceDescriptors();
          if (fini) return;

          if (visages.length === 0) {
            ui.bordure('#E2E8EE');
            ui.statut('Placez votre visage dans le cercle', '#5B6B7B');
          } else if (visages.length > 1) {
            ui.bordure('#C0392B');
            ui.statut('Un seul visage à la fois', '#C0392B');
          } else if (visages[0].detection.score < SCORE_MIN) {
            ui.bordure('#F68B3F');
            ui.statut('Rapprochez-vous, avec plus de lumière', '#C2581E');
          } else {
            echantillons.push(Array.from(visages[0].descriptor));
            ui.bordure('#0F7B83');
            ui.statut('Analyse… ' + echantillons.length + '/' + NB_ECHANTILLONS);
            if (echantillons.length >= NB_ECHANTILLONS) {
              ui.statut('Visage capturé ✓');
              await new Promise((r) => setTimeout(r, 400));
              return terminer({ descripteur: moyenne(echantillons) });
            }
          }
          await new Promise((r) => setTimeout(r, 200));
        }
      })().catch((e) => terminer({ erreur: e && e.message ? e.message : String(e) }));
    });
  };
})();
