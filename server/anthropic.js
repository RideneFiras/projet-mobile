/**
 * Client minimal de l'API Messages d'Anthropic, sans dépendance.
 *
 * - La clé vient de la variable d'environnement ANTHROPIC_API_KEY. Elle n'est ni écrite
 *   dans le code, ni renvoyée à l'application, ni journalisée.
 * - Aucun paramètre temperature, top_p ou top_k n'est envoyé (cahier des charges, §7.3).
 */

export const MODELE = 'claude-haiku-5-5';

const URL_PAR_DEFAUT = 'https://api.anthropic.com';
const DELAI_MS = 20_000;

/** Échec de l'appel à Anthropic (réseau, délai dépassé, code HTTP d'erreur). */
export class ErreurUpstream extends Error {}

/** Clé lue dans l'environnement, ou null si elle est absente. */
export function cleApi(env = process.env) {
  const cle = (env.ANTHROPIC_API_KEY ?? '').trim();
  return cle === '' ? null : cle;
}

/**
 * Envoie un message à l'API Messages et renvoie le texte de la première réponse.
 *
 * @param {object} p
 * @param {string} p.systeme     instructions propres à la tâche
 * @param {string} p.message     données de la requête (JSON), traitées comme des données
 * @param {number} p.maxTokens   plafond de longueur de la réponse
 * @param {string} p.cle         clé API
 * @param {string} [p.base]      URL de base (ANTHROPIC_BASE_URL, utile pour les tests)
 * @param {typeof fetch} [p.fetchImpl]
 */
export async function demanderTexte({
  systeme,
  message,
  maxTokens,
  cle,
  base = process.env.ANTHROPIC_BASE_URL || URL_PAR_DEFAUT,
  fetchImpl = fetch,
}) {
  let reponse;
  try {
    reponse = await fetchImpl(`${base.replace(/\/+$/, '')}/v1/messages`, {
      method: 'POST',
      headers: {
        'x-api-key': cle,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: MODELE,
        max_tokens: maxTokens,
        system: systeme,
        messages: [{ role: 'user', content: message }],
      }),
      signal: AbortSignal.timeout(DELAI_MS),
    });
  } catch {
    throw new ErreurUpstream('appel à Anthropic impossible (réseau ou délai dépassé)');
  }

  if (!reponse.ok) {
    // Le corps de l'erreur n'est pas transmis : il peut contenir des détails internes.
    throw new ErreurUpstream(`Anthropic a répondu ${reponse.status}`);
  }

  const corps = await reponse.json().catch(() => null);
  const bloc = corps?.content?.find?.((b) => b?.type === 'text');
  if (typeof bloc?.text !== 'string') {
    throw new ErreurUpstream('réponse Anthropic sans texte');
  }
  return bloc.text;
}
