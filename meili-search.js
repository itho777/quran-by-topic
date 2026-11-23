/* ================================================
   meili-search.js — Meilisearch keyword engine for tafseer.id
   ---------------------------------------------------------------
   Primary keyword search. Falls back to the in-house client index
   (app.js step 3) when this returns no hits or fails.

   Index: `verses` — one document per (source, verse) pair.
     {id, verse:"2:187", source:"id.kemenag", kind, lang, sura, ayah,
      sura_name_en, sura_name_local, text}
   kind ∈ quran | translations | tafsirs | asbabun_nuzul | transliterations
   filterable: source, kind, lang, sura, ayah

   Only the search-only key is used here. It is scoped to `search` on all
   indexes, so publishing it in the bundle grants nothing else.
   ================================================ */

const CONFIG = {
  // Cloudflare Worker that follows the active InstaBox (meili-handoff-router).
  host: 'https://meili-handoff-router.irianto-suryoputro.workers.dev',
  searchKey: '5097f0a23f1728b653e9f31a8cefba073f47ab04e47fd3ed75348a46c8182a4e',
  index: 'verses',
  timeoutMs: 4500,
  maxHits: 100,
  cacheTtlMs: 5 * 60 * 1000,
  cacheMax: 40,
};

// UI checkbox → index `kind`
const KIND_BY_OPTION = {
  quran: 'quran',
  trans: 'translations',
  tafsir: 'tafsirs',
  nuzul: 'asbabun_nuzul',
  translit: 'transliterations',
};

// Only these kinds have a registry source id the results UI can link to.
const SNIPPET_KINDS = new Set(['translations', 'tafsirs', 'asbabun_nuzul']);

const cache = new Map();

function cacheGet(key) {
  const hit = cache.get(key);
  if (!hit) return null;
  if (Date.now() - hit.at > CONFIG.cacheTtlMs) {
    cache.delete(key);
    return null;
  }
  return hit.value;
}

function cacheSet(key, value) {
  if (cache.size >= CONFIG.cacheMax) {
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) cache.delete(oldest);
  }
  cache.set(key, { at: Date.now(), value });
}

/**
 * Build a Meilisearch filter expression from the search-UI checkboxes.
 * Returns '' when every category is enabled and no language is pinned.
 */
export function buildFilter(searchOptions) {
  const opts = searchOptions || {};
  const lang = opts.lang && opts.lang !== 'all' ? String(opts.lang) : null;
  const clauses = [];

  Object.keys(KIND_BY_OPTION).forEach((optKey) => {
    if (!opts[optKey]) return;
    const kind = KIND_BY_OPTION[optKey];
    if (kind === 'quran') {
      // The Arabic text is always lang "ar"; never pin it to a translation lang.
      clauses.push('(kind = "quran")');
      return;
    }
    if (kind === 'transliterations') {
      // Transliterations are per-source, not per-UI-language; keep them broad.
      clauses.push('(kind = "transliterations")');
      return;
    }
    clauses.push(
      lang
        ? `(kind = "${kind}" AND lang = "${lang}")`
        : `(kind = "${kind}")`
    );
  });

  return clauses.join(' OR ');
}

function stripTags(html) {
  return String(html || '')
    .replace(/<mark[^>]*>/gi, '')
    .replace(/<\/mark>/gi, '')
    .replace(/<[^>]+>/g, '');
}

function normalizeHits(raw, query) {
  const out = [];
  for (const hit of raw) {
    if (!hit || !hit.verse || typeof hit.verse !== 'string' || !hit.verse.includes(':')) continue;
    out.push({
      verse: hit.verse,
      kind: hit.kind || '',
      source: hit.source || '',
      lang: hit.lang || '',
      snippet: SNIPPET_KINDS.has(hit.kind)
        ? stripTags(hit._formatted && hit._formatted.text) || String(hit.text || '').slice(0, 240)
        : '',
    });
  }
  return out;
}

async function request(query, filter, matchingStrategy) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), CONFIG.timeoutMs);
  try {
    const res = await fetch(`${CONFIG.host}/indexes/${CONFIG.index}/search`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${CONFIG.searchKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        q: query,
        limit: CONFIG.maxHits,
        // `all` is mandatory for Arabic: the tokenizer splits off the definite
        // article `ال`, and the default strategy stops matching as soon as that
        // token matches — which is nearly every verse.
        matchingStrategy,
        filter: filter || undefined,
        attributesToHighlight: ['text'],
        attributesToCrop: ['text'],
        cropLength: 45,
        highlightPreTag: '<mark class="highlight">',
        highlightPostTag: '</mark>',
      }),
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`Meilisearch HTTP ${res.status}`);
    const data = await res.json();
    return { hits: data.hits || [], total: data.estimatedTotalHits || 0 };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Query the `verses` index.
 * @returns {Promise<{ok:boolean, engine:string, strategy:string, total:number,
 *                    hits:Array<{verse,kind,source,lang,snippet}>, error?:string}>}
 */
export async function meiliSearchVerses(query, searchOptions) {
  const q = String(query || '').trim();
  if (!q) return { ok: true, engine: 'meili', strategy: 'all', total: 0, hits: [] };

  // "Tags" is a client-side category with no documents in this index; when it
  // is the only thing enabled there is nothing to ask the server for.
  //
  // Arabic recall is handled at index time, not here: the quran documents
  // carry a `text_norm` field with diacritics/tatweel removed, rasm `صلوة`
  // mapped to `صلاة`, and the superscript-alef variants emitted separately.
  // Keep the query untouched so the same field serves modern and Uthmani
  // spellings without a second request.
  const anyKind = Object.keys(KIND_BY_OPTION).some((k) => searchOptions && searchOptions[k]);
  if (!anyKind) return { ok: true, engine: 'meili', strategy: 'all', total: 0, hits: [] };

  const filter = buildFilter(searchOptions);
  const cacheKey = `${filter}|${q.toLowerCase()}`;
  const cached = cacheGet(cacheKey);
  if (cached) return cached;

  try {
    let strategy = 'all';
    let result = await request(q, filter, strategy);

    // `all` is mandatory: the Arabic tokenizer splits off `ال`, and `last`
    // matches 4,205 Qur'an verses for the single word "الصلاة".
    //
    // Arabic queries get no retry. The `verses` index carries `text_norm`
    // (see index_quran_verses.py) with every Uthmani spelling pre-folded, so
    // zero hits means the word is not in the corpus — widening the query only
    // returns verses that happened to contain the article. Latin queries keep
    // one `frequency` retry for long natural-language phrases; `last` is
    // never tried because it matches nearly the whole index.
    const hasArabic = /[\u0600-\u06ff]/.test(q);
    if (!hasArabic && result.hits.length === 0 && q.split(/\s+/).length > 1) {
      strategy = 'frequency';
      result = await request(q, filter, strategy);
    }

    const value = {
      ok: true,
      engine: 'meili',
      strategy,
      total: result.total,
      hits: normalizeHits(result.hits, q),
    };
    if (value.hits.length > 0) cacheSet(cacheKey, value);
    return value;
  } catch (err) {
    return {
      ok: false,
      engine: 'meili',
      strategy: 'all',
      total: 0,
      hits: [],
      error: err && err.message ? err.message : String(err),
    };
  }
}

export const MEILI_INDEX = CONFIG.index;
export { KIND_BY_OPTION, SNIPPET_KINDS };
