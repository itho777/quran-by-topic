/* ================================================
   TAFSEER.ID – Full Web App
   Supabase-Powered SPA — Read, Comprehend, Apply
   ================================================ */

// --- 0. Supabase Client ---
const SUPABASE_URL = 'https://zgeygoclduqotqveperx.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kyxOvxsj6WxjTCadR_tpoA_Xb7sQ6Ik';
let supabaseClient = null;
let currentUser = null;
let currentUserProfile = null;

function initSupabase() {
  const adminPath = localStorage.getItem('admin_path');
  if (adminPath && window.location.hash.includes('access_token=')) {
    localStorage.removeItem('admin_path');
    window.location.href = window.location.origin + adminPath + window.location.hash;
    return;
  }

  // Fix double hash (e.g. #login#access_token=... or #home#access_token=...) from OAuth redirects
  // BEFORE creating the client so it can parse the access token on load.
  if (window.location.hash.includes('access_token=')) {
    const idx = window.location.hash.indexOf('access_token=');
    if (idx > 1) {
      window.location.hash = '#' + window.location.hash.substring(idx);
    }
  }

  if (typeof supabase !== 'undefined') {
    supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  } else {
    console.warn('[Supabase] CDN not loaded — will use local data files.');
  }
}

// --- 1. Global State & Constants ---
const defaultState = {
  theme: 'dark',
  uiLang: 'en',
  arabicFontSize: 28,
  transFontSize: 15,
  activeTranslation1: 'en.shakir',
  activeTranslation2: 'id.kemenag',
  activeTransliteration: 'en.transliteration',
  activeReciter: 'Alafasy_128kbps',
  activeTafsir1: 'en.katsir_pdf',
  activeTafsir2: 'id.jalalayn',
  activeNuzul1: 'en.wahidi',
  activeNuzul2: 'id.kemenag_nuzul',
  activeTags: 'en',
  tagsUserPref: false,
  trans1UserPref: false,
  trans2UserPref: false,
  transliterationUserPref: false,
  nuzul1UserPref: false,
  nuzul2UserPref: false,
  tafsir1UserPref: false,
  tafsir2UserPref: false,
  // Pagination
  ayahPerPage: 10,
  layers: {
    trans1: true,
    trans2: true,
    transliteration: true,
    tafsir1: true,
    tafsir2: true,
    nuzul1: true,
    nuzul2: true,
    tags: true
  },
  searchOptions: {
    quran: true,
    trans: true,
    tafsir: true,
    nuzul: true,
    tags: true,
    semantic: false,
    lang: 'all'
  }
};

// Per-sura pagination state (not persisted — resets on navigation)
let suraPage = 1;
let topicPage = 1;
let searchPage = 1;

// Semantic search similarity scores: { "sura:ayah" -> similarity (0-1) }
let searchSimilarityScores = {};
let searchContextSnippets = {};
let lastActiveHash = '#home';

// Bookmarks store (Set of verse keys: e.g. "1:1")
const bookmarks = new Set(JSON.parse(localStorage.getItem('tafsir_bookmarks')) || []);

function saveBookmarks() {
  localStorage.setItem('tafsir_bookmarks', JSON.stringify(Array.from(bookmarks)));
}

// Settings schema version — bump whenever defaults change meaningfully
const SETTINGS_VERSION = 8;

let state = JSON.parse(localStorage.getItem('tafsir_settings')) || defaultState;
// If the stored settings predate this version, reset non-preference keys to defaults
// but keep user preferences (theme, font sizes, layer toggles, user pref flags).
if (!state._v || state._v < SETTINGS_VERSION) {
  const userPrefs = {
    theme: state.theme,
    uiLang: state.uiLang,
    arabicFontSize: state.arabicFontSize,
    transFontSize: state.transFontSize,
    layers: state.layers,
    // Preserve explicit user selections only if they have the UserPref flag set
    activeTranslation1: state.trans1UserPref ? state.activeTranslation1 : defaultState.activeTranslation1,
    activeTranslation2: state.trans2UserPref ? state.activeTranslation2 : defaultState.activeTranslation2,
    activeTransliteration: state.transliterationUserPref ? state.activeTransliteration : defaultState.activeTransliteration,
    activeTafsir1: state.tafsir1UserPref ? state.activeTafsir1 : defaultState.activeTafsir1,
    activeTafsir2: state.tafsir2UserPref ? state.activeTafsir2 : defaultState.activeTafsir2,
    activeNuzul1: state.nuzul1UserPref ? state.activeNuzul1 : defaultState.activeNuzul1,
    activeNuzul2: state.nuzul2UserPref ? state.activeNuzul2 : defaultState.activeNuzul2,
    activeTags: state.tagsUserPref ? state.activeTags : defaultState.activeTags,
    activeReciter: state.activeReciter || defaultState.activeReciter,
    // Pref flags
    trans1UserPref: state.trans1UserPref || false,
    trans2UserPref: state.trans2UserPref || false,
    transliterationUserPref: state.transliterationUserPref || false,
    tafsir1UserPref: state.tafsir1UserPref || false,
    tafsir2UserPref: state.tafsir2UserPref || false,
    nuzul1UserPref: state.nuzul1UserPref || false,
    nuzul2UserPref: state.nuzul2UserPref || false,
    tagsUserPref: state.tagsUserPref || false,
    // Reset pagination to new default
    ayahPerPage: defaultState.ayahPerPage,
  };
  state = { ...defaultState, ...userPrefs, _v: SETTINGS_VERSION, layers: { ...defaultState.layers, ...(state.layers || {}) } };
  localStorage.setItem('tafsir_settings', JSON.stringify(state));
} else {
  // Normal merge — ensure all keys exist
  state = {
    ...defaultState,
    ...state,
    _v: SETTINGS_VERSION,
    layers: { ...defaultState.layers, ...state.layers },
    searchOptions: { ...defaultState.searchOptions, ...(state.searchOptions || {}) }
  };
}

// Fresh session reset: force primary translation and transliteration to defaults on new visit
if (!sessionStorage.getItem('tafsir_session_active')) {
  state.trans1UserPref = false;
  state.transliterationUserPref = false;
  state.layers.trans1 = true;
  state.layers.transliteration = true;
  
  // Re-apply defaults
  applyLanguageDefaultTranslations(true);
  applyLanguageDefaultTransliterations(true);
  
  localStorage.setItem('tafsir_settings', JSON.stringify(state));
  sessionStorage.setItem('tafsir_session_active', '1');
}

// Runtime-only (not persisted): tracks split-mushaf mode and active verse
state.mushafSplitMode = false;
state.currentSuraId = null;
state.currentAyahNum = null;

function applyLanguageDefaultTranslations(isInit = false) {
  if (isInit) {
    const expectedTrans1 = state.uiLang === 'id' ? 'id.kemenag' : 'en.shakir';
    const expectedTrans2 = state.uiLang === 'id' ? 'en.shakir' : 'id.kemenag';
    if (state.trans1UserPref === undefined) {
      state.trans1UserPref = (state.activeTranslation1 !== expectedTrans1);
    }
    if (state.trans2UserPref === undefined) {
      state.trans2UserPref = (state.activeTranslation2 !== expectedTrans2);
    }
  }

  if (!state.trans1UserPref) {
    state.activeTranslation1 = state.uiLang === 'id' ? 'id.kemenag' : 'en.shakir';
  }
  if (!state.trans2UserPref) {
    state.activeTranslation2 = state.uiLang === 'id' ? 'en.shakir' : 'id.kemenag';
  }
}

function applyLanguageDefaultTransliterations(isInit = false) {
  if (isInit) {
    const expectedTranslit = state.uiLang === 'id' ? 'id.kemenag_translit' : 'en.transliteration';
    if (state.transliterationUserPref === undefined) {
      state.transliterationUserPref = (state.activeTransliteration !== expectedTranslit);
    }
  }

  if (!state.transliterationUserPref) {
    state.activeTransliteration = state.uiLang === 'id' ? 'id.kemenag_translit' : 'en.transliteration';
  }
}

function applyLanguageDefaultNuzul(isInit = false) {
  if (isInit) {
    const expectedNuz1 = state.uiLang === 'id' ? 'id.kemenag_nuzul' : 'en.wahidi';
    const expectedNuz2 = state.uiLang === 'id' ? 'en.wahidi' : 'id.kemenag_nuzul';
    if (state.nuzul1UserPref === undefined) {
      state.nuzul1UserPref = (state.activeNuzul1 !== '' && state.activeNuzul1 !== expectedNuz1);
    }
    if (state.nuzul2UserPref === undefined) {
      state.nuzul2UserPref = (state.activeNuzul2 !== '' && state.activeNuzul2 !== expectedNuz2);
    }
  }

  if (!state.nuzul1UserPref) {
    state.activeNuzul1 = state.uiLang === 'id' ? 'id.kemenag_nuzul' : 'en.wahidi';
  }
  if (!state.nuzul2UserPref) {
    state.activeNuzul2 = state.uiLang === 'id' ? 'en.wahidi' : 'id.kemenag_nuzul';
  }
}

/**
 * Tafsir language defaults:
 *   EN → Primary: en.katsir_pdf | Secondary: id.jalalayn
 *   ID → Primary: id.jalalayn   | Secondary: en.katsir_pdf
 */
function applyLanguageDefaultTafsir(isInit = false) {
  if (isInit) {
    const expectedTaf1 = state.uiLang === 'id' ? 'id.jalalayn' : 'en.katsir_pdf';
    const expectedTaf2 = state.uiLang === 'id' ? 'en.katsir_pdf' : 'id.jalalayn';
    if (state.tafsir1UserPref === undefined) {
      state.tafsir1UserPref = (state.activeTafsir1 !== expectedTaf1);
    }
    if (state.tafsir2UserPref === undefined) {
      state.tafsir2UserPref = (state.activeTafsir2 !== expectedTaf2);
    }
  }

  if (!state.tafsir1UserPref) {
    state.activeTafsir1 = state.uiLang === 'id' ? 'id.jalalayn' : 'en.katsir_pdf';
  }
  if (!state.tafsir2UserPref) {
    state.activeTafsir2 = state.uiLang === 'id' ? 'en.katsir_pdf' : 'id.jalalayn';
  }
}

// Call on load to apply proper default settings
applyLanguageDefaultTranslations(true);
applyLanguageDefaultTransliterations(true);
applyLanguageDefaultNuzul(true);
applyLanguageDefaultTafsir(true);

const i18n = {
  en: {
    heroTitle: "Qur'an Reader & Study Tool",
    heroSubtitle: "Compare translations, read tafsir commentary, and explore by topic",
    slogan: "Read · Comprehend · Apply",
    suraList: "Sura List",
    topics: "Topics",
    settings: "Settings",
    loadingDb: "Loading database...",
    loadingChapters: "Loading chapter index...",
    loadingScript: "Loading Arabic script...",
    loadingTags: "Loading topic maps...",
    ready: "Database ready!",
    gotoTitle: "Go to Ayah",
    gotoSuraLabel: "Select Surah",
    gotoSuraPlaceholder: "Search surah...",
    gotoAyahLabel: "Ayah Number",
    gotoCancel: "Cancel",
    gotoSubmit: "Go",
    advSearchPlaceholder: "Search in the Qur'an…",
    modeKeyword: "Keyword",
    modeSemantic: "Semantic (AI)",
    advToggle: "Advanced",
    searchQuran: "Qur'an Text",
    searchTrans: "Translations",
    searchTafsir: "Tafsirs",
    searchNuzul: "Asbabun Nuzul",
    searchTags: "Tags"
  },
  id: {
    heroTitle: "Al-Qur'an & Alat Kajian Tafsir",
    heroSubtitle: "Bandingkan terjemahan, baca tafsir, dan jelajahi berdasarkan topik",
    slogan: "Baca · Pahami · Amalkan",
    suraList: "Daftar Surah",
    topics: "Topik Tafsir",
    settings: "Pengaturan",
    loadingDb: "Memuat basis data...",
    loadingChapters: "Memuat indeks surah...",
    loadingScript: "Memuat teks Arab...",
    loadingTags: "Memuat peta topik...",
    ready: "Basis data siap!",
    gotoTitle: "Lompat ke Ayat",
    gotoSuraLabel: "Pilih Surah",
    gotoSuraPlaceholder: "Cari surah...",
    gotoAyahLabel: "Nomor Ayat",
    gotoCancel: "Batal",
    gotoSubmit: "Lompat",
    advSearchPlaceholder: "Cari di Al-Qur'an…",
    modeKeyword: "Kata Kunci",
    modeSemantic: "Semantik (AI)",
    advToggle: "Lanjutan",
    searchQuran: "Teks Qur'an",
    searchTrans: "Terjemahan",
    searchTafsir: "Tafsir",
    searchNuzul: "Asbabun Nuzul",
    searchTags: "Tag / Topik"
  }
};

// --- 2. Database Manager (Supabase-Powered) ---
class Database {
  constructor() {
    this.cache = new Map();
    // chunkedSuraLoaded tracks which sura IDs are loaded for each chunked source
    this.chunkedSuraLoaded = new Map(); // cacheKey -> Set<suraNum>
    this.registry = null;
    this.suraList = null;
    this.quranArabic = null;
    this.tags = null;
    this.verseTags = null;
    this.searchIndex = null;
  }

  async init(onProgress) {
    onProgress(10, state.uiLang === 'id' ? i18n.id.loadingDb : i18n.en.loadingDb);
    // Registry, sura list, and Arabic text are static — always load locally
    const regRes = await fetch('data/registry.json');
    this.registry = await regRes.json();

    onProgress(30, state.uiLang === 'id' ? i18n.id.loadingChapters : i18n.en.loadingChapters);
    const suraRes = await fetch(this.registry.sura_list);
    this.suraList = await suraRes.json();

    onProgress(60, state.uiLang === 'id' ? i18n.id.loadingScript : i18n.en.loadingScript);
    const arRes = await fetch(this.registry.quran_arabic);
    this.quranArabic = await arRes.json();

    onProgress(85, state.uiLang === 'id' ? i18n.id.loadingTags : i18n.en.loadingTags);
    // Load tags from Supabase if available, else fall back to local files
    await this._loadTagsFromSupabase(state.activeTags);

    onProgress(100, state.uiLang === 'id' ? i18n.id.ready : i18n.en.ready);
  }

  // Load tags dataset — verseTags always from local JSON (complete), tags list from Supabase or local
  async _loadTagsFromSupabase(lang) {
    const effectiveLang = lang || 'id';

    // Always load verseTags from local JSON — the Supabase table has 110k+ rows
    // and the default REST page size (1000) silently truncates the result,
    // causing missing tag-to-verse mappings for most surahs.
    if (this.registry && this.registry.tags && this.registry.tags.length > 0) {
      let tagInfo = this.registry.tags.find(t => t.id === effectiveLang);
      if (!tagInfo) tagInfo = this.registry.tags[0];
      const mapRes = await fetch(tagInfo.verse_map);
      this.verseTags = await mapRes.json();
    } else {
      this.verseTags = {};
    }

    // Try Supabase for the compact tags list (tag names only — small, ~few hundred rows)
    if (supabaseClient) {
      try {
        const { data: tagsData } = await supabaseClient
          .from('tags')
          .select('id, name')
          .eq('lang', effectiveLang);
        if (tagsData && tagsData.length > 0) {
          this.tags = tagsData;
          return;
        }
        console.warn('[DB] Tags list from Supabase empty, falling back to local file.');
      } catch (e) {
        console.warn('[DB] Tags list Supabase load failed, using local file:', e);
      }
    }

    // Local fallback for tags list
    if (this.registry && this.registry.tags && this.registry.tags.length > 0) {
      let tagInfo = this.registry.tags.find(t => t.id === effectiveLang);
      if (!tagInfo) tagInfo = this.registry.tags[0];
      const tagsRes = await fetch(tagInfo.file);
      this.tags = await tagsRes.json();
    } else {
      this.tags = [];
    }
  }


  // Derive table name and source_id from a registry file path
  _parseFilePath(file) {
    if (file.startsWith('data/translations/') || file.startsWith('data/transliteration/')) {
      const sourceId = file.replace(/^data\/(translations|transliteration)\//, '').replace(/\.json$/, '');
      return { table: 'translations', sourceId };
    }
    if (file.startsWith('data/tafsirs/')) {
      const sourceId = file.replace(/^data\/tafsirs\//, '').replace(/(\.chunks)?\.json$/, '');
      return { table: 'tafsirs', sourceId };
    }
    if (file.startsWith('data/asbabun_nuzul/')) {
      const sourceId = file.replace(/^data\/asbabun_nuzul\//, '').replace(/\.json$/, '');
      return { table: 'asbabun_nuzul', sourceId };
    }
    return null;
  }

  // Fetch a full source dataset from Supabase and cache as { verseKey: text }
  async getResource(file) {
    const cacheKey = file.replace('.chunks.json', '.json');
    if (this.cache.has(cacheKey)) return this.cache.get(cacheKey);

    const parsed = this._parseFilePath(file);
    if (supabaseClient && parsed) {
      try {
        const result = {};
        let from = 0;
        const pageSize = 1000;
        while (true) {
          const { data, error } = await supabaseClient
            .from(parsed.table)
            .select('verse_key, text')
            .eq('source_id', parsed.sourceId)
            .range(from, from + pageSize - 1);
          if (error) throw error;
          if (!data || data.length === 0) break;
          data.forEach(row => { result[row.verse_key] = row.text; });
          if (data.length < pageSize) break;
          from += pageSize;
        }

        // Validate completeness of database response before caching it:
        const count = Object.keys(result).length;
        let isComplete = false;
        if (parsed.table === 'translations' || parsed.table === 'tafsirs') {
          const isChunked = file.includes('.chunks.json');
          if (isChunked) {
            isComplete = (count > 0);
          } else {
            isComplete = (count >= 6000);
          }
        } else if (parsed.table === 'asbabun_nuzul') {
          if (parsed.sourceId === 'en.wahidi') isComplete = (count >= 630);
          else if (parsed.sourceId === 'id.kemenag_nuzul') isComplete = (count >= 100);
          else isComplete = (count > 0);
        } else {
          isComplete = (count > 0);
        }

        if (isComplete) {
          this.cache.set(cacheKey, result);
          return result;
        } else {
          console.warn(`[DB] Supabase source ${parsed.sourceId} has incomplete/empty rows (${count}), falling back to local file`);
        }
      } catch (e) {
        console.warn(`[DB] Supabase getResource failed for ${file}, falling back:`, e);
      }
    }
    // Local file fallback
    // If it's a chunks.json metadata file, fetch the corresponding .json file instead (which contains the full dataset)
    const localFile = file.replace('.chunks.json', '.json');
    const res = await fetch(localFile);
    const data = await res.json();
    this.cache.set(cacheKey, data);
    return data;
  }

  // Load surah-level data for a chunked source (tafsir) via Supabase
  async getChunkedResource(src, suraNum) {
    const cacheKey = src.file.replace('.chunks.json', '.json');
    if (!this.cache.has(cacheKey)) this.cache.set(cacheKey, {});
    if (!this.chunkedSuraLoaded.has(cacheKey)) this.chunkedSuraLoaded.set(cacheKey, new Set());

    const loaded = this.chunkedSuraLoaded.get(cacheKey);
    if (loaded.has(suraNum)) return this.cache.get(cacheKey);

    const parsed = this._parseFilePath(src.file);
    if (supabaseClient && parsed) {
      try {
        const { data, error } = await supabaseClient
          .from(parsed.table)
          .select('verse_key, text, verses!inner(sura_id)')
          .eq('source_id', parsed.sourceId)
          .eq('verses.sura_id', suraNum);
        if (error) throw error;
        if (data && data.length > 0) {
          const unified = this.cache.get(cacheKey);
          data.forEach(row => { unified[row.verse_key] = row.text; });
          loaded.add(suraNum);
          return unified;
        } else {
          console.warn(`[DB] Supabase chunked load returned 0 rows for ${parsed.sourceId} sura ${suraNum}, falling back to local file`);
        }
      } catch (e) {
        console.warn(`[DB] Supabase chunked load failed for sura ${suraNum}:`, e);
      }
    }
    // Fallback: fetch all (non-chunked path)
    return this.getResource(src.file);
  }

  // Return already-merged data for a chunked source
  getCachedChunked(src) {
    const cacheKey = src.file.replace('.chunks.json', '.json');
    return this.cache.get(cacheKey) || null;
  }
}


const db = new Database();
let tagLookup = new Map();
let tagCounts = {};

// --- 3. Save / Load Settings & Style Application ---
function saveSettings() {
  localStorage.setItem('tafsir_settings', JSON.stringify(state));
}

function applyStyles() {
  document.documentElement.setAttribute('data-theme', state.theme);
  document.documentElement.style.setProperty('--arabic-size', state.arabicFontSize + 'px');
  document.documentElement.style.setProperty('--trans-size', state.transFontSize + 'px');
  // Tafsir size scales proportionally
  document.documentElement.style.setProperty('--tafsir-size', (state.transFontSize - 1) + 'px');
  
  const arLabel = document.getElementById('arabic-font-label');
  const transLabel = document.getElementById('trans-font-label');
  if (arLabel) arLabel.textContent = state.arabicFontSize + 'px';
  if (transLabel) transLabel.textContent = state.transFontSize + 'px';
}

function updateThemeButtons() {
  ['dark', 'light', 'sepia'].forEach(t => {
    const btn = document.getElementById(`theme-${t}`);
    if (btn) {
      if (state.theme === t) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    }
  });
}

function applyLocalization() {
  const lang = state.uiLang || 'en';
  const dict = i18n[lang];

  // Update tabs
  const tabSura = document.getElementById('tab-sura-list');
  const tabTopics = document.getElementById('tab-topics');
  const tabSettings = document.getElementById('tab-settings');

  if (tabSura) tabSura.innerHTML = `<svg viewBox="0 0 24 24"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>${dict.suraList}`;
  if (tabTopics) tabTopics.innerHTML = `<svg viewBox="0 0 24 24"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>${dict.topics}`;
  if (tabSettings) tabSettings.innerHTML = `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>${dict.settings}`;

  // Update Hero
  const title = document.querySelector('.home-hero-title');
  const subtitle = document.querySelector('.home-hero-subtitle');
  if (title) title.textContent = dict.heroTitle;
  if (subtitle) subtitle.textContent = dict.heroSubtitle;
  
  // Update sidebar tagline
  const sidebarTagline = document.getElementById('sidebar-tagline');
  if (sidebarTagline) sidebarTagline.textContent = dict.slogan;

  // Update splash tagline
  const splashTagline = document.getElementById('splash-tagline');
  if (splashTagline) splashTagline.textContent = dict.slogan;

  // Search input
  const searchInput = document.getElementById('search-input');
  if (searchInput) searchInput.placeholder = lang === 'id' ? 'Cari topik, ayat...' : 'Search topics, verses...';

  // Go to Ayah modal localization
  const modalTitle = document.getElementById('goto-modal-title');
  const suraLabel = document.getElementById('goto-sura-label');
  const suraSearch = document.getElementById('goto-sura-search');
  const ayahLabel = document.getElementById('goto-ayah-label');
  const cancelBtn = document.getElementById('goto-cancel-btn');
  const submitBtn = document.getElementById('goto-submit-btn');

  if (modalTitle) modalTitle.textContent = dict.gotoTitle;
  if (suraLabel) suraLabel.textContent = dict.gotoSuraLabel;
  if (suraSearch) suraSearch.placeholder = dict.gotoSuraPlaceholder;
  if (ayahLabel) ayahLabel.textContent = dict.gotoAyahLabel;
  if (cancelBtn) cancelBtn.textContent = dict.gotoCancel;
  if (submitBtn) submitBtn.textContent = dict.gotoSubmit;

  // New Advanced Search localization
  const advSearchInput = document.getElementById('adv-search-input');
  if (advSearchInput) advSearchInput.placeholder = dict.advSearchPlaceholder;

  const modePillKeyword = document.getElementById('mode-pill-keyword-label');
  if (modePillKeyword) modePillKeyword.textContent = dict.modeKeyword;

  const modePillSemantic = document.getElementById('mode-pill-semantic-label');
  if (modePillSemantic) modePillSemantic.textContent = dict.modeSemantic;

  const advToggleLabel = document.getElementById('adv-toggle-label');
  if (advToggleLabel) advToggleLabel.textContent = dict.advToggle;

  const updateLabelText = (id, text) => {
    const input = document.getElementById(id);
    if (input && input.parentElement) {
      for (const node of input.parentElement.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) {
          node.textContent = ' ' + text;
          break;
        }
      }
    }
  };
  updateLabelText('adv-search-quran', dict.searchQuran);
  updateLabelText('adv-search-trans', dict.searchTrans);
  updateLabelText('adv-search-tafsir', dict.searchTafsir);
  updateLabelText('adv-search-nuzul', dict.searchNuzul);
  updateLabelText('adv-search-tags', dict.searchTags);
}

// --- 4. Lazy-loading Required Datasets ---
async function ensureActiveDatasets(suraNum) {
  const promises = [];
  const sura = suraNum || getActiveSuraId();
  
  if (state.layers.trans1 && state.activeTranslation1) {
    const item = db.registry.translations.find(t => t.id === state.activeTranslation1);
    if (item) promises.push(db.getResource(item.file));
  }
  if (state.layers.trans2 && state.activeTranslation2) {
    const item = db.registry.translations.find(t => t.id === state.activeTranslation2);
    if (item) promises.push(db.getResource(item.file));
  }
  if (state.layers.tafsir1 && state.activeTafsir1) {
    const item = db.registry.tafsirs.find(t => t.id === state.activeTafsir1);
    if (item) {
      promises.push(item.chunked ? db.getChunkedResource(item, sura) : db.getResource(item.file));
    }
  }
  if (state.layers.tafsir2 && state.activeTafsir2) {
    const item = db.registry.tafsirs.find(t => t.id === state.activeTafsir2);
    if (item) {
      promises.push(item.chunked ? db.getChunkedResource(item, sura) : db.getResource(item.file));
    }
  }
  if (state.layers.nuzul1 && state.activeNuzul1) {
    const item = db.registry.asbabun_nuzul.find(n => n.id === state.activeNuzul1);
    if (item) promises.push(db.getResource(item.file));
  }
  if (state.layers.nuzul2 && state.activeNuzul2) {
    const item = db.registry.asbabun_nuzul.find(n => n.id === state.activeNuzul2);
    if (item) promises.push(db.getResource(item.file));
  }
  if (state.layers.transliteration && state.activeTransliteration) {
    const item = db.registry.transliterations && db.registry.transliterations.find(t => t.id === state.activeTransliteration);
    if (item) promises.push(db.getResource(item.file));
  }
  
  await Promise.all(promises);
}

// Return cached tafsir data regardless of whether the source is chunked or not.
function getTafsirData(item) {
  if (!item) return null;
  if (item.chunked) return db.getCachedChunked(item);
  return db.cache.get(item.file) || null;
}

// Dynamically reloads the tags dataset when lang or active tags dataset changes
async function reloadTagsDataset() {
  await db._loadTagsFromSupabase(state.activeTags);
  tagLookup = new Map(db.tags.map(t => [t.id, t.name]));
  tagCounts = {};
  for (const verseKey in db.verseTags) {
    db.verseTags[verseKey].forEach(id => {
      tagCounts[id] = (tagCounts[id] || 0) + 1;
    });
  }
  renderSidebarTopicList();
}

// --- 5. Navigation & Routing ---
function switchView(viewId) {
  document.querySelectorAll('.view-area .view').forEach(v => {
    v.classList.remove('active');
    if (v.id === 'view-mushaf') {
      v.style.setProperty('display', 'none', 'important');
    }
  });
  const view = document.getElementById(`view-${viewId}`);
  if (view) {
    view.classList.add('active');
    if (viewId === 'mushaf') {
      view.style.setProperty('display', 'flex', 'important');
    }
  }
}

function updateBreadcrumbs(view, details = {}) {
  const breadcrumb = document.getElementById('topbar-breadcrumb');
  if (!breadcrumb) return;

  let html = `<span style="cursor:pointer" onclick="window.location.hash='#home'">Qur'an</span>`;

  if (view === 'sura') {
    const name = state.uiLang === 'id' ? details.sura.name_id : details.sura.name_en;
    html += ` <span class="sep">/</span> <span class="current">${name}</span>`;
  } else if (view === 'ayah') {
    const name = state.uiLang === 'id' ? details.sura.name_id : details.sura.name_en;
    html += ` <span class="sep">/</span> <span style="cursor:pointer" onclick="window.location.hash='#sura/${details.sura.id}'">${name}</span> <span class="sep">/</span> <span class="current">Ayah ${details.verse}</span>`;
  } else if (view === 'topic') {
    html += ` <span class="sep">/</span> <span style="cursor:pointer" onclick="window.location.hash='#home'">Topics</span> <span class="sep">/</span> <span class="current">${details.topicName}</span>`;
  } else if (view === 'search') {
    html += ` <span class="sep">/</span> <span class="current">Search</span>`;
  }

  breadcrumb.innerHTML = html;
}

// --- 6. Rendering Functions ---
// Localize sura revelation type based on UI language
function localizeType(type) {
  if (state.uiLang !== 'id') return type;
  if (type === 'Meccan') return 'Makkiyah';
  if (type === 'Medinan') return 'Madaniyyah';
  return type;
}

function renderSidebarSuraList() {
  const container = document.getElementById('sura-list-container');
  container.innerHTML = '';
  
  db.suraList.forEach(sura => {
    const name = state.uiLang === 'id' ? sura.name_id : sura.name_en;
    const item = document.createElement('div');
    item.className = 'sura-item';
    item.id = `sura-item-${sura.id}`;
    item.innerHTML = `
      <div class="sura-item-num">${sura.id}</div>
      <div class="sura-item-info">
        <div class="sura-item-name-en">${name}</div>
        <div class="sura-item-sub">${localizeType(sura.type)} • ${sura.ayas} ${state.uiLang === 'id' ? 'ayat' : 'verses'}</div>
      </div>
      <div class="sura-item-ar" lang="ar">${sura.name_ar}</div>
    `;
    item.addEventListener('click', () => {
      window.location.hash = `#sura/${sura.id}`;
      closeSidebarMobile();
    });
    container.appendChild(item);
  });
}

function renderHomeGrid() {
  const grid = document.getElementById('sura-grid');
  if (!grid) return;
  grid.innerHTML = '';

  db.suraList.forEach(sura => {
    const name = state.uiLang === 'id' ? sura.name_id : sura.name_en;
    const card = document.createElement('div');
    card.className = 'sura-card';
    card.innerHTML = `
      <div class="sura-card-num">${sura.id}</div>
      <div class="sura-card-info">
        <div class="sura-card-name">${name}</div>
        <div class="sura-card-meta">${state.uiLang === 'id' && sura.meaning_id ? sura.meaning_id : sura.meaning} • ${sura.ayas} ${state.uiLang === 'id' ? 'ayat' : 'verses'}</div>
      </div>
      <div class="sura-card-ar" lang="ar">${sura.name_ar}</div>
    `;
    card.addEventListener('click', () => {
      window.location.hash = `#sura/${sura.id}`;
    });
    grid.appendChild(card);
  });
}

function renderSidebarTopicList() {
  const container = document.getElementById('topic-list-container');
  container.innerHTML = '';

  // Sort tags alphabetically
  const sortedTags = [...db.tags].sort((a, b) => a.name.localeCompare(b.name));

  sortedTags.forEach(tag => {
    const count = tagCounts[tag.id] || 0;
    if (count === 0) return; // Hide empty tags

    const item = document.createElement('div');
    item.className = 'topic-tag-item';
    item.innerHTML = `
      <span>${tag.name}</span>
      <span class="topic-tag-count">${count}</span>
    `;
    item.addEventListener('click', () => {
      window.location.hash = `#topic/${tag.id}`;
      closeSidebarMobile();
    });
    container.appendChild(item);
  });
}

function highlightActiveSuraInSidebar(suraId) {
  document.querySelectorAll('.sura-item').forEach(item => {
    item.classList.remove('active');
  });
  if (suraId) {
    const activeItem = document.getElementById(`sura-item-${suraId}`);
    if (activeItem) {
      activeItem.classList.add('active');
      activeItem.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  }
}

// Custom chunked rendering to prevent UI freezes on massive suras
function renderVerseList(container, versesToRender, highlightQuery = '') {
  container.innerHTML = '';
  if (versesToRender.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">🔍</div>
        <div class="empty-state-title">No verses found</div>
        <div class="empty-state-text">Try adjusting your filters or search query.</div>
      </div>
    `;
    return;
  }

  const CHUNK_SIZE = 12;
  let currentIndex = 0;

  function renderNextChunk() {
    const end = Math.min(currentIndex + CHUNK_SIZE, versesToRender.length);
    const fragment = document.createDocumentFragment();

    for (let i = currentIndex; i < end; i++) {
      const verseKey = versesToRender[i];
      const card = createVerseCard(verseKey, false, highlightQuery);
      fragment.appendChild(card);
    }

    container.appendChild(fragment);

    // Post-process: reveal "Show more" buttons only when content actually overflows
    requestAnimationFrame(() => {
      container.querySelectorAll('.verse-layer-more:not([data-processed])').forEach(btn => {
        btn.setAttribute('data-processed', '1');
        const textEl = btn.previousElementSibling;
        if (textEl && textEl.scrollHeight > textEl.clientHeight + 2) {
          btn.style.display = '';
        }
      });
      container.querySelectorAll('.tags-more-btn:not([data-processed])').forEach(btn => {
        btn.setAttribute('data-processed', '1');
        const tagsEl = btn.previousElementSibling;
        if (tagsEl && tagsEl.scrollHeight > tagsEl.clientHeight + 2) {
          btn.style.display = 'inline-flex';
          btn.onclick = () => {
            const expanded = tagsEl.classList.toggle('is-expanded');
            btn.textContent = expanded ? btn.getAttribute('data-less') : btn.getAttribute('data-more');
          };
        }
      });
    });

    currentIndex = end;

    if (currentIndex < versesToRender.length) {
      setTimeout(renderNextChunk, 35);
    }
  }

  renderNextChunk();
}

/**
 * renderSuraPage – wraps renderVerseList with pagination controls.
 * Uses the module-level `suraPage` variable and `state.ayahPerPage`.
 *
 * @param {string[]} allKeys  – all verse keys for this sura ("sura:aya")
 * @param {number}   suraId
 * @param {object}   sura     – sura meta object
 */
function renderSuraPage(allKeys, suraId, sura) {
  const perPage = state.ayahPerPage || 25;
  const totalPages = Math.ceil(allKeys.length / perPage);
  // Guard suraPage bounds
  if (suraPage < 1) suraPage = 1;
  if (suraPage > totalPages) suraPage = totalPages;

  const start = (suraPage - 1) * perPage;
  const end   = Math.min(start + perPage, allKeys.length);
  const pageKeys = allKeys.slice(start, end);

  const verseListContainer = document.getElementById('verse-list');
  verseListContainer.innerHTML = `
    <div class="loading-wrap">
      <div class="spinner"></div>
      <div>Loading verses...</div>
    </div>
  `;

  // Build pagination toolbar
  function buildPaginator() {
    // Remove any existing paginator
    const old = document.getElementById('sura-paginator');
    if (old) old.remove();

    const isId   = state.uiLang === 'id';
    const label  = isId ? 'Ayat per halaman' : 'Ayahs per page';
    const of     = isId ? 'dari' : 'of';
    const pageTxt = isId ? 'Halaman' : 'Page';

    const paginator = document.createElement('div');
    paginator.id = 'sura-paginator';
    paginator.className = 'sura-paginator';

    // --- Per-page selector ---
    const selectorHtml = `
      <div class="paginator-per-page">
        <label class="paginator-label" for="ayah-per-page-select">${label}:</label>
        <select id="ayah-per-page-select" class="paginator-select">
          <option value="10"  ${perPage === 10  ? 'selected' : ''}>10</option>
          <option value="25"  ${perPage === 25  ? 'selected' : ''}>25</option>
          <option value="50"  ${perPage === 50  ? 'selected' : ''}>50</option>
        </select>
      </div>`;

    // --- Page info ---
    const infoHtml = `
      <div class="paginator-info">
        <span>${start + 1}–${end} ${of} ${allKeys.length}</span>
      </div>`;

    // --- Prev / page pills / Next ---
    const maxPills = 5;
    let pagesHtml = '';
    if (totalPages > 1) {
      const half  = Math.floor(maxPills / 2);
      let pStart  = Math.max(1, suraPage - half);
      let pEnd    = Math.min(totalPages, pStart + maxPills - 1);
      if (pEnd - pStart < maxPills - 1) pStart = Math.max(1, pEnd - maxPills + 1);

      let pills = '';
      if (pStart > 1) {
        pills += `<button class="paginator-pill" data-page="1">1</button>`;
        if (pStart > 2) pills += `<span class="paginator-ellipsis">…</span>`;
      }
      for (let p = pStart; p <= pEnd; p++) {
        pills += `<button class="paginator-pill${p === suraPage ? ' active' : ''}" data-page="${p}">${p}</button>`;
      }
      if (pEnd < totalPages) {
        if (pEnd < totalPages - 1) pills += `<span class="paginator-ellipsis">…</span>`;
        pills += `<button class="paginator-pill" data-page="${totalPages}">${totalPages}</button>`;
      }

      pagesHtml = `
        <div class="paginator-nav">
          <button class="paginator-btn paginator-prev" id="paginator-prev-btn" ${suraPage <= 1 ? 'disabled' : ''} aria-label="Previous page">
            <svg viewBox="0 0 24 24" width="16" height="16"><path d="M15 18l-6-6 6-6"/></svg>
          </button>
          <div class="paginator-pills">${pills}</div>
          <button class="paginator-btn paginator-next" id="paginator-next-btn" ${suraPage >= totalPages ? 'disabled' : ''} aria-label="Next page">
            <svg viewBox="0 0 24 24" width="16" height="16"><path d="M9 18l6-6-6-6"/></svg>
          </button>
        </div>`;
    }

    paginator.innerHTML = selectorHtml + infoHtml + (pagesHtml || '');

    // Insert paginator just before #sura-nav
    const suraNav = document.getElementById('sura-nav');
    if (suraNav) {
      suraNav.parentNode.insertBefore(paginator, suraNav);
    }

    // Event: change per-page
    const sel = document.getElementById('ayah-per-page-select');
    if (sel) {
      sel.addEventListener('change', () => {
        state.ayahPerPage = Number(sel.value);
        saveSettings();
        suraPage = 1;
        renderSuraPage(allKeys, suraId, sura);
      });
    }

    // Event: prev
    const prevP = document.getElementById('paginator-prev-btn');
    if (prevP) {
      prevP.addEventListener('click', () => {
        if (suraPage > 1) { suraPage--; renderSuraPage(allKeys, suraId, sura); }
      });
    }

    // Event: next
    const nextP = document.getElementById('paginator-next-btn');
    if (nextP) {
      nextP.addEventListener('click', () => {
        if (suraPage < totalPages) { suraPage++; renderSuraPage(allKeys, suraId, sura); }
      });
    }

    // Event: page pills
    paginator.querySelectorAll('.paginator-pill[data-page]').forEach(btn => {
      btn.addEventListener('click', () => {
        const pg = Number(btn.dataset.page);
        if (pg !== suraPage) { suraPage = pg; renderSuraPage(allKeys, suraId, sura); }
      });
    });
  }

  // Render the current page's verses then attach paginator
  renderVerseList(verseListContainer, pageKeys);

  // Scroll to top of verse list on every page change
  requestAnimationFrame(() => {
    verseListContainer.scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // Wait a tick for renderVerseList to kick off, then place paginator
  requestAnimationFrame(buildPaginator);
}

function renderTopicPage(allKeys, tagId, tag) {
  const perPage = state.ayahPerPage || 25;
  const totalPages = Math.ceil(allKeys.length / perPage);
  if (topicPage < 1) topicPage = 1;
  if (topicPage > totalPages) topicPage = totalPages;

  const start = (topicPage - 1) * perPage;
  const end   = Math.min(start + perPage, allKeys.length);
  const pageKeys = allKeys.slice(start, end);

  const container = document.getElementById('topic-results-list');
  container.innerHTML = `
    <div class="loading-wrap">
      <div class="spinner"></div>
      <div>Loading verses...</div>
    </div>
  `;

  function buildPaginator() {
    const placeholder = document.getElementById('topic-paginator-placeholder');
    if (!placeholder) return;
    placeholder.innerHTML = '';

    if (allKeys.length === 0) return;

    const isId   = state.uiLang === 'id';
    const label  = isId ? 'Ayat per halaman' : 'Ayahs per page';
    const of     = isId ? 'dari' : 'of';

    const paginator = document.createElement('div');
    paginator.className = 'sura-paginator';

    const selectorHtml = `
      <div class="paginator-per-page">
        <label class="paginator-label" for="topic-per-page-select">${label}:</label>
        <select id="topic-per-page-select" class="paginator-select">
          <option value="10"  ${perPage === 10  ? 'selected' : ''}>10</option>
          <option value="25"  ${perPage === 25  ? 'selected' : ''}>25</option>
          <option value="50"  ${perPage === 50  ? 'selected' : ''}>50</option>
        </select>
      </div>`;

    const infoHtml = `
      <div class="paginator-info">
        <span>${start + 1}–${end} ${of} ${allKeys.length}</span>
      </div>`;

    const maxPills = 5;
    let pagesHtml = '';
    if (totalPages > 1) {
      const half  = Math.floor(maxPills / 2);
      let pStart  = Math.max(1, topicPage - half);
      let pEnd    = Math.min(totalPages, pStart + maxPills - 1);
      if (pEnd - pStart < maxPills - 1) pStart = Math.max(1, pEnd - maxPills + 1);

      let pills = '';
      if (pStart > 1) {
        pills += `<button class="paginator-pill" data-page="1">1</button>`;
        if (pStart > 2) pills += `<span class="paginator-ellipsis">…</span>`;
      }
      for (let p = pStart; p <= pEnd; p++) {
        pills += `<button class="paginator-pill${p === topicPage ? ' active' : ''}" data-page="${p}">${p}</button>`;
      }
      if (pEnd < totalPages) {
        if (pEnd < totalPages - 1) pills += `<span class="paginator-ellipsis">…</span>`;
        pills += `<button class="paginator-pill" data-page="${totalPages}">${totalPages}</button>`;
      }

      pagesHtml = `
        <div class="paginator-nav">
          <button class="paginator-btn paginator-prev" id="topic-prev-btn" ${topicPage <= 1 ? 'disabled' : ''} aria-label="Previous page">
            <svg viewBox="0 0 24 24" width="16" height="16"><path d="M15 18l-6-6 6-6"/></svg>
          </button>
          <div class="paginator-pills">${pills}</div>
          <button class="paginator-btn paginator-next" id="topic-next-btn" ${topicPage >= totalPages ? 'disabled' : ''} aria-label="Next page">
            <svg viewBox="0 0 24 24" width="16" height="16"><path d="M9 18l6-6-6-6"/></svg>
          </button>
        </div>`;
    }

    paginator.innerHTML = selectorHtml + infoHtml + (pagesHtml || '');
    placeholder.appendChild(paginator);

    const sel = document.getElementById('topic-per-page-select');
    if (sel) {
      sel.addEventListener('change', () => {
        state.ayahPerPage = Number(sel.value);
        saveSettings();
        topicPage = 1;
        renderTopicPage(allKeys, tagId, tag);
      });
    }

    const prevP = document.getElementById('topic-prev-btn');
    if (prevP) {
      prevP.addEventListener('click', () => {
        if (topicPage > 1) { topicPage--; renderTopicPage(allKeys, tagId, tag); }
      });
    }

    const nextP = document.getElementById('topic-next-btn');
    if (nextP) {
      nextP.addEventListener('click', () => {
        if (topicPage < totalPages) { topicPage++; renderTopicPage(allKeys, tagId, tag); }
      });
    }

    paginator.querySelectorAll('.paginator-pill[data-page]').forEach(btn => {
      btn.addEventListener('click', () => {
        const pg = Number(btn.dataset.page);
        if (pg !== topicPage) { topicPage = pg; renderTopicPage(allKeys, tagId, tag); }
      });
    });
  }

  renderVerseList(container, pageKeys);

  // Scroll to top on topic page change
  requestAnimationFrame(() => {
    container.scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  requestAnimationFrame(buildPaginator);
}

function renderSearchPage(allKeys, query) {
  const perPage = state.ayahPerPage || 25;
  const totalPages = Math.ceil(allKeys.length / perPage);
  if (searchPage < 1) searchPage = 1;
  if (searchPage > totalPages) searchPage = totalPages;

  const start = (searchPage - 1) * perPage;
  const end   = Math.min(start + perPage, allKeys.length);
  const pageKeys = allKeys.slice(start, end);

  const container = document.getElementById('search-results-list');
  container.innerHTML = `
    <div class="loading-wrap">
      <div class="spinner"></div>
      <div>Loading verses...</div>
    </div>
  `;

  function buildPaginator() {
    const placeholder = document.getElementById('search-paginator-placeholder');
    if (!placeholder) return;
    placeholder.innerHTML = '';

    if (allKeys.length === 0) return;

    const isId   = state.uiLang === 'id';
    const label  = isId ? 'Ayat per halaman' : 'Ayahs per page';
    const of     = isId ? 'dari' : 'of';

    const paginator = document.createElement('div');
    paginator.className = 'sura-paginator';

    const selectorHtml = `
      <div class="paginator-per-page">
        <label class="paginator-label" for="search-per-page-select">${label}:</label>
        <select id="search-per-page-select" class="paginator-select">
          <option value="10"  ${perPage === 10  ? 'selected' : ''}>10</option>
          <option value="25"  ${perPage === 25  ? 'selected' : ''}>25</option>
          <option value="50"  ${perPage === 50  ? 'selected' : ''}>50</option>
        </select>
      </div>`;

    const infoHtml = `
      <div class="paginator-info">
        <span>${start + 1}–${end} ${of} ${allKeys.length}</span>
      </div>`;

    const maxPills = 5;
    let pagesHtml = '';
    if (totalPages > 1) {
      const half  = Math.floor(maxPills / 2);
      let pStart  = Math.max(1, searchPage - half);
      let pEnd    = Math.min(totalPages, pStart + maxPills - 1);
      if (pEnd - pStart < maxPills - 1) pStart = Math.max(1, pEnd - maxPills + 1);

      let pills = '';
      if (pStart > 1) {
        pills += `<button class="paginator-pill" data-page="1">1</button>`;
        if (pStart > 2) pills += `<span class="paginator-ellipsis">…</span>`;
      }
      for (let p = pStart; p <= pEnd; p++) {
        pills += `<button class="paginator-pill${p === searchPage ? ' active' : ''}" data-page="${p}">${p}</button>`;
      }
      if (pEnd < totalPages) {
        if (pEnd < totalPages - 1) pills += `<span class="paginator-ellipsis">…</span>`;
        pills += `<button class="paginator-pill" data-page="${totalPages}">${totalPages}</button>`;
      }

      pagesHtml = `
        <div class="paginator-nav">
          <button class="paginator-btn paginator-prev" id="search-prev-btn" ${searchPage <= 1 ? 'disabled' : ''} aria-label="Previous page">
            <svg viewBox="0 0 24 24" width="16" height="16"><path d="M15 18l-6-6 6-6"/></svg>
          </button>
          <div class="paginator-pills">${pills}</div>
          <button class="paginator-btn paginator-next" id="search-next-btn" ${searchPage >= totalPages ? 'disabled' : ''} aria-label="Next page">
            <svg viewBox="0 0 24 24" width="16" height="16"><path d="M9 18l6-6-6-6"/></svg>
          </button>
        </div>`;
    }

    paginator.innerHTML = selectorHtml + infoHtml + (pagesHtml || '');
    placeholder.appendChild(paginator);

    const sel = document.getElementById('search-per-page-select');
    if (sel) {
      sel.addEventListener('change', () => {
        state.ayahPerPage = Number(sel.value);
        saveSettings();
        searchPage = 1;
        renderSearchPage(allKeys, query);
      });
    }

    const prevP = document.getElementById('search-prev-btn');
    if (prevP) {
      prevP.addEventListener('click', () => {
        if (searchPage > 1) { searchPage--; renderSearchPage(allKeys, query); }
      });
    }

    const nextP = document.getElementById('search-next-btn');
    if (nextP) {
      nextP.addEventListener('click', () => {
        if (searchPage < totalPages) { searchPage++; renderSearchPage(allKeys, query); }
      });
    }

    paginator.querySelectorAll('.paginator-pill[data-page]').forEach(btn => {
      btn.addEventListener('click', () => {
        const pg = Number(btn.dataset.page);
        if (pg !== searchPage) { searchPage = pg; renderSearchPage(allKeys, query); }
      });
    });
  }

  renderVerseList(container, pageKeys, query);

  // Scroll to top on search page change
  requestAnimationFrame(() => {
    container.scrollIntoView({ behavior: 'smooth', block: 'start' });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  requestAnimationFrame(buildPaginator);
}

function resolveTafsirText(data, verseKey) {
  if (!data) return '';
  if (data[verseKey]) return data[verseKey];

  // Resolve ranges for grouped commentaries (like Ibn Kathir)
  const [sura, aya] = verseKey.split(':').map(Number);
  let bestAya = -1;

  for (const key in data) {
    const [sKey, aKey] = key.split(':').map(Number);
    if (sKey === sura && aKey <= aya) {
      if (aKey > bestAya) {
        bestAya = aKey;
      }
    }
  }

  if (bestAya !== -1) {
    return data[`${sura}:${bestAya}`];
  }
  return '';
}

/**
 * Wraps layer text in a truncatable container with a "Show more" button.
 * The text is clamped to 10 lines by default via CSS.
 */
function wrapLayerText(text) {
  const moreLabel = state.uiLang === 'id' ? 'Selengkapnya ▼' : 'Show more ▼';
  return `<div class="verse-layer-text is-clamped">${text}</div>
          <button class="verse-layer-more" style="display:none">${moreLabel}</button>`;
}

// --- Shared text highlight & query match helpers ---
// Curated map of common Quranic/Islamic transliteration root & variant mappings
const KNOWN_RELATED_MAP = {
  'hanif': ['hanifah', 'hanifan'],
  'hanifah': ['hanif'],
  'hanifan': ['hanif'],
  'salat': ['sholat'],
  'sholat': ['salat'],
  'zakat': ['jakat'],
  'jakat': ['zakat'],
  'mushaf': ['moshaf', 'masahif'],
  'moshaf': ['mushaf'],
  'asbabun nuzul': ['asbab nuzul'],
  'asbab nuzul': ['asbabun nuzul'],
  'rijal': ['rajul'],
  'rajul': ['rijal'],
  'tawrat': ['taurat', 'torah'],
  'taurat': ['tawrat', 'torah'],
  'injil': ['injel', 'gospel'],
  'furqan': ['furqaan']
};

function getRelatedSearchTerms(query) {
  if (!query) return [];
  const q = query.toLowerCase().trim();
  const terms = new Set();

  // 1. Direct dictionary lookup for full query
  if (KNOWN_RELATED_MAP[q]) {
    KNOWN_RELATED_MAP[q].forEach(t => terms.add(t));
  }

  // 2. Check individual words for multi-word queries
  const words = q.split(/\s+/);
  words.forEach(w => {
    if (KNOWN_RELATED_MAP[w]) {
      KNOWN_RELATED_MAP[w].forEach(r => {
        terms.add(q.replace(w, r));
      });
    }
  });

  return Array.from(terms).filter(t => t !== q).slice(0, 3);
}

function textMatchesQuery(text, query) {
  if (!text) return false;
  const qLower = query.toLowerCase().trim();
  const exactPhrases = [];
  const broadWords = [];
  const regexParse = /"([^"]+)"|(\S+)/g;
  let match;
  while ((match = regexParse.exec(qLower)) !== null) {
    if (match[1]) exactPhrases.push(match[1].trim());
    else if (match[2]) broadWords.push(match[2].trim());
  }

  const textLower = text.toLowerCase();
  
  // Match if ANY exact phrase matches
  for (const ep of exactPhrases) {
    if (textLower.includes(ep)) return true;
  }
  
  // Match if ANY broad word (or curated dictionary variant) matches
  for (const bw of broadWords) {
    if (bw.length < 2) continue;
    if (textLower.includes(bw)) return true;
    if (KNOWN_RELATED_MAP[bw]) {
      for (const rel of KNOWN_RELATED_MAP[bw]) {
        if (textLower.includes(rel)) return true;
      }
    }
  }

  return false;
}

function escapeRegExpGlobal(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function highlightSnippet(text, q) {
  if (!text) return '';
  // Clean tags without breaking inner word tokens
  const cleanText = text.replace(/<[^>]*>/g, '');
  const qLower = q.toLowerCase().trim();

  // Parse exact phrases and broad words to highlight
  const exactPhrases = [];
  const broadWords = [];
  const regexParse = /"([^"]+)"|(\S+)/g;
  let match;
  while ((match = regexParse.exec(qLower)) !== null) {
    if (match[1]) exactPhrases.push(match[1].trim());
    else if (match[2]) broadWords.push(match[2].trim());
  }

  const highlightTerms = [...exactPhrases, ...broadWords].filter(t => t.length >= 2);
  const extraStems = [];
  for (const t of highlightTerms) {
    if (KNOWN_RELATED_MAP[t]) {
      KNOWN_RELATED_MAP[t].forEach(r => extraStems.push(r));
    }
  }
  extraStems.forEach(s => {
    if (s.length >= 2 && !highlightTerms.includes(s)) highlightTerms.push(s);
  });

  if (highlightTerms.length === 0) return cleanText.slice(0, 150) + '...';

  // Find the first matching term index to center the snippet
  let bestIdx = -1;
  let termLen = 0;
  for (const term of highlightTerms) {
    const idx = cleanText.toLowerCase().indexOf(term);
    if (idx !== -1) {
      bestIdx = idx;
      termLen = term.length;
      break;
    }
  }
  if (bestIdx === -1) return cleanText.slice(0, 150) + '...';

  let startIdx = 0, endIdx = cleanText.length, prefix = '', suffix = '';
  if (cleanText.length > 200) {
    startIdx = Math.max(0, bestIdx - 60);
    endIdx   = Math.min(cleanText.length, bestIdx + termLen + 80);
    if (startIdx > 0) prefix = '... ';
    if (endIdx < cleanText.length) suffix = ' ...';
  }

  const snippet = cleanText.slice(startIdx, endIdx);
  
  // Sort longest first to prioritize matching longer terms
  highlightTerms.sort((a, b) => b.length - a.length);
  const regexPattern = `(${highlightTerms.map(t => escapeRegExpGlobal(t)).join('|')})(?![^<>]*>)`;
  const regex = new RegExp(regexPattern, 'gi');
  return prefix + snippet.replace(regex, '<mark class="search-highlight">$1</mark>') + suffix;
}

// Module-level alias — needed by createVerseCard (tag & transliteration highlighting) and getSearchExcerpts
function highlightText(text, q) {
  return highlightSnippet(text, q);
}

function getSearchExcerpts(verseKey, query) {
  if (!query) return '';
  const isId = state.uiLang === 'id';
  const qLower = query.toLowerCase();
  let html = '';
  const seenSources = new Set();

  const typeLabel = {
    translations:   isId ? 'Terjemahan' : 'Translation',
    tafsirs:        'Tafsir',
    asbabun_nuzul:  'Asbabun Nuzul'
  };
  const slotMap = {
    translations:   ['trans1', 'trans2'],
    tafsirs:        ['tafsir1', 'tafsir2'],
    asbabun_nuzul:  ['nuzul1',  'nuzul2']
  };

  const createExcerptRow = (sourceId, type, displayName, typeClass, verseKey, text, isSnippet = false) => {
    const [slot1, slot2] = slotMap[type] || [];
    let setBtns = '';
    if (slot1 && slot2 && sourceId) {
      const btn1Label = isId ? `Pasang sebagai ${typeLabel[type]} 1` : `Set as ${typeLabel[type]} 1`;
      const btn2Label = isId ? `Pasang sebagai ${typeLabel[type]} 2` : `Set as ${typeLabel[type]} 2`;
      setBtns = `
        <span class="excerpt-set-btns">
          <button class="btn-set-source" onclick="setSearchSource('${slot1}','${sourceId}','${verseKey}')">${btn1Label}</button>
          <button class="btn-set-source" onclick="setSearchSource('${slot2}','${sourceId}','${verseKey}')">${btn2Label}</button>
        </span>
      `;
    }

    const titleLink = (sourceId && type)
      ? `<a class="search-excerpt-source ${typeClass} search-excerpt-source-link" href="#" title="Open ayah with this source" onclick="return goToVerseWithSource('${sourceId}','${type}','${verseKey}')">${displayName}</a>`
      : `<span class="search-excerpt-source ${typeClass}">${displayName}</span>`;

    const snippetText = isSnippet ? `...${highlightText(text, query)}...` : highlightText(text, query);

    return `
      <div class="search-excerpt-item">
        <div class="search-excerpt-source-row">
          ${titleLink}
          ${setBtns}
        </div>
        <div class="search-excerpt-text">${snippetText}</div>
      </div>
    `;
  };

  if (searchContextSnippets && searchContextSnippets[verseKey]) {
    let snippets = [];
    try {
      const raw = searchContextSnippets[verseKey];
      snippets = typeof raw === 'string' ? JSON.parse(raw) : raw;
    } catch (_) {}

    if (Array.isArray(snippets) && snippets.length > 0) {
      snippets.forEach(s => {
        if (s && s.text) {
          const typeClass = s.source_type === 'Tafsir' ? 'tafsir-source' : 
                            s.source_type === 'Asbabun Nuzul' ? 'nuzul-source' : 'translation-source';

          let displayName = s.source_name || '';
          let sourceId = s.source_id || '';
          let type = s.source_type === 'Tafsir' ? 'tafsirs' :
                     s.source_type === 'Asbabun Nuzul' ? 'asbabun_nuzul' : 'translations';

          const sNameClean = displayName.toLowerCase().replace(/[^a-z0-9]/g, '');
          const sIdClean = sourceId.toLowerCase().replace(/[^a-z0-9]/g, '');

          let matchedRegistryItem = null;
          const allReg = [
            ...(db.registry?.translations || []).map(r => ({ ...r, type: 'translations' })),
            ...(db.registry?.tafsirs || []).map(r => ({ ...r, type: 'tafsirs' })),
            ...(db.registry?.asbabun_nuzul || []).map(r => ({ ...r, type: 'asbabun_nuzul' }))
          ];

          for (const reg of allReg) {
            const regIdClean = reg.id.toLowerCase().replace(/[^a-z0-9]/g, '');
            const regNameClean = reg.name.toLowerCase().replace(/[^a-z0-9]/g, '');
            if (sIdClean && regIdClean === sIdClean) { matchedRegistryItem = reg; break; }
            if (sNameClean && (regIdClean === sNameClean || regNameClean === sNameClean)) { matchedRegistryItem = reg; break; }
          }

          if (matchedRegistryItem) {
            displayName = matchedRegistryItem.name;
            sourceId = matchedRegistryItem.id;
            type = matchedRegistryItem.type;
            seenSources.add(matchedRegistryItem.id);
            seenSources.add(matchedRegistryItem.name.toLowerCase());
          }

          if (displayName) seenSources.add(displayName.toLowerCase());
          if (s.source_name) seenSources.add(s.source_name.toLowerCase());
          if (s.source_id) seenSources.add(s.source_id);

          html += createExcerptRow(sourceId, type, displayName, typeClass, verseKey, s.text, true);
        }
      });
    }
  }

  // Check all translations
  db.registry.translations.forEach(t => {
    if (seenSources.has(t.id) || seenSources.has(t.name.toLowerCase())) return;
    const data = db.cache.get(t.file);
    if (data && data[verseKey]) {
      const text = data[verseKey];
      if (textMatchesQuery(text, query)) {
        seenSources.add(t.id);
        seenSources.add(t.name.toLowerCase());
        html += createExcerptRow(t.id, 'translations', t.name, 'translation-source', verseKey, text, false);
      }
    }
  });

  // Check all tafsirs
  db.registry.tafsirs.forEach(t => {
    if (seenSources.has(t.id) || seenSources.has(t.name.toLowerCase())) return;
    const data = getTafsirData(t);
    if (data) {
      const text = resolveTafsirText(data, verseKey);
      if (textMatchesQuery(text, query)) {
        seenSources.add(t.id);
        seenSources.add(t.name.toLowerCase());
        html += createExcerptRow(t.id, 'tafsirs', t.name, 'tafsir-source', verseKey, text, false);
      }
    }
  });

  // Check all asbabun nuzul
  db.registry.asbabun_nuzul.forEach(n => {
    if (seenSources.has(n.id) || seenSources.has(n.name.toLowerCase())) return;
    const data = db.cache.get(n.file);
    if (data && data[verseKey]) {
      const text = data[verseKey];
      if (textMatchesQuery(text, query)) {
        seenSources.add(n.id);
        seenSources.add(n.name.toLowerCase());
        html += createExcerptRow(n.id, 'asbabun_nuzul', n.name, 'nuzul-source', verseKey, text, false);
      }
    }
  });

  // Check topic tags
  if (db.verseTags && db.verseTags[verseKey]) {
    const tagIds = db.verseTags[verseKey];
    tagIds.forEach(id => {
      const name = tagLookup.get(id) || id;
      if (textMatchesQuery(name, query)) {
        const tagSourceTitle = isId ? 'Topik / Tag' : 'Topic Tag';
        html += `
          <div class="search-excerpt-item">
            <a class="search-excerpt-source search-excerpt-source-link" href="#topic/${id}" title="Open topic" style="background:#e0f2fe;color:#0369a1;border-color:#bae6fd;">${tagSourceTitle}</a>
            <div class="search-excerpt-text">${highlightText(name, query)}</div>
          </div>
        `;
      }
    });
  }

  if (html) {
    const title = isId ? 'Kecocokan Pencarian:' : 'Search Matches:';
    return `
      <div class="search-excerpts-box">
        <div class="search-excerpts-title">${title}</div>
        <div class="search-excerpts-list">${html}</div>
      </div>
    `;
  }

  // No match visible in currently loaded sources —
  // check matching inactive sources in the index
  if (db.searchIndex) {
    const qLower = query.toLowerCase().trim();

    // Parse query the same way as the search engine:
    // extract exact phrases (inside quotes) and bare broad words
    const exactPhrases = [];
    const broadWords   = [];
    const rxParse = /"([^"]+)"|(\S+)/g;
    let m;
    while ((m = rxParse.exec(qLower)) !== null) {
      if (m[1]) exactPhrases.push(m[1].trim());       // quoted phrase
      else if (m[2]) broadWords.push(m[2].trim());    // bare word
    }

    // Flatten into individual clean words for index lookup
    // (exact phrase "mercy of god" → ["mercy","of","god"])
    const indexLookupWords = [
      ...exactPhrases.flatMap(ep => ep.split(/\s+/).filter(w => w.length >= 2)),
      ...broadWords.filter(w => w.length >= 2)
    ];
    const effectiveWords = indexLookupWords.length ? indexLookupWords : [qLower];

    // Check if the index actually has this verse for our query words
    const matchedIndices = new Set();
    for (const qw of effectiveWords) {
      for (const word in db.searchIndex) {
        if (word.includes(qw)) {
          const entryStr = db.searchIndex[word];
          if (entryStr) {
            const pairs = entryStr.split(',');
            for (const pair of pairs) {
              const parts = pair.split('_');
              if (parts[0] === verseKey) {
                for (let i = 1; i < parts.length; i++) {
                  matchedIndices.add(Number(parts[i]));
                }
              }
            }
          }
        }
      }
    }

    const allRegistrySources = [
      ...db.registry.translations,
      ...db.registry.tafsirs,
      ...db.registry.asbabun_nuzul
    ];

    const activeFiles = new Set();
    const activeIds = [
      state.activeTranslation1, state.activeTranslation2,
      state.activeTafsir1, state.activeTafsir2,
      state.activeNuzul1, state.activeNuzul2
    ];
    for (const src of allRegistrySources) {
      if (activeIds.includes(src.id)) {
        activeFiles.add(src.file);
      }
    }

    const inactiveMatchedNames = [];
    for (const idx of matchedIndices) {
      const src = allRegistrySources[idx];
      if (src && !activeFiles.has(src.file)) {
        inactiveMatchedNames.push(src.name);
      }
    }

    if (inactiveMatchedNames.length > 0) {
      const isId = state.uiLang === 'id';
      const msg = isId
        ? `Ditemukan kecocokan di: <strong>${inactiveMatchedNames.join(', ')}</strong>`
        : `Found match in: <strong>${inactiveMatchedNames.join(', ')}</strong>`;
      const btnLabel = isId ? '🔍 Lihat teks yang cocok...' : '🔍 View matching source...';

      // Encode args safely for inline onclick
      const vkAttr  = verseKey.replace(/'/g, '');
      const qAttr   = query.replace(/'/g, '').replace(/"/g, '');
      return `
        <div class="search-excerpts-box search-excerpts-other">
          <div class="search-excerpt-item">
            <div class="search-excerpt-hint" style="margin-bottom: 6px;">${msg}</div>
            <button class="btn-find-source" onclick="findMatchingSource('${vkAttr}','${qAttr}',this)">${btnLabel}</button>
          </div>
        </div>
      `;
    }
  }

  return '';
}

/**
 * Async: scans all registry sources for `query` in `verseKey`,
 * renders matched excerpts as clickable items with "Set as active" buttons.
 * Called inline from the "Find matching source" button in search result cards.
 */
async function findMatchingSource(verseKey, query, btn) {
  const box = btn.closest('.search-excerpts-other');
  const isId = state.uiLang === 'id';
  box.innerHTML = `<div class="loading-wrap" style="padding:8px 0;"><div class="spinner" style="width:16px;height:16px;"></div><span style="font-size:0.8rem;margin-left:8px;">${isId ? 'Mencari...' : 'Searching sources...'}</span></div>`;

  const qLower = query.toLowerCase();
  const found  = [];

  // Load all source types in parallel then scan
  const allSources = [
    ...db.registry.translations.map(s => ({ src: s, type: 'translations' })),
    ...db.registry.tafsirs.map(s => ({ src: s, type: 'tafsirs' })),
    ...db.registry.asbabun_nuzul.map(s => ({ src: s, type: 'asbabun_nuzul' }))
  ];

  await Promise.all(allSources.map(({ src }) =>
    src.chunked ? Promise.resolve(null) : db.getResource(src.file).catch(() => null)
  ));

  for (const { src, type } of allSources) {
    const data = type === 'tafsirs' ? getTafsirData(src) : db.cache.get(src.file);
    if (!data) continue;
    const text = type === 'tafsirs'
      ? resolveTafsirText(data, verseKey)
      : (data[verseKey] || '');
    if (textMatchesQuery(text, query)) {
      found.push({ src, type, text });
    }
  }

  if (found.length === 0) {
    box.innerHTML = `<p class="search-excerpt-hint" style="padding:4px 0;">${isId ? 'Tidak ditemukan di sumber lain.' : 'Not found in any other source.'}</p>`;
    return;
  }

  // Build label suffix map
  const typeLabel = {
    translations:   isId ? 'Terjemahan' : 'Translation',
    tafsirs:        'Tafsir',
    asbabun_nuzul:  isId ? 'Asbabun Nuzul' : 'Asbabun Nuzul'
  };
  const slotMap = {
    translations:   ['trans1', 'trans2'],
    tafsirs:        ['tafsir1', 'tafsir2'],
    asbabun_nuzul:  ['nuzul1',  'nuzul2']
  };
  const cssClass = {
    translations:  'translation-source',
    tafsirs:       'tafsir-source',
    asbabun_nuzul: 'nuzul-source'
  };

  let innerHtml = `<div class="search-excerpts-title">${isId ? 'Ditemukan di:' : 'Found in:'}</div><div class="search-excerpts-list">`;

  for (const { src, type, text } of found) {
    const [slot1, slot2] = slotMap[type];
    const btn1Label = isId ? `Pasang sebagai ${typeLabel[type]} 1` : `Set as ${typeLabel[type]} 1`;
    const btn2Label = isId ? `Pasang sebagai ${typeLabel[type]} 2` : `Set as ${typeLabel[type]} 2`;
    innerHtml += `
      <div class="search-excerpt-item">
        <div class="search-excerpt-source-row">
          <a class="search-excerpt-source ${cssClass[type]} search-excerpt-source-link" href="#" title="Open ayah with this source" onclick="return goToVerseWithSource('${src.id}','${type}','${verseKey}')">${src.name}</a>
          <span class="excerpt-set-btns">
            <button class="btn-set-source" onclick="setSearchSource('${slot1}','${src.id}','${verseKey}')">${btn1Label}</button>
            <button class="btn-set-source" onclick="setSearchSource('${slot2}','${src.id}','${verseKey}')">${btn2Label}</button>
          </span>
        </div>
        <div class="search-excerpt-text">${highlightSnippet(text, query)}</div>
      </div>`;
  }

  innerHtml += '</div>';
  box.className = 'search-excerpts-box';
  box.innerHTML = innerHtml;
}

/**
 * Sets a source as the active translation/tafsir/nuzul slot,
 * saves settings, and re-renders the current search view.
 */
async function setSearchSource(slot, sourceId, verseKey) {
  const stateMap = {
    trans1:  { key: 'activeTranslation1',  pref: 'trans1UserPref'  },
    trans2:  { key: 'activeTranslation2',  pref: 'trans2UserPref'  },
    tafsir1: { key: 'activeTafsir1',       pref: 'tafsir1UserPref' },
    tafsir2: { key: 'activeTafsir2',       pref: 'tafsir2UserPref' },
    nuzul1:  { key: 'activeNuzul1',        pref: 'nuzul1UserPref'  },
    nuzul2:  { key: 'activeNuzul2',        pref: 'nuzul2UserPref'  }
  };
  const mapping = stateMap[slot];
  if (!mapping) return;

  state[mapping.key] = sourceId;
  state[mapping.pref] = true;  // Prevent auto-reset on language change
  saveSettings();

  // Sync the comparison panel dropdown if visible
  const sel = document.getElementById(`${slot}-select`);
  if (sel) sel.value = sourceId;

  await ensureActiveDatasets();
  triggerRouting();          // Re-render the whole page so all cards update
}

/**
 * Navigate to the ayah detail page with the clicked source set as the primary slot.
 * Called from clickable source name labels in search result excerpts.
 */
function goToVerseWithSource(sourceId, sourceType, verseKey) {
  const slotKeyMap = {
    translations:  { key: 'activeTranslation1', pref: 'trans1UserPref'  },
    tafsirs:       { key: 'activeTafsir1',       pref: 'tafsir1UserPref' },
    asbabun_nuzul: { key: 'activeNuzul1',        pref: 'nuzul1UserPref'  }
  };
  const mapping = slotKeyMap[sourceType];
  if (mapping) {
    state[mapping.key] = sourceId;
    state[mapping.pref] = true; // Lock this choice, don't auto-reset on language change
    saveSettings();
  }
  const [suraId, ayahNum] = verseKey.split(':');
  window.location.hash = `#sura/${suraId}/verse/${ayahNum}`;
  return false; // Prevent default anchor navigation
}

// Expose handlers to global window scope so inline onclick works
window.findMatchingSource = findMatchingSource;
window.setSearchSource = setSearchSource;
window.goToVerseWithSource = goToVerseWithSource;

function createVerseCard(verseKey, isDetailMode = false, highlightQuery = '') {
  const card = document.createElement('div');
  card.className = 'verse-card';
  card.id = `v-${verseKey.replace(':', '-')}`;

  const arabicText = db.quranArabic[verseKey] || '';
  const [suraId, ayaId] = verseKey.split(':');

  // Resolve sura name for the ref label
  const suraMeta = db.suraList ? db.suraList.find(s => s.id === Number(suraId)) : null;
  const suraName = suraMeta
    ? (state.uiLang === 'id' ? suraMeta.name_id : suraMeta.name_en)
    : `Sura ${suraId}`;
  const refLabel = `${suraName} : ${ayaId}`;

  const similarityScore = searchSimilarityScores[verseKey];
  const similarityBadge = (similarityScore !== undefined)
    ? `<span class="similarity-badge" style="font-size: 0.7rem; background: var(--accent-light, rgba(16, 185, 129, 0.1)); color: var(--accent); font-weight: 600; padding: 2px 6px; border-radius: 4px; margin-left: 8px; border: 1px solid rgba(16, 185, 129, 0.2);">AI Match: ${(similarityScore * 100).toFixed(0)}%</span>`
    : '';

  // Card Header
  const isBookmarked = bookmarks.has(verseKey);
  let headerHtml = `
    <div class="verse-card-header">
      <div style="display:flex;align-items:center;gap:2px;">
        <a href="#sura/${suraId}/verse/${ayaId}" class="verse-ref-link verse-ref">${refLabel}</a>
        ${similarityBadge}
      </div>
      <div class="verse-actions">
        <button class="btn-icon btn-play-ayah" data-key="${verseKey}" title="Play Ayah audio">
          <svg class="play-icon" viewBox="0 0 24 24" fill="currentColor" style="width: 18px; height: 18px;"><path d="M8 5v14l11-7z"/></svg>
          <svg class="pause-icon" viewBox="0 0 24 24" fill="currentColor" style="width: 18px; height: 18px; display: none;"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
        </button>
        <button class="btn-icon btn-bookmark" data-key="${verseKey}" title="Bookmark verse" aria-label="Bookmark" aria-pressed="${isBookmarked}">
          <svg viewBox="0 0 24 24" fill="${isBookmarked ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="2" style="width:16px;height:16px;"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>
        </button>
        <button class="btn-icon btn-copy" data-key="${verseKey}" title="Copy verse text">
          <svg viewBox="0 0 24 24"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
        </button>
      </div>
    </div>
  `;

  // Arabic Body
  let bodyHtml = `
    <div class="verse-card-body">
      <div class="verse-arabic" lang="ar">${arabicText}</div>
  `;

  // Transliteration — always rendered right below Arabic (if enabled)
  if (state.layers.transliteration && state.activeTransliteration) {
    const trInfo = db.registry.transliterations && db.registry.transliterations.find(t => t.id === state.activeTransliteration);
    if (trInfo) {
      const trData = db.cache.get(trInfo.file);
      const trText = trData ? trData[verseKey] : '';
      if (trText) {
        const renderedTr = highlightQuery ? highlightText(trText, highlightQuery) : trText;
        bodyHtml += `<div class="verse-transliteration">${renderedTr}</div>`;
      }
    }
  }

  if (!isDetailMode) {
    // Simple Mode: Arabic, one translation, topic tags, and footer link
    if (state.layers.trans1 && state.activeTranslation1) {
      const tInfo = db.registry.translations.find(t => t.id === state.activeTranslation1);
      if (tInfo) {
        const data = db.cache.get(tInfo.file);
        const text = data ? data[verseKey] : '';
        if (text) {
          bodyHtml += `
            <div class="verse-layer">
              <span class="verse-layer-label translation">${tInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    if (highlightQuery) {
      bodyHtml += getSearchExcerpts(verseKey, highlightQuery);
    }

    // Topic Tags
    if (state.layers.tags && db.verseTags && db.verseTags[verseKey]) {
      const tagIds = db.verseTags[verseKey];
      if (tagIds && tagIds.length > 0) {
        const moreLabel = state.uiLang === 'id' ? 'Selengkapnya ▼' : 'Show more ▼';
        const lessLabel = state.uiLang === 'id' ? 'Lebih sedikit ▲' : 'Show less ▲';
        let tagsHtml = '<div class="verse-tags tags-collapsible">';
        tagIds.forEach(id => {
          const name = tagLookup.get(id) || id;
          const displayName = highlightQuery ? highlightText(name, highlightQuery) : name;
          tagsHtml += `<a href="#topic/${id}" class="verse-tag">${displayName}</a>`;
        });
        tagsHtml += `</div><button class="tags-more-btn" style="display:none" data-more="${moreLabel}" data-less="${lessLabel}">${moreLabel}</button>`;
        bodyHtml += tagsHtml;
      }
    }

    bodyHtml += `
      <div class="verse-card-footer">
        <a href="#sura/${suraId}/verse/${ayaId}" class="btn-study-link">
          <span>Kaji Ayah / Study Detail</span>
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
        </a>
      </div>
    `;
  } else {
    // Detail Mode: Render all toggled comparison layers + sharing buttons
    // Primary Translation
    if (state.layers.trans1 && state.activeTranslation1) {
      const tInfo = db.registry.translations.find(t => t.id === state.activeTranslation1);
      if (tInfo) {
        const data = db.cache.get(tInfo.file);
        const text = data ? data[verseKey] : '';
        if (text) {
          bodyHtml += `
            <div class="verse-layer">
              <span class="verse-layer-label translation">${tInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    // Secondary Translation
    if (state.layers.trans2 && state.activeTranslation2) {
      const tInfo = db.registry.translations.find(t => t.id === state.activeTranslation2);
      if (tInfo) {
        const data = db.cache.get(tInfo.file);
        const text = data ? data[verseKey] : '';
        if (text) {
          bodyHtml += `
            <div class="verse-layer">
              <span class="verse-layer-label translation">${tInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    // Primary Tafsir
    if (state.layers.tafsir1 && state.activeTafsir1) {
      const tInfo = db.registry.tafsirs.find(t => t.id === state.activeTafsir1);
      if (tInfo) {
        const data = getTafsirData(tInfo);
        const text = resolveTafsirText(data, verseKey);
        if (text) {
          bodyHtml += `
            <div class="verse-layer tafsir">
              <span class="verse-layer-label tafsir">${tInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    // Secondary Tafsir
    if (state.layers.tafsir2 && state.activeTafsir2) {
      const tInfo = db.registry.tafsirs.find(t => t.id === state.activeTafsir2);
      if (tInfo) {
        const data = getTafsirData(tInfo);
        const text = resolveTafsirText(data, verseKey);
        if (text) {
          bodyHtml += `
            <div class="verse-layer tafsir">
              <span class="verse-layer-label tafsir">${tInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    // Nuzul 1
    if (state.layers.nuzul1 && state.activeNuzul1) {
      const nInfo = db.registry.asbabun_nuzul.find(n => n.id === state.activeNuzul1);
      if (nInfo) {
        const data = db.cache.get(nInfo.file);
        const text = data ? data[verseKey] : '';
        if (text) {
          bodyHtml += `
            <div class="verse-layer nuzul">
              <span class="verse-layer-label nuzul">${nInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    // Nuzul 2
    if (state.layers.nuzul2 && state.activeNuzul2) {
      const nInfo = db.registry.asbabun_nuzul.find(n => n.id === state.activeNuzul2);
      if (nInfo) {
        const data = db.cache.get(nInfo.file);
        const text = data ? data[verseKey] : '';
        if (text) {
          bodyHtml += `
            <div class="verse-layer nuzul">
              <span class="verse-layer-label nuzul">${nInfo.name}</span>
              ${wrapLayerText(text)}
            </div>
          `;
        }
      }
    }

    if (highlightQuery) {
      bodyHtml += getSearchExcerpts(verseKey, highlightQuery);
    }

    // Topic Tags
    if (state.layers.tags && db.verseTags && db.verseTags[verseKey]) {
      const tagIds = db.verseTags[verseKey];
      if (tagIds && tagIds.length > 0) {
        const moreLabel = state.uiLang === 'id' ? 'Selengkapnya ▼' : 'Show more ▼';
        const lessLabel = state.uiLang === 'id' ? 'Lebih sedikit ▲' : 'Show less ▲';
        let tagsHtml = '<div class="verse-tags tags-collapsible">';
        tagIds.forEach(id => {
          const name = tagLookup.get(id) || id;
          const displayName = highlightQuery ? highlightText(name, highlightQuery) : name;
          tagsHtml += `<a href="#topic/${id}" class="verse-tag">${displayName}</a>`;
        });
        tagsHtml += `</div><button class="tags-more-btn" style="display:none" data-more="${moreLabel}" data-less="${lessLabel}">${moreLabel}</button>`;
        bodyHtml += tagsHtml;
      }
    }

    // Social Share Buttons (embedded SVG icons for WhatsApp, X, Facebook, Telegram, and Link Copy)
    bodyHtml += `
      <div class="share-buttons-container">
        <span class="share-label">Bagikan / Share:</span>
        <div class="share-buttons">
          <button class="share-btn whatsapp" data-share="whatsapp" data-key="${verseKey}" title="WhatsApp">
            <svg viewBox="0 0 24 24"><path d="M12.012 2c-5.506 0-9.989 4.478-9.99 9.984a9.96 9.96 0 001.37 5.016L2 22l5.13-1.35a9.923 9.923 0 004.882 1.28h.005c5.502 0 9.985-4.478 9.986-9.986 0-2.67-1.035-5.18-2.916-7.06C17.215 3.01 14.7 2.003 12.012 2zm6.36 13.916c-.273.76-1.57 1.393-2.154 1.488-.575.093-1.127.327-3.702-.733-3.294-1.357-5.385-4.757-5.55-4.975-.164-.217-1.345-1.787-1.345-3.41 0-1.622.846-2.422 1.15-2.747.303-.326.66-.407.88-.407.218 0 .438.002.63.01.2.01.468-.076.73.574.27.658.917 2.247.997 2.41.08.163.134.353.027.57-.107.217-.16.353-.32.542-.16.19-.335.423-.478.57-.16.163-.327.34-.14.66.186.32.827 1.36 1.77 2.2 1.22 1.09 2.247 1.43 2.565 1.59.32.16.507.135.696-.08.19-.217.823-.96.104-1.287-.08-.163-.2-.353-.3-.57z"/></svg>
            <span>WhatsApp</span>
          </button>
          <button class="share-btn twitter" data-share="twitter" data-key="${verseKey}" title="Twitter/X">
            <svg viewBox="0 0 24 24"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
            <span>X</span>
          </button>
          <button class="share-btn facebook" data-share="facebook" data-key="${verseKey}" title="Facebook">
            <svg viewBox="0 0 24 24"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
            <span>Facebook</span>
          </button>
          <button class="share-btn telegram" data-share="telegram" data-key="${verseKey}" title="Telegram">
            <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 6.8c-.15 1.58-.8 5.42-1.13 7.19-.14.75-.42 1-.68 1.03-.58.05-1.02-.38-1.58-.75-.88-.58-1.38-.94-2.23-1.5-1-.65-.35-1 .22-1.6.15-.15 2.76-2.53 2.81-2.75.01-.03.01-.14-.06-.2-.07-.06-.18-.04-.25-.03-.11.02-1.87 1.18-5.27 3.47-.5.34-.95.5-1.34.49-.43 0-1.27-.24-1.89-.44-.76-.25-1.37-.39-1.31-.83.03-.23.35-.47.95-.73 3.71-1.61 6.19-2.67 7.43-3.18 3.53-1.45 4.26-1.7 4.74-1.7.1 0 .34.02.49.14.12.1.16.24.18.34.02.09.02.26.01.32z"/></svg>
            <span>Telegram</span>
          </button>
          <button class="share-btn copy" data-share="copy" data-key="${verseKey}" title="Copy Link">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>
            <span>${state.uiLang === 'id' ? 'Salin Link' : 'Copy Link'}</span>
          </button>
        </div>
      </div>
    `;
  }

  bodyHtml += '</div>';
  card.innerHTML = headerHtml + bodyHtml;

  // Add click listeners to tags (to prevent bubbling, though they carry native href links now)
  card.querySelectorAll('.verse-tag').forEach(tagEl => {
    tagEl.onclick = (e) => {
      e.stopPropagation();
    };
  });

  // Play audio listener
  const playBtn = card.querySelector('.btn-play-ayah');
  if (playBtn) {
    playBtn.onclick = (e) => {
      e.stopPropagation();
      togglePlayAyah(verseKey);
    };
  }

  // Copy verse listener
  card.querySelector('.btn-copy').onclick = () => {
    copyVerse(verseKey, card);
  };

  // Bookmark listener
  const bookmarkBtn = card.querySelector('.btn-bookmark');
  if (bookmarkBtn) {
    bookmarkBtn.onclick = (e) => {
      e.stopPropagation();
      toggleBookmark(verseKey);
      // Update all bookmark buttons for this verse (may be on multiple cards)
      document.querySelectorAll(`.btn-bookmark[data-key="${verseKey}"]`).forEach(btn => {
        const isBm = bookmarks.has(verseKey);
        btn.setAttribute('aria-pressed', isBm);
        const svg = btn.querySelector('svg');
        if (svg) svg.setAttribute('fill', isBm ? 'currentColor' : 'none');
      });
    };
  }

  // "Show more" / "Show less" toggle listeners
  card.querySelectorAll('.verse-layer-more').forEach(btn => {
    btn.addEventListener('click', () => {
      const textEl = btn.previousElementSibling;
      if (!textEl) return;
      const isClamped = textEl.classList.toggle('is-clamped');
      if (isClamped) {
        btn.textContent = state.uiLang === 'id' ? 'Selengkapnya ▼' : 'Show more ▼';
      } else {
        btn.textContent = state.uiLang === 'id' ? 'Sembunyikan ▲' : 'Show less ▲';
      }
    });
  });

  // Share buttons listener
  if (isDetailMode) {
    card.querySelectorAll('.share-btn').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const shareType = btn.dataset.share;
        const key = btn.dataset.key;
        shareVerse(shareType, key, card);
      };
    });
  }

  return card;
}

function copyVerse(verseKey, card) {
  const parts = [];
  
  // Arabic text
  const ar = card.querySelector('.verse-arabic')?.textContent;
  if (ar) parts.push(ar);

  // Enabled translations and commentary
  card.querySelectorAll('.verse-layer').forEach(layer => {
    const label = layer.querySelector('.verse-layer-label')?.textContent;
    const text = layer.querySelector('.verse-layer-text')?.textContent;
    if (label && text) {
      parts.push(`[${label}] ${text}`);
    }
  });

  parts.push(`(Qur'an ${verseKey})`);

  const fullText = parts.join('\n\n');
  navigator.clipboard.writeText(fullText).then(() => {
    const btn = card.querySelector('.btn-copy');
    btn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" style="color:var(--green)"><path d="M20 6 9 17l-5-5"/></svg>`;
    setTimeout(() => {
      btn.innerHTML = `<svg viewBox="0 0 24 24"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`;
    }, 2000);
  }).catch(err => {
    console.error('Failed to copy: ', err);
  });
}

function shareVerse(type, key, card) {
  const [suraId, ayaId] = key.split(':');
  const shareUrl = `${window.location.origin}${window.location.pathname}#sura/${suraId}/verse/${ayaId}`;
  
  const arText = card.querySelector('.verse-arabic')?.textContent || '';
  const firstLayerText = card.querySelector('.verse-layer-text')?.textContent || '';
  
  const textMsg = `Qur'an ${key}\n\n${arText}\n\n"${firstLayerText}"`;
  
  if (type === 'whatsapp') {
    const url = `https://api.whatsapp.com/send?text=${encodeURIComponent(textMsg + '\n\n' + (state.uiLang === 'id' ? 'Selengkapnya: ' : 'Read more: ') + shareUrl)}`;
    window.open(url, '_blank');
  } else if (type === 'twitter') {
    const url = `https://twitter.com/intent/tweet?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(textMsg)}`;
    window.open(url, '_blank');
  } else if (type === 'facebook') {
    const url = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`;
    window.open(url, '_blank');
  } else if (type === 'telegram') {
    const url = `https://t.me/share/url?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(textMsg)}`;
    window.open(url, '_blank');
  } else if (type === 'copy') {
    navigator.clipboard.writeText(shareUrl).then(() => {
      const btn = card.querySelector('.share-btn.copy');
      const origHtml = btn.innerHTML;
      btn.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" style="color:var(--green)"><path d="M20 6 9 17l-5-5"/></svg>
        <span>${state.uiLang === 'id' ? 'Salin Berhasil' : 'Copied!'}</span>
      `;
      setTimeout(() => {
        btn.innerHTML = origHtml;
      }, 2000);
    }).catch(err => {
      console.error('Failed to copy share link: ', err);
    });
  }
}

// --- Bookmarks Controller ---
function toggleBookmark(verseKey) {
  if (bookmarks.has(verseKey)) {
    bookmarks.delete(verseKey);
  } else {
    bookmarks.add(verseKey);
  }
  saveBookmarks();
  renderBookmarksList();
}

function renderBookmarksList() {
  const container = document.getElementById('bookmarks-list-container');
  if (!container) return;
  
  if (bookmarks.size === 0) {
    const isId = state.uiLang === 'id';
    container.innerHTML = `
      <div class="sidebar-empty-state" style="padding: 2rem 1rem; text-align: center; color: var(--text-muted);">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 48px; height: 48px; margin: 0 auto 1rem; opacity: 0.5;">
          <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
        </svg>
        <p style="font-weight: 500;">${isId ? 'Belum ada bookmark' : 'No bookmarks yet'}</p>
        <p style="font-size: 0.8rem; margin-top: 0.5rem; opacity: 0.8; line-height: 1.4;">
          ${isId ? 'Ketuk ikon bookmark pada ayat untuk menyimpannya di sini.' : 'Tap the bookmark icon on any verse to save it here.'}
        </p>
      </div>
    `;
    return;
  }
  
  // Sort bookmarks by sura:ayah order
  const sorted = Array.from(bookmarks).sort((a, b) => {
    const [s1, v1] = a.split(':').map(Number);
    const [s2, v2] = b.split(':').map(Number);
    if (s1 !== s2) return s1 - s2;
    return v1 - v2;
  });
  
  container.innerHTML = '';
  sorted.forEach(verseKey => {
    const [suraId, ayaId] = verseKey.split(':');
    const suraMeta = db.suraList ? db.suraList.find(s => s.id === Number(suraId)) : null;
    const suraName = suraMeta
      ? (state.uiLang === 'id' ? suraMeta.name_id : suraMeta.name_en)
      : `Sura ${suraId}`;
    
    const arText = db.quranArabic[verseKey] || '';
    
    const item = document.createElement('div');
    item.className = 'bookmark-item';
    
    item.innerHTML = `
      <div class="bookmark-item-header">
        <a href="#sura/${suraId}/verse/${ayaId}" class="bookmark-ref-link">
          ${suraName} : ${ayaId}
        </a>
        <button class="btn-icon delete-bookmark" data-key="${verseKey}" title="Remove bookmark">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="3 6 5 6 21 6"></polyline>
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
          </svg>
        </button>
      </div>
      <div class="bookmark-preview-ar" lang="ar">
        ${arText}
      </div>
    `;
    
    // Wire click to navigate to the verse detail
    item.querySelector('a').onclick = (e) => {
      closeSidebarMobile();
    };
    
    // Wire delete button
    item.querySelector('.delete-bookmark').onclick = (e) => {
      e.stopPropagation();
      toggleBookmark(verseKey);
      // Also update any bookmark buttons visible on screen
      document.querySelectorAll(`.btn-bookmark[data-key="${verseKey}"]`).forEach(btn => {
        btn.setAttribute('aria-pressed', 'false');
        const svg = btn.querySelector('svg');
        if (svg) svg.setAttribute('fill', 'none');
      });
    };
    
    container.appendChild(item);
  });
}

// --- 7. Router Trigger Handler ---
async function triggerRouting() {
  const hash = window.location.hash || '#home';
  closeSidebarMobile();

  // Track the last active hash (excluding mushaf, verse detail views, login, recovery, access_token)
  if (hash && hash !== '#mushaf' && !hash.includes('/verse/') && !hash.startsWith('#login') && !hash.includes('access_token') && !hash.includes('recovery')) {
    lastActiveHash = hash;
  }

  // On OAuth redirect, Supabase needs the hash fragment to extract tokens.
  // Do NOT clear/redirect the hash here — let Supabase's onAuthStateChange fire
  // naturally. Once it fires SIGNED_IN, handleAuthSession() will do the redirect.
  if (hash.includes('access_token') || hash.includes('error_description')) {
    // Just render home silently while Supabase processes the fragment
    switchView('home');
    updateBreadcrumbs('home');
    renderHomeGrid();
    return;
  }
  
  if (hash === '#home' || hash === '' || hash === '#') {
    // Exit split mode if active
    state.mushafSplitMode = false;
    document.body.classList.remove('split-mushaf-mode');
    const sidebarEl = document.getElementById('sidebar');
    if (sidebarEl) sidebarEl.classList.remove('collapsed');
    switchView('home');
    updateBreadcrumbs('home');
    highlightActiveSuraInSidebar(null);
    renderHomeGrid();
  } else if (hash === '#admin' || hash === '#/admin') {
    openAdminCms();
  } else if (hash.startsWith('#sura/')) {
    const parts = hash.split('/');
    const suraId = parseInt(parts[1], 10);
    const targetVerse = parts[3] ? parseInt(parts[3], 10) : null;
    
    if (suraId >= 1 && suraId <= 114) {
      const sura = db.suraList.find(s => s.id === suraId);
      highlightActiveSuraInSidebar(suraId);
      
      // Track current sura/ayah for mushaf sync
      state.currentSuraId = suraId;
      state.currentAyahNum = targetVerse || null;

      // Highlight corresponding tab (only if not in split mode, to avoid collapsing mushaf)
      if (!state.mushafSplitMode) {
        const tabSura = document.getElementById('tab-sura-list');
        if (tabSura) tabSura.click();
      }

      // First display of surah page and ayah page logic:
      // Open the display settings sidebar and set all options activated (if not done yet in this session)
      if (!sessionStorage.getItem('tafsir_first_display_done')) {
        sessionStorage.setItem('tafsir_first_display_done', '1');
        
        // Open panel
        const compPanel = document.getElementById('comparison-panel');
        if (compPanel && !compPanel.classList.contains('open')) {
          compPanel.classList.add('open');
        }
        
        // Set all layers to active
        for (const layer in state.layers) {
          state.layers[layer] = true;
        }
        
        // Update checkbox controls in UI
        for (const layer in state.layers) {
          const cb = document.getElementById(`${layer}-toggle`);
          if (cb) cb.checked = true;
        }
        
        saveSettings();
      }

      await ensureActiveDatasets();

      if (targetVerse) {
        // --- Single Ayah View Mode ---
        if (state.mushafSplitMode) {
          // SPLIT MODE: show Mushaf + Ayah side-by-side
          document.body.classList.add('split-mushaf-mode');
          const sidebarEl = document.getElementById('sidebar');
          if (sidebarEl) sidebarEl.classList.add('collapsed');

          // Fetch the mushaf page number for this verse and sync
          let targetPage = null;
          if (supabaseClient) {
            try {
              const { data: pageData } = await supabaseClient
                .from('verses')
                .select('page_number')
                .eq('verse_key', `${suraId}:${targetVerse}`)
                .maybeSingle();
              if (pageData && pageData.page_number) targetPage = pageData.page_number;
            } catch (e) { console.warn('[Routing] page_number fetch failed:', e); }
          }

          if (targetPage && targetPage !== mushafCurrentPage) {
            // Page turn — loadMushafPage will auto-highlight
            mushafCurrentPage = targetPage;
            const slider = document.getElementById('mushaf-page-slider');
            if (slider) slider.value = targetPage;
            updateMushafPageLabel();
            await loadMushafPage(targetPage);
          } else {
            // Same page — just update highlight
            syncMushafHighlight();
          }

          // Activate both views side-by-side
          switchView('mushaf');
          const viewAyahEl = document.getElementById('view-ayah');
          if (viewAyahEl) viewAyahEl.classList.add('active');
          // Show close button in split mode
          const splitCloseBtn = document.getElementById('ayah-detail-close-btn');
          if (splitCloseBtn) splitCloseBtn.style.display = 'flex';
        } else {
          // NORMAL MODE: full-screen ayah view
          document.body.classList.remove('split-mushaf-mode');
          switchView('ayah');
          // Hide close button in normal ayah view
          const splitCloseBtn = document.getElementById('ayah-detail-close-btn');
          if (splitCloseBtn) splitCloseBtn.style.display = 'none';
        }
        updateBreadcrumbs('ayah', { sura, verse: targetVerse });

        // Render Header
        const headerContainer = document.getElementById('ayah-detail-header');
        const name = state.uiLang === 'id' ? sura.name_id : sura.name_en;
        headerContainer.innerHTML = `
          <div class="ayah-detail-header-sura">${name}</div>
          <h2 class="ayah-detail-header-title">Ayah ${targetVerse}</h2>
          <div class="ayah-detail-header-meta">${state.uiLang === 'id' && sura.meaning_id ? sura.meaning_id : sura.meaning} • ${localizeType(sura.type)}</div>
        `;

        // Render single card in detail mode
        const detailContent = document.getElementById('ayah-detail-content');
        detailContent.innerHTML = '';
        const card = createVerseCard(`${suraId}:${targetVerse}`, true);
        detailContent.appendChild(card);

        // Post-process "Show more" buttons for this detail card
        requestAnimationFrame(() => {
          card.querySelectorAll('.verse-layer-more:not([data-processed])').forEach(btn => {
            btn.setAttribute('data-processed', '1');
            const textEl = btn.previousElementSibling;
            if (textEl && textEl.scrollHeight > textEl.clientHeight + 2) {
              btn.style.display = '';
            }
          });
          card.querySelectorAll('.tags-more-btn:not([data-processed])').forEach(btn => {
            btn.setAttribute('data-processed', '1');
            const tagsEl = btn.previousElementSibling;
            if (tagsEl && tagsEl.scrollHeight > tagsEl.clientHeight + 2) {
              btn.style.display = 'inline-flex';
              btn.onclick = () => {
                const expanded = tagsEl.classList.toggle('is-expanded');
                btn.textContent = expanded ? btn.getAttribute('data-less') : btn.getAttribute('data-more');
              };
            }
          });
        });

        // Prev / Next / Back buttons
        const prevBtn = document.getElementById('ayah-prev-btn');
        const nextBtn = document.getElementById('ayah-next-btn');
        const backBtn = document.getElementById('ayah-back-btn');

        if (backBtn) {
          backBtn.onclick = () => window.location.hash = `#sura/${suraId}`;
        }

        if (prevBtn) {
          if (targetVerse > 1) {
            prevBtn.style.visibility = 'visible';
            prevBtn.onclick = () => window.location.hash = `#sura/${suraId}/verse/${targetVerse - 1}`;
          } else if (suraId > 1) {
            const prevSura = db.suraList.find(s => s.id === suraId - 1);
            prevBtn.style.visibility = 'visible';
            prevBtn.onclick = () => window.location.hash = `#sura/${suraId - 1}/verse/${prevSura.ayas}`;
          } else {
            prevBtn.style.visibility = 'hidden';
          }
        }

        if (nextBtn) {
          if (targetVerse < sura.ayas) {
            nextBtn.style.visibility = 'visible';
            nextBtn.onclick = () => window.location.hash = `#sura/${suraId}/verse/${targetVerse + 1}`;
          } else if (suraId < 114) {
            nextBtn.style.visibility = 'visible';
            nextBtn.onclick = () => window.location.hash = `#sura/${suraId + 1}/verse/1`;
          } else {
            nextBtn.style.visibility = 'hidden';
          }
        }
      } else {
        // --- Sura List Mode --- exit split mode
        state.mushafSplitMode = false;
        state.currentAyahNum = null;
        document.body.classList.remove('split-mushaf-mode');
        const sidebarElRestore = document.getElementById('sidebar');
        if (sidebarElRestore) sidebarElRestore.classList.remove('collapsed');
        switchView('sura');
        updateBreadcrumbs('sura', { sura });

        // Auto-open comparison panel so users can see display settings
        const compPanel = document.getElementById('comparison-panel');
        if (compPanel && !compPanel.classList.contains('open')) {
          compPanel.classList.add('open');
        }

        // Reset to page 1 whenever we navigate to a new sura
        suraPage = 1;

        // Render Header
        const headerContainer = document.getElementById('sura-header');
        const name = state.uiLang === 'id' ? sura.name_id : sura.name_en;
        const bismillahHtml = (sura.id !== 1 && sura.id !== 9)
          ? `<div class="sura-header-bismillah" lang="ar">بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ</div>`
          : '';

        headerContainer.innerHTML = `
          <div class="sura-header-num">Sura ${sura.id}</div>
          <div class="sura-header-name-ar" lang="ar">${sura.name_ar}</div>
          <h2 class="sura-header-name-en">${name}</h2>
          <div class="sura-header-meta">${state.uiLang === 'id' && sura.meaning_id ? sura.meaning_id : sura.meaning} • ${localizeType(sura.type)} • ${sura.ayas} ${state.uiLang === 'id' ? 'Ayat' : 'Verses'}</div>
          ${bismillahHtml}
        `;

        // Next / Prev sura links
        const prevBtn = document.getElementById('sura-prev-btn');
        const nextBtn = document.getElementById('sura-next-btn');
        if (prevBtn) {
          prevBtn.style.visibility = suraId > 1 ? 'visible' : 'hidden';
          prevBtn.onclick = () => window.location.hash = `#sura/${suraId - 1}`;
        }
        if (nextBtn) {
          nextBtn.style.visibility = suraId < 114 ? 'visible' : 'hidden';
          nextBtn.onclick = () => window.location.hash = `#sura/${suraId + 1}`;
        }

        // Build all verse keys for this sura
        const allVerseKeys = [];
        for (let i = 1; i <= sura.ayas; i++) {
          allVerseKeys.push(`${suraId}:${i}`);
        }

        // Render paginated verse list
        renderSuraPage(allVerseKeys, suraId, sura);
      }
    }
  } else if (hash.startsWith('#topic/')) {
    state.mushafSplitMode = false;
    document.body.classList.remove('split-mushaf-mode');
    const sidebarEl = document.getElementById('sidebar');
    if (sidebarEl) sidebarEl.classList.remove('collapsed');
    const tagId = decodeURIComponent(hash.substring(7));
    switchView('topic');
    highlightActiveSuraInSidebar(null);

    // Switch active sidebar panel to Topic List
    const tabTopics = document.getElementById('tab-topics');
    if (tabTopics) tabTopics.click();

    const tag = db.tags.find(t => t.id === tagId);
    updateBreadcrumbs('topic', { topicName: tag ? tag.name : tagId });

    // Reset pagination on new topic navigation
    topicPage = 1;
    const placeholder = document.getElementById('topic-paginator-placeholder');
    if (placeholder) placeholder.innerHTML = '';

    // Extract matches
    const verses = [];
    for (const key in db.verseTags) {
      if (db.verseTags[key].includes(tagId)) {
        verses.push(key);
      }
    }

    verses.sort((a, b) => {
      const [s1, v1] = a.split(':').map(Number);
      const [s2, v2] = b.split(':').map(Number);
      if (s1 !== s2) return s1 - s2;
      return v1 - v2;
    });

    const isId = state.uiLang === 'id';
    const header = document.getElementById('topic-results-header');
    if (header) {
      header.innerHTML = `
        <h2 class="search-results-title">Topic: ${tag ? tag.name : tagId}</h2>
        <div class="search-results-count">${verses.length} ${isId ? 'ayat dengan topik ini' : 'verses tagged with this topic'}</div>
      `;
    }

    await ensureActiveDatasets();
    renderTopicPage(verses, tagId, tag);
  } else if (hash.startsWith('#search/')) {
    state.mushafSplitMode = false;
    document.body.classList.remove('split-mushaf-mode');
    const sidebarEl = document.getElementById('sidebar');
    if (sidebarEl) sidebarEl.classList.remove('collapsed');
    const query = decodeURIComponent(hash.substring(8));
    switchView('search');
    highlightActiveSuraInSidebar(null);
    updateBreadcrumbs('search');

    // Reset pagination on new search
    searchPage = 1;
    const searchPlaceholder = document.getElementById('search-paginator-placeholder');
    if (searchPlaceholder) searchPlaceholder.innerHTML = '';

    const isId = state.uiLang === 'id';
    const searchResultsList = document.getElementById('search-results-list');
    const header = document.getElementById('search-results-header');

    const showProgress = (msg) => {
      searchResultsList.innerHTML = `
        <div class="loading-wrap">
          <div class="spinner"></div>
          <div>${msg}</div>
        </div>
      `;
    };

    // Reset similarity scores and context snippets
    searchSimilarityScores = {};
    searchContextSnippets = {};

    if (state.searchOptions && state.searchOptions.semantic) {
      showProgress(isId ? 'Menghubungkan ke AI...' : 'Connecting to AI...');
      try {
        // ── Cloudflare Workers AI Hybrid Search (bge-m3 vector + trigram RRF) ──
        // Replaced old Supabase-only RPC with the CF Worker that generates
        // real-time embeddings via @cf/baai/bge-m3 and merges semantic +
        // full-text results using Reciprocal Rank Fusion (RRF).
        const CF_WORKER_URL = 'https://tafsir-web-search.irianto-suryoputro.workers.dev/api/search';

        const workerRes = await fetch(CF_WORKER_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            query: query.trim(),
            lang: state.uiLang === 'id' ? 'id' : 'en',
            limit: 50,
          }),
        });

        if (!workerRes.ok) throw new Error(`Worker HTTP ${workerRes.status}`);
        const workerData = await workerRes.json();
        if (!workerData.success) throw new Error(workerData.error || 'Worker error');

        const mergedResults = [];
        if (workerData.results && Array.isArray(workerData.results)) {
          workerData.results.forEach(r => {
            const verseKey = r.verse_key;
            // Store RRF score as similarity so existing score-badge UI still works
            searchSimilarityScores[verseKey] = r.score || 0;
            mergedResults.push(verseKey);
          });
        }

        if (header) {
          header.innerHTML = `
            <h2 class="search-results-title">${isId ? 'Hasil Pencarian Semantik untuk' : 'Semantic Search Results for'} &ldquo;${query}&rdquo;</h2>
            <div class="search-results-count">${isId ? 'Ditemukan' : 'Found'} ${mergedResults.length} ${isId ? 'ayat paling relevan secara makna' : 'verses matching semantically'}</div>
          `;
        }

        await ensureActiveDatasets();
        renderSearchPage(mergedResults, query);
        return;
      } catch (err) {
        console.warn('Hybrid search (CF Worker) failed, falling back to legacy semantic search:', err);
        // ── Legacy fallback: old Supabase RPC (no CF AI vectors) ──────────────
        try {
          const { data: results, error: rpcErr } = await supabaseClient.rpc('semantic_search_verses_by_text', {
            query_text: query.trim(),
            lang_code: state.uiLang,
            match_threshold: 0.1,
            result_limit: 50,
            offset_val: 0
          });

          if (rpcErr) throw rpcErr;

          const mergedResults = [];
          if (results && Array.isArray(results)) {
            results.forEach(r => {
              const verseKey = r.verse_key;
              searchSimilarityScores[verseKey] = r.similarity || 0;
              mergedResults.push(verseKey);
            });
          }

          if (header) {
            header.innerHTML = `
              <h2 class="search-results-title">${isId ? 'Hasil Pencarian Semantik untuk' : 'Semantic Search Results for'} &ldquo;${query}&rdquo;</h2>
              <div class="search-results-count">${isId ? 'Ditemukan' : 'Found'} ${mergedResults.length} ${isId ? 'ayat paling relevan secara makna' : 'verses matching semantically'}</div>
            `;
          }

          await ensureActiveDatasets();
          renderSearchPage(mergedResults, query);
          return;
        } catch (fallbackErr) {
          console.warn('Legacy semantic search also failed, falling back to keyword search:', fallbackErr);
          searchSimilarityScores = {};
        }
      }
    }

    // Reset context snippets and match frequency scores
    searchContextSnippets = {};
    const verseMatchScores = {};

    const addHit = (vk, weight = 1) => {
      verseMatchScores[vk] = (verseMatchScores[vk] || 0) + weight;
    };

    showProgress(isId ? 'Mencari...' : 'Searching...');

    // ── 1. Algolia Keyword Search ──────────────────────────────────────────
    try {
      const ALGOLIA_APP_ID   = 'EKMF7ZL31U';
      const ALGOLIA_SEARCH_KEY = 'fdd11b6d57ebb5060e66599e7a9738ec';
      const targetLang = state.uiLang === 'id' ? 'id' : 'en';

      const algoliaRes = await fetch(
        `https://${ALGOLIA_APP_ID}-dsn.algolia.net/1/indexes/quran_verses/query`,
        {
          method: 'POST',
          headers: {
            'X-Algolia-Application-Id': ALGOLIA_APP_ID,
            'X-Algolia-API-Key': ALGOLIA_SEARCH_KEY,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            query: query.trim(),
            hitsPerPage: 100,
            attributesToRetrieve: ['verse_key', 'text_ar', `text_${targetLang}`, `translit_${targetLang}`, `tags_${targetLang}`],
            attributesToHighlight: [`text_${targetLang}`, `translit_${targetLang}`, `tags_${targetLang}`],
          })
        }
      );

      if (algoliaRes.ok) {
        const algoliaData = await algoliaRes.json();
        if (algoliaData.hits && algoliaData.hits.length > 0) {
          algoliaData.hits.forEach(h => {
            addHit(h.verse_key, 2);
            const hl = h._highlightResult;
            const snippetField = hl && (hl[`text_${targetLang}`] || hl[`translit_${targetLang}`]);
            if (snippetField && snippetField.value) {
              searchContextSnippets[h.verse_key] = snippetField.value
                .replace(/<em>/g, '<mark class="highlight">')
                .replace(/<\/em>/g, '</mark>');
            }
          });
        }
      }
    } catch (algoliaErr) {
      console.warn('Algolia search error:', algoliaErr);
    }

    // ── 2. Database / RPC Search (Supabase) ──────────────────────────────────
    if (supabaseClient) {
      try {
        const { data: results, error: rpcErr } = await supabaseClient.rpc('search_verses', {
          p_query: query.trim(),
          p_lang_code: state.uiLang,
          p_result_limit: 100,
          p_offset_val: 0
        });

        if (!rpcErr && results && Array.isArray(results)) {
          results.forEach(r => {
            addHit(r.verse_key, 2);
            if (r.context_snippet && !searchContextSnippets[r.verse_key]) {
              searchContextSnippets[r.verse_key] = r.context_snippet;
            }
          });
        }
      } catch (err) {
        console.warn('Database search error:', err);
      }
    }

    // ── 3. Local Search Index & Tafsir Scan ────────────────────────────────
    await ensureActiveDatasets();
    const qLower = query.toLowerCase().trim();

    // Check pre-built search index
    if (!db.searchIndex) {
      try {
        const indexFile = (state.searchOptions.lang !== 'en' && state.searchOptions.lang !== 'id' && state.searchOptions.lang !== 'all')
          ? 'data/search_index_full.json' : 'data/search_index.json';
        const res = await fetch(indexFile);
        db.searchIndex = await res.json();
      } catch (_) {}
    }

    if (db.searchIndex) {
      const exactPhrases = [];
      const broadWords = [];
      const regexParse = /"([^"]+)"|(\S+)/g;
      let match;
      while ((match = regexParse.exec(qLower)) !== null) {
        if (match[1]) exactPhrases.push(match[1].trim());
        else if (match[2]) broadWords.push(match[2].trim());
      }
      for (const bw of broadWords) {
        if (bw.length < 2) continue;
        for (const word in db.searchIndex) {
          if (word.includes(bw)) {
            const entryStr = db.searchIndex[word];
            if (entryStr) {
              const pairs = entryStr.split(',');
              for (const pair of pairs) {
                addHit(pair.split('_')[0], 1);
              }
            }
          }
        }
      }
    }

    // Check loaded tafsirs for exact commentary matches (e.g., "Abu Hanifah")
    if (db.registry && db.registry.tafsirs) {
      db.registry.tafsirs.forEach(t => {
        const data = getTafsirData(t);
        if (data) {
          for (const key in data) {
            const txt = data[key];
            if (typeof txt === 'string' && textMatchesQuery(txt, query)) {
              addHit(key, 1);
            }
          }
        }
      });
    }

    // Check topic tags
    if (db.tags && db.verseTags) {
      const matchingTagIds = db.tags
        .filter(t => t.name.toLowerCase().includes(qLower))
        .map(t => t.id);
      for (const key in db.verseTags) {
        if (db.verseTags[key].some(t => matchingTagIds.includes(t))) {
          addHit(key, 1);
        }
      }
    }

    // ── 4. Relevance Ranking & Sequential Sort ─────────────────────────────
    // Primary sort: Match frequency score descending (verses matching multiple engines/sources rank higher)
    // Secondary sort: Surah & Ayah number ascending (sequential order within each relevance tier)
    const mergedResults = Object.keys(verseMatchScores).sort((a, b) => {
      const scoreA = verseMatchScores[a] || 0;
      const scoreB = verseMatchScores[b] || 0;
      if (scoreB !== scoreA) {
        return scoreB - scoreA;
      }
      const [s1, v1] = a.split(':').map(Number);
      const [s2, v2] = b.split(':').map(Number);
      if (s1 !== s2) return s1 - s2;
      return v1 - v2;
    });

    if (header) {
      const relatedTerms = getRelatedSearchTerms(query);
      let noteHtml = '';
      if (relatedTerms.length > 0) {
        const links = relatedTerms.map(t => `<a href="#search/${encodeURIComponent(t)}" style="color:var(--accent, #10b981); font-weight:600; text-decoration:underline; margin:0 3px;">${t}</a>`).join(', ');
        noteHtml = `
          <div class="search-related-note" style="margin-top: 8px; font-size: 0.88rem; color: var(--text-muted, #94a3b8); background: rgba(16, 185, 129, 0.05); border: 1px solid rgba(16, 185, 129, 0.15); border-radius: 6px; padding: 6px 12px; display: inline-block;">
            💡 ${isId ? 'Pencarian juga mencakup kata/terminologi terkait:' : 'Search results also include related terms:'} ${links}
          </div>
        `;
      }

      header.innerHTML = `
        <h2 class="search-results-title">${isId ? 'Hasil Pencarian untuk' : 'Search Results for'} &ldquo;${query}&rdquo;</h2>
        <div class="search-results-count">${isId ? 'Ditemukan' : 'Found'} ${mergedResults.length} ${isId ? 'ayat dari semua terjemahan, tafsir, asbabun nuzul & topik' : 'verses across all translations, tafsirs, asbabun nuzul & topics'}</div>
        ${noteHtml}
      `;
    }

    await ensureActiveDatasets();
    renderSearchPage(mergedResults, query);
    return;

    // --- 5. Pre-load source files referenced in index for matched verses ---
    // This ensures getSearchExcerpts() can always show excerpts even when
    // the matching source (translation/tafsir/nuzul) is turned off in the sidebar.
    if (db.searchIndex) {
      const allRegistrySources = [
        ...db.registry.translations,
        ...db.registry.tafsirs,
        ...db.registry.asbabun_nuzul
      ];

      // Build a set of the matched verse keys for fast O(1) lookup
      const matchedSet = new Set(mergedResults);

      // Collect unique source-file indices referenced for those verses.
      const neededFileIndices = new Set();

      // 1. Always pre-fetch the user's currently active translation / tafsir / nuzul sources
      const activeIds = [
        state.activeTranslation1,
        state.activeTranslation2,
        state.activeTafsir1,
        state.activeTafsir2
      ].filter(Boolean);
      for (const id of activeIds) {
        const idx = allRegistrySources.findIndex(s => s.id === id);
        if (idx !== -1) neededFileIndices.add(idx);
      }

      // 2. Also pre-fetch a broad list of common multilingual translations for excerpt search
      const commonMultilingualIds = [
        'nl.keyzer', 'nl.leemhuis', 'nl.siregar',
        'de.bubenheim', 'de.khoury', 'de.aburida', 'de.zaidan',
        'fr.hamidullah',
        'tr.ates', 'tr.bulac', 'tr.diyanet',
        'bs.korkut', 'bs.mlivo',
        'es.garcia', 'es.cortes', 'es.bornez',
        'ru.kuliev', 'ru.krachkovsky', 'ru.osmanov',
        'ur.maududi', 'ur.jalandhry',
        'pt.elhayek',
        'ms.basmeih',
        'it.piccardo',
        'no.berg',
        'sv.bernstrom',
        'pl.bielawskiego',
        'ro.grigore'
      ];
      for (const id of commonMultilingualIds) {
        const idx = allRegistrySources.findIndex(s => s.id === id);
        if (idx !== -1) neededFileIndices.add(idx);
      }

      // Pre-fetch any not-yet-cached source files in parallel
      const fetchPromises = [];
      for (const idx of neededFileIndices) {
        const src = allRegistrySources[idx];
        if (src && !db.cache.has(src.file)) {
          fetchPromises.push(db.getResource(src.file).catch(() => null));
        }
      }
      if (fetchPromises.length > 0) {
        await Promise.all(fetchPromises);
      }
    }

    renderSearchPage(mergedResults, query);
  } else if (hash === '#mushaf') {
    // Full-screen mushaf mode — exit split if active
    state.mushafSplitMode = false;
    document.body.classList.remove('split-mushaf-mode');
    const viewAyahOnMushaf = document.getElementById('view-ayah');
    if (viewAyahOnMushaf) viewAyahOnMushaf.classList.remove('active');
    const mushafCloseBtn = document.getElementById('ayah-detail-close-btn');
    if (mushafCloseBtn) mushafCloseBtn.style.display = 'none';
    switchView('mushaf');
    updateBreadcrumbs('home');
    highlightActiveSuraInSidebar(null);
    // Mushaf view loads SVG via its own controller
  } else {
    // Fallback: unknown hash — show home
    state.mushafSplitMode = false;
    document.body.classList.remove('split-mushaf-mode');
    const sidebarEl = document.getElementById('sidebar');
    if (sidebarEl) sidebarEl.classList.remove('collapsed');
    switchView('home');
    updateBreadcrumbs('home');
    renderHomeGrid();
  }
  updateAudioUI();
}

// --- 8. Sidebar Toggle Logic ---
const sidebar = document.getElementById('sidebar');
const overlay = document.getElementById('overlay');

function closeSidebarMobile() {
  if (window.innerWidth <= 900) {
    if (sidebar) sidebar.classList.remove('open');
    if (overlay) overlay.classList.remove('active');
  }
}

// --- 9. Populating Dropdowns ---
function buildSearchableSelect(searchId, dropdownId, hiddenId, items, currentValue, noneLabel) {
  const searchEl = document.getElementById(searchId);
  const dropdown = document.getElementById(dropdownId);
  const hidden = document.getElementById(hiddenId);
  if (!searchEl || !dropdown || !hidden) return;

  dropdown.innerHTML = '';
  if (noneLabel !== undefined && noneLabel !== null) {
    const noneOpt = document.createElement('div');
    noneOpt.className = 'ss-option' + (currentValue === '' ? ' selected' : '');
    noneOpt.textContent = noneLabel;
    noneOpt.dataset.value = '';
    dropdown.appendChild(noneOpt);
  }
  items.forEach(item => {
    const opt = document.createElement('div');
    opt.className = 'ss-option' + (item.id === currentValue ? ' selected' : '');
    opt.textContent = item.name;
    opt.dataset.value = item.id;
    dropdown.appendChild(opt);
  });

  const currentItem = items.find(i => i.id === currentValue);
  searchEl.value = currentItem ? currentItem.name : (noneLabel || '');
  hidden.value = currentValue || '';

  searchEl.addEventListener('input', () => {
    const q = searchEl.value.toLowerCase();
    let visibleCount = 0;
    dropdown.querySelectorAll('.ss-option').forEach(opt => {
      const match = opt.textContent.toLowerCase().includes(q);
      opt.classList.toggle('hidden', !match);
      if (match) visibleCount++;
    });

    let noRes = dropdown.querySelector('.ss-no-results');
    if (visibleCount === 0) {
      if (!noRes) {
        noRes = document.createElement('div');
        noRes.className = 'ss-no-results';
        dropdown.appendChild(noRes);
      }
      noRes.textContent = 'No results found';
    } else if (noRes) {
      noRes.remove();
    }
    dropdown.classList.add('open');
  });

  searchEl.addEventListener('focus', () => {
    document.querySelectorAll('.ss-dropdown').forEach(d => {
      if (d !== dropdown) d.classList.remove('open');
    });
    searchEl.select();
    dropdown.classList.add('open');
  });

  searchEl.addEventListener('click', (e) => {
    e.stopPropagation();
    document.querySelectorAll('.ss-dropdown').forEach(d => {
      if (d !== dropdown) d.classList.remove('open');
    });
    dropdown.classList.add('open');
  });

  dropdown.addEventListener('click', (e) => {
    const opt = e.target.closest('.ss-option');
    if (!opt) return;
    const val = opt.dataset.value;
    hidden.value = val;
    searchEl.value = opt.textContent;

    dropdown.querySelectorAll('.ss-option').forEach(o => o.classList.remove('selected'));
    opt.classList.add('selected');
    dropdown.classList.remove('open');

    hidden.dispatchEvent(new Event('change'));
  });
}

function syncSearchableSelect(searchId, dropdownId, hiddenId, items, value, noneLabel) {
  const searchEl = document.getElementById(searchId);
  const hidden = document.getElementById(hiddenId);
  const dropdown = document.getElementById(dropdownId);
  if (!searchEl || !hidden) return;

  const item = items ? items.find(i => i.id === value) : null;
  searchEl.value = item ? item.name : (noneLabel || '');
  hidden.value = value || '';

  if (dropdown) {
    dropdown.querySelectorAll('.ss-option').forEach(o => {
      o.classList.toggle('selected', o.dataset.value === (value || ''));
      o.classList.remove('hidden');
    });
    const noRes = dropdown.querySelector('.ss-no-results');
    if (noRes) noRes.remove();
  }
}

function populateSelects() {
  buildSearchableSelect('trans1-search', 'trans1-dropdown', 'trans1-select', db.registry.translations, state.activeTranslation1, null);
  buildSearchableSelect('trans2-search', 'trans2-dropdown', 'trans2-select', db.registry.translations, state.activeTranslation2, null);
  buildSearchableSelect('translit-search', 'translit-dropdown', 'translit-select', db.registry.transliterations || [], state.activeTransliteration, '— none —');
  buildSearchableSelect('reciter-search', 'reciter-dropdown', 'reciter-select',
    (db.registry.reciters || []).map(r => ({ id: r.id, name: `${r.name} — ${r.style}` })),
    state.activeReciter, null);
  buildSearchableSelect('tafsir1-search', 'tafsir1-dropdown', 'tafsir1-select', db.registry.tafsirs, state.activeTafsir1, null);
  buildSearchableSelect('tafsir2-search', 'tafsir2-dropdown', 'tafsir2-select', db.registry.tafsirs, state.activeTafsir2, null);
  buildSearchableSelect('nuzul1-search', 'nuzul1-dropdown', 'nuzul1-select', db.registry.asbabun_nuzul, state.activeNuzul1, '— none available —');
  buildSearchableSelect('nuzul2-search', 'nuzul2-dropdown', 'nuzul2-select', db.registry.asbabun_nuzul, state.activeNuzul2, '— none available —');

  const tagSel = document.getElementById('tags-select');
  if (tagSel) {
    tagSel.innerHTML = '';
    db.registry.tags.forEach(tag => tagSel.add(new Option(tag.name, tag.id)));
    tagSel.value = state.activeTags;
  }
  updateTagsSelectHint();
}

function updateTagsSelectHint() {
  const tagSel = document.getElementById('tags-select');
  if (tagSel) {
    if (state.tagsUserPref) {
      tagSel.style.border = '1px solid var(--accent)';
      tagSel.style.boxShadow = '0 0 5px var(--accent)';
    } else {
      tagSel.style.border = '';
      tagSel.style.boxShadow = '';
    }
  }
}

// --- Global Audio Controller ---
let currentAudio = null;
let currentPlayingKey = null; // "sura:ayah"
let isAudioPlaying = false;

// Reciters served as whole-surah MP3s from mp3quran.net (not per-ayah from everyayah)
const SURAH_LEVEL_RECITERS = {
  'wdee3': 'https://server6.mp3quran.net/wdee3/'
};

function getAudioUrl(verseKey, reciterId, mirror = 0) {
  const [sura, ayah] = verseKey.split(':');
  const suraPad = sura.padStart(3, '0');
  // Surah-level reciter: one MP3 per surah, ignore ayah
  if (SURAH_LEVEL_RECITERS[reciterId]) {
    return `${SURAH_LEVEL_RECITERS[reciterId]}${suraPad}.mp3`;
  }
  // Per-ayah: try three CDNs in order
  const ayahPad = ayah.padStart(3, '0');
  const hosts = [
    'https://mirrors.quranicaudio.com/everyayah',  // 0: primary mirror
    'https://everyayah.com/data',                   // 1: direct everyayah
    `https://cdn.islamic.network/quran/audio/128`,  // 2: islamic.network CDN
  ];
  const host = hosts[mirror] || hosts[0];
  // islamic.network uses a different path format: /{reciter}/{sura}{ayah}.mp3 → already ok
  return `${host}/${reciterId}/${suraPad}${ayahPad}.mp3`;
}

function playAyah(verseKey) {
  if (currentAudio) {
    currentAudio.pause();
  }
  
  currentPlayingKey = verseKey;
  isAudioPlaying = true;
  
  let _mirrorIndex = 0;
  function tryPlay(url) {
    currentAudio = new Audio(url);
    currentAudio.onended = () => {
      playNextAyah();
    };
    
    currentAudio.play().then(() => {
      updateAudioUI();
    }).catch(err => {
      console.warn(`Audio playback failed on ${url}:`, err);
      _mirrorIndex++;
      if (_mirrorIndex <= 2) {
        const fallbackUrl = getAudioUrl(verseKey, state.activeReciter, _mirrorIndex);
        console.log(`Trying mirror ${_mirrorIndex}: ${fallbackUrl}`);
        tryPlay(fallbackUrl);
      } else {
        console.error('Audio playback failed on all mirrors:', err);
        isAudioPlaying = false;
        currentPlayingKey = null;
        updateAudioUI();
      }
    });
  }

  const url = getAudioUrl(verseKey, state.activeReciter, 0);
  tryPlay(url);
}

function pauseAyah() {
  if (currentAudio) {
    currentAudio.pause();
    isAudioPlaying = false;
    updateAudioUI();
  }
}

function togglePlayAyah(verseKey) {
  // If the caller is the global player bar re-playing the old key,
  // but the user has since selected a different verse, redirect to that verse.
  const selectedKey = (state.currentSuraId && state.currentAyahNum)
    ? `${state.currentSuraId}:${state.currentAyahNum}`
    : null;
  if (verseKey === currentPlayingKey && selectedKey && selectedKey !== currentPlayingKey) {
    playAyah(selectedKey);
    return;
  }

  if (currentPlayingKey === verseKey) {
    if (isAudioPlaying) {
      pauseAyah();
    } else {
      if (currentAudio) {
        currentAudio.play().then(() => {
          isAudioPlaying = true;
          updateAudioUI();
        });
      } else {
        playAyah(verseKey);
      }
    }
  } else {
    playAyah(verseKey);
  }
}

function playNextAyah() {
  if (!currentPlayingKey) return;
  const [sura, ayah] = currentPlayingKey.split(':').map(Number);
  
  const suraMeta = db.suraList.find(s => s.id === sura);
  if (!suraMeta) return;
  
  if (ayah < suraMeta.ayas) {
    const nextKey = `${sura}:${ayah + 1}`;
    const hash = window.location.hash;
    const isViewingThisSuraList = hash === `#sura/${sura}`;
    const isViewingDetail = hash.startsWith(`#sura/${sura}/verse/`);
    
    if (isViewingThisSuraList) {
      const perPage = state.ayahPerPage || 25;
      const targetPage = Math.floor(ayah / perPage) + 1; // Since next index is `ayah`
      
      if (targetPage !== suraPage) {
        suraPage = targetPage;
        const allVerseKeys = [];
        for (let i = 1; i <= suraMeta.ayas; i++) {
          allVerseKeys.push(`${sura}:${i}`);
        }
        renderSuraPage(allVerseKeys, sura, suraMeta);
      }
    } else if (isViewingDetail) {
      window.location.hash = `#sura/${sura}/verse/${ayah + 1}`;
    } else if (hash === '#mushaf') {
      // Mushaf mode: load page first, then play audio so highlight appears correctly
      (async () => {
        const targetPage = await getVersePageNumber(sura, ayah + 1);
        if (targetPage && targetPage !== mushafCurrentPage) {
          mushafCurrentPage = targetPage;
          const slider = document.getElementById('mushaf-page-slider');
          if (slider) slider.value = targetPage;
          updateMushafPageLabel();
          await loadMushafPage(targetPage);
        }
        await showMushafVerseDetail(sura, ayah + 1);
        playAyah(nextKey);
      })();
      return; // audio handled inside async block above
    }
    
    setTimeout(() => {
      const nextCard = document.getElementById(`v-${nextKey.replace(':', '-')}`);
      if (nextCard) {
        nextCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 200);
    
    playAyah(nextKey);
  } else {
    // End of sura, check for next sura
    if (sura < 114) {
      const nextSura = sura + 1;
      const hash = window.location.hash;
      if (hash === '#mushaf') {
        // Mushaf mode: load next sura's page then play
        (async () => {
          const targetPage = await getVersePageNumber(nextSura, 1);
          if (targetPage && targetPage !== mushafCurrentPage) {
            mushafCurrentPage = targetPage;
            const slider = document.getElementById('mushaf-page-slider');
            if (slider) slider.value = targetPage;
            updateMushafPageLabel();
            await loadMushafPage(targetPage);
          }
          await showMushafVerseDetail(nextSura, 1);
          playAyah(`${nextSura}:1`);
        })();
        return; // audio handled inside async block
      } else if (state.mushafSplitMode || isViewingDetail) {
        window.location.hash = `#sura/${nextSura}/verse/1`;
      } else {
        window.location.hash = `#sura/${nextSura}`;
      }
      setTimeout(() => {
        playAyah(`${nextSura}:1`);
      }, 1000);
    } else {
      stopAudio();
    }
  }
}

function playPrevAyah() {
  if (!currentPlayingKey) return;
  const [sura, ayah] = currentPlayingKey.split(':').map(Number);
  
  if (ayah > 1) {
    const prevKey = `${sura}:${ayah - 1}`;
    const hash = window.location.hash;
    const isViewingThisSuraList = hash === `#sura/${sura}`;
    const isViewingDetail = hash.startsWith(`#sura/${sura}/verse/`);
    
    if (isViewingThisSuraList) {
      const perPage = state.ayahPerPage || 25;
      const targetPage = Math.floor((ayah - 2) / perPage) + 1; // Since prev index is `ayah - 2`
      
      if (targetPage !== suraPage) {
        suraPage = targetPage;
        const suraMeta = db.suraList.find(s => s.id === sura);
        const allVerseKeys = [];
        for (let i = 1; i <= suraMeta.ayas; i++) {
          allVerseKeys.push(`${sura}:${i}`);
        }
        renderSuraPage(allVerseKeys, sura, suraMeta);
      }
    } else if (isViewingDetail) {
      window.location.hash = `#sura/${sura}/verse/${ayah - 1}`;
    } else if (hash === '#mushaf') {
      (async () => {
        const targetPage = await getVersePageNumber(sura, ayah - 1);
        if (targetPage && targetPage !== mushafCurrentPage) {
          mushafCurrentPage = targetPage;
          const slider = document.getElementById('mushaf-page-slider');
          if (slider) slider.value = targetPage;
          updateMushafPageLabel();
          await loadMushafPage(targetPage);
        }
        showMushafVerseDetail(sura, ayah - 1);
      })();
    }
    
    setTimeout(() => {
      const prevCard = document.getElementById(`v-${prevKey.replace(':', '-')}`);
      if (prevCard) {
        prevCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 200);
    
    playAyah(prevKey);
  } else {
    if (sura > 1) {
      const prevSura = sura - 1;
      const prevSuraMeta = db.suraList.find(s => s.id === prevSura);
      if (prevSuraMeta) {
        const hash = window.location.hash;
        if (hash === '#mushaf') {
          (async () => {
            const targetPage = await getVersePageNumber(prevSura, prevSuraMeta.ayas);
            if (targetPage && targetPage !== mushafCurrentPage) {
              mushafCurrentPage = targetPage;
              const slider = document.getElementById('mushaf-page-slider');
              if (slider) slider.value = targetPage;
              updateMushafPageLabel();
              await loadMushafPage(targetPage);
            }
            showMushafVerseDetail(prevSura, prevSuraMeta.ayas);
          })();
        } else if (state.mushafSplitMode || isViewingDetail) {
          window.location.hash = `#sura/${prevSura}/verse/${prevSuraMeta.ayas}`;
        } else {
          window.location.hash = `#sura/${prevSura}`;
        }
        setTimeout(() => {
          playAyah(`${prevSura}:${prevSuraMeta.ayas}`);
        }, 1000);
      }
    }
  }
}

function stopAudio() {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio = null;
  }
  currentPlayingKey = null;
  isAudioPlaying = false;
  updateAudioUI();
}

function getOrCreatePlayerBar() {
  let player = document.getElementById('global-audio-player');
  if (!player) {
    player = document.createElement('div');
    player.id = 'global-audio-player';
    player.className = 'global-audio-player';
    player.innerHTML = `
      <div class="gap-content">
        <div class="gap-info">
          <div class="gap-title" id="gap-title">Sura Name</div>
          <div class="gap-reciter" id="gap-reciter">Reciter Name</div>
        </div>
        <div class="gap-controls">
          <button class="gap-btn" id="gap-prev" title="Previous Ayah">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6L18 6v12z"/></svg>
          </button>
          <button class="gap-btn gap-play-main" id="gap-play-pause" title="Play/Pause">
            <svg class="play-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            <svg class="pause-icon" viewBox="0 0 24 24" fill="currentColor" style="display:none;"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
          </button>
          <button class="gap-btn" id="gap-next" title="Next Ayah">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 18V6l8.5 6L6 18zm9-12h2v12h-2z"/></svg>
          </button>
          <button class="gap-btn gap-close" id="gap-close" title="Close Player">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
          </button>
        </div>
      </div>
    `;
    document.body.appendChild(player);
    
    document.getElementById('gap-prev').onclick = playPrevAyah;
    document.getElementById('gap-next').onclick = playNextAyah;
    document.getElementById('gap-play-pause').onclick = () => {
      if (currentPlayingKey) {
        togglePlayAyah(currentPlayingKey);
      }
    };
    document.getElementById('gap-close').onclick = stopAudio;
  }
  return player;
}

function updateAudioUI() {
  document.querySelectorAll('.btn-play-ayah').forEach(btn => {
    const key = btn.dataset.key;
    const isCurrent = (key === currentPlayingKey);
    const isPlaying = isCurrent && isAudioPlaying;
    
    btn.classList.toggle('playing', isPlaying);
    const playSvg = btn.querySelector('.play-icon');
    const pauseSvg = btn.querySelector('.pause-icon');
    if (playSvg && pauseSvg) {
      playSvg.style.display = isPlaying ? 'none' : 'block';
      pauseSvg.style.display = isPlaying ? 'block' : 'none';
    }
  });

  const player = getOrCreatePlayerBar();
  if (currentPlayingKey) {
    player.classList.add('visible');
    
    const [sura, ayah] = currentPlayingKey.split(':');
    const suraMeta = db.suraList ? db.suraList.find(s => s.id === Number(sura)) : null;
    const name = suraMeta ? (state.uiLang === 'id' ? suraMeta.name_id : suraMeta.name_en) : `Sura ${sura}`;
    
    document.getElementById('gap-title').textContent = `${name} : ${ayah}`;
    
    const reciter = db.registry.reciters ? db.registry.reciters.find(r => r.id === state.activeReciter) : null;
    document.getElementById('gap-reciter').textContent = reciter ? reciter.name : state.activeReciter;
    
    const mainPlayBtn = document.getElementById('gap-play-pause');
    const playIcon = mainPlayBtn.querySelector('.play-icon');
    const pauseIcon = mainPlayBtn.querySelector('.pause-icon');
    if (playIcon && pauseIcon) {
      playIcon.style.display = isAudioPlaying ? 'none' : 'block';
      pauseIcon.style.display = isAudioPlaying ? 'block' : 'none';
    }
  } else {
    player.classList.remove('visible');
  }

  // Update Mushaf detail play/pause button if it exists
  const mushafPlayBtn = document.getElementById('btn-play-mushaf-ayah');
  if (mushafPlayBtn) {
    const isPlaying = (currentPlayingKey === `${state.currentSuraId}:${state.currentAyahNum}` && isAudioPlaying);
    mushafPlayBtn.textContent = isPlaying ? 'Pause Audio ⏸' : 'Play Audio ▶';
  }

  // Sync Mushaf SVG highlight
  if (typeof syncMushafHighlight === 'function') {
    syncMushafHighlight();
  }
}

// =====================================================================
// --- MUSHAF CONTROLLER ---
// =====================================================================
let mushafCurrentPage = 1;

async function initMushafView() {
  const slider = document.getElementById('mushaf-page-slider');
  const prevBtn = document.getElementById('mushaf-prev-btn');
  const nextBtn = document.getElementById('mushaf-next-btn');
  if (!slider) return;
  slider.addEventListener('input', () => {
    mushafCurrentPage = parseInt(slider.value);
    updateMushafPageLabel();
    loadMushafPage(mushafCurrentPage);
  });
  prevBtn && prevBtn.addEventListener('click', () => {
    if (mushafCurrentPage > 1) { mushafCurrentPage--; slider.value = mushafCurrentPage; updateMushafPageLabel(); loadMushafPage(mushafCurrentPage); }
  });
  nextBtn && nextBtn.addEventListener('click', () => {
    if (mushafCurrentPage < 604) { mushafCurrentPage++; slider.value = mushafCurrentPage; updateMushafPageLabel(); loadMushafPage(mushafCurrentPage); }
  });
  loadMushafPage(mushafCurrentPage);
}

function updateMushafPageLabel() {
  const el = document.getElementById('mushaf-page-label');
  if (el) el.textContent = `Page ${mushafCurrentPage} / 604`;
}

async function getVersePageNumber(suraId, ayahNum) {
  if (supabaseClient) {
    try {
      const { data } = await supabaseClient
        .from('verses')
        .select('page_number')
        .eq('verse_key', `${suraId}:${ayahNum}`)
        .maybeSingle();
      if (data && data.page_number) return data.page_number;
    } catch (e) {
      console.warn('[Page lookup] failed:', e);
    }
  }
  return null;
}
window.getVersePageNumber = getVersePageNumber;

function syncMushafHighlight() {
  const wrapper = document.querySelector('.mushaf-svg-wrapper');
  if (!wrapper) return;

  // Clear previous fills
  wrapper.querySelectorAll('.ayahPolygon').forEach(el => {
    el.style.fill = '';
    el.style.fillOpacity = '';
  });

  // 1. Highlight manual selection (or current verse)
  const selSura = state.currentSuraId;
  const selAyah = state.currentAyahNum;
  if (selSura && selAyah) {
    wrapper.querySelectorAll(`[surah="${selSura}"][ayah="${selAyah}"]`).forEach(el => {
      el.style.fill = 'rgba(201,151,58,0.22)';
      el.style.fillOpacity = '1';
    });
  }

  // 2. Highlight currently playing verse (audio playing)
  if (currentPlayingKey && isAudioPlaying) {
    const [playSura, playAyah] = currentPlayingKey.split(':');
    wrapper.querySelectorAll(`[surah="${playSura}"][ayah="${playAyah}"]`).forEach(el => {
      el.style.fill = 'rgba(201,151,58,0.45)';
      el.style.fillOpacity = '1';
    });
  }
}
window.syncMushafHighlight = syncMushafHighlight;

function closeMushafDetailPane(e) {
  if (e) {
    e.preventDefault();
    e.stopPropagation();
  }
  const detailPane = document.getElementById('mushaf-detail-pane');
  if (detailPane) detailPane.style.display = 'none';
  state.currentSuraId = null;
  state.currentAyahNum = null;
  syncMushafHighlight();
}
window.closeMushafDetailPane = closeMushafDetailPane;

async function loadMushafPage(pageNum) {
  const container = document.getElementById('mushaf-page-container');
  if (!container) return;
  container.innerHTML = `<div class="mushaf-loading">Loading page ${pageNum}…</div>`;
  const padded = String(pageNum).padStart(3, '0');
  const svgUrl = `https://cdn.jsdelivr.net/gh/quranpedia/quran-svg@main/mushafs/hafs/kfqc/svg/${padded}.svg`;
  try {
    const res = await fetch(svgUrl);
    if (!res.ok) throw new Error('SVG fetch failed');
    const svgText = await res.text();
    const wrapper = document.createElement('div');
    wrapper.className = 'mushaf-svg-wrapper';
    wrapper.innerHTML = svgText;
    const svg = wrapper.querySelector('svg');
    if (svg) {
      svg.style.cssText = 'width:100%;height:auto;max-height:calc(100vh - 160px);display:block;';
      svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
      const style = document.createElement('style');
      style.textContent = `
        .ayahPolygon { fill: transparent; fill-opacity: 0; cursor: pointer; pointer-events: auto !important; transition: fill 0.15s, fill-opacity 0.15s; }
        .ayahPolygon:hover { fill: rgba(201,151,58,0.18) !important; fill-opacity: 1 !important; }
        svg *:not(.ayahPolygon) { pointer-events: none !important; }
        /* Custom overrides to prevent dark text on dark background in Mushaf SVGs */
        svg path[fill="#231f20"],
        svg path[fill="#000000"],
        svg path[fill="#000"],
        svg path[fill="black"],
        svg [fill="#231f20"],
        svg [fill="#000000"] {
          fill: var(--mushaf-text-color) !important;
        }
        svg rect[fill="#ffffff"],
        svg rect[fill="#fff"],
        svg rect[fill="white"] {
          fill: transparent !important;
        }
      `;
      svg.prepend(style);
    }
    container.innerHTML = '';
    container.appendChild(wrapper);
    
    // Automatically apply highlights
    syncMushafHighlight();

    wrapper.addEventListener('click', (e) => {
      let t = e.target;
      while (t && t !== wrapper) {
        const sura = t.getAttribute('surah');
        const ayah = t.getAttribute('ayah');
        if (sura && ayah) {
          const suraNum = parseInt(sura, 10);
          const ayahNum = parseInt(ayah, 10);
          state.currentSuraId = suraNum;
          state.currentAyahNum = ayahNum;
          
          if (state.mushafSplitMode) {
            window.location.hash = `#sura/${suraNum}/verse/${ayahNum}`;
          } else {
            showMushafVerseDetail(suraNum, ayahNum);
          }
          return;
        }
        t = t.parentElement;
      }
    });
  } catch (err) {
    container.innerHTML = `<img src="https://quran.ksu.edu.sa/png_big/${pageNum}.png" style="max-width:100%;max-height:calc(100vh - 160px);display:block;margin:auto;" alt="Quran Page ${pageNum}" />`;
  }
}

async function showMushafVerseDetail(surahNum, ayahNum) {
  state.currentSuraId = surahNum;
  state.currentAyahNum = ayahNum;
  
  const emptyEl = document.getElementById('mushaf-detail-empty');
  const contentEl = document.getElementById('mushaf-detail-content');
  const detailPane = document.getElementById('mushaf-detail-pane');
  if (!contentEl) return;
  if (emptyEl) emptyEl.style.display = 'none';
  contentEl.style.display = 'block';
  if (detailPane) detailPane.style.display = 'flex';
  contentEl.innerHTML = '<div class="mushaf-detail-loading">Loading…</div>';

  // Ensure active datasets are loaded (translation + tafsir) for this surah
  await ensureActiveDatasets(surahNum);

  const verseKey = `${surahNum}:${ayahNum}`;
  const arabicText = db.quranArabic ? (db.quranArabic[verseKey] || '') : '';
  const transSource = state.activeTranslation1 || 'en.shakir';
  const tafsirSource = state.activeTafsir1 || 'id.jalalayn';
  let transText = '', tafsirText = '';

  if (supabaseClient) {
    try {
      const [{ data: transData }, { data: tafsirData }] = await Promise.all([
        supabaseClient.from('translations').select('text').eq('verse_key', verseKey).eq('source_id', transSource).maybeSingle(),
        supabaseClient.from('tafsirs').select('text').eq('verse_key', verseKey).eq('source_id', tafsirSource).maybeSingle()
      ]);
      if (transData) transText = transData.text;
      if (tafsirData) tafsirText = tafsirData.text;
    } catch (e) { console.warn('[Mushaf] verse detail fetch failed:', e); }
  }

  // Fallback to local cache if Supabase returned empty (incomplete DB rows)
  if (!transText) {
    const tInfo = db.registry && db.registry.translations.find(t => t.id === transSource);
    if (tInfo) {
      const localCacheKey = tInfo.file.replace('.chunks.json', '.json');
      const cached = db.cache.get(localCacheKey);
      if (cached && cached[verseKey]) transText = cached[verseKey];
    }
  }
  if (!tafsirText) {
    const tInfo = db.registry && db.registry.tafsirs.find(t => t.id === tafsirSource);
    if (tInfo) {
      const cached = getTafsirData(tInfo);
      const resolved = resolveTafsirText(cached, verseKey);
      if (resolved) tafsirText = resolved;
    }
  }
  
  // Apply visual highlight immediately on selection
  syncMushafHighlight();
  
  const suraMeta = db.suraList ? db.suraList.find(s => s.id === surahNum) : null;
  const suraName = suraMeta ? (state.uiLang === 'id' ? suraMeta.name_id : suraMeta.name_en) : `Surah ${surahNum}`;
  
  const isPlaying = (currentPlayingKey === verseKey && isAudioPlaying);
  const playLabel = isPlaying ? 'Pause Audio ⏸' : 'Play Audio ▶';
  
  const isBookmarked = bookmarks.has(verseKey);
  contentEl.innerHTML = `
    <div class="mushaf-verse-key" style="display:flex;align-items:center;justify-content:space-between;">
      <span>${suraName} ${verseKey}</span>
      <button class="btn-icon btn-bookmark" id="btn-mushaf-bookmark" aria-pressed="${isBookmarked}" title="${isBookmarked ? 'Remove bookmark' : 'Bookmark verse'}" style="padding:4px;">
        <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" fill="${isBookmarked ? 'currentColor' : 'none'}" style="width:18px;height:18px;"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>
      </button>
    </div>
    ${arabicText ? `<div class="mushaf-verse-arabic" lang="ar">${arabicText}</div>` : ''}
    ${transText ? `<div class="mushaf-verse-trans">${transText}</div>` : ''}
    ${tafsirText ? `<details class="mushaf-verse-tafsir-wrap"><summary>Tafsir</summary><div class="mushaf-verse-tafsir">${tafsirText}</div></details>` : ''}
    <div class="mushaf-detail-actions" style="display:flex;gap:0.5rem;margin-top:1rem;">
      <button class="btn btn-primary" id="btn-play-mushaf-ayah" style="flex:1;text-align:center;" onclick="togglePlayAyah('${verseKey}')">
        ${playLabel}
      </button>
      <button class="btn btn-outline" style="flex:1;text-align:center;" onclick="openMushafSplitDetail(${surahNum}, ${ayahNum})">Open Detail →</button>
    </div>
  `;
  // Wire bookmark button
  const bBtn = document.getElementById('btn-mushaf-bookmark');
  if (bBtn) {
    bBtn.onclick = () => {
      toggleBookmark(verseKey);
      const now = bookmarks.has(verseKey);
      bBtn.setAttribute('aria-pressed', String(now));
      bBtn.title = now ? 'Remove bookmark' : 'Bookmark verse';
      const svg = bBtn.querySelector('svg');
      if (svg) svg.setAttribute('fill', now ? 'currentColor' : 'none');
    };
  }
}

function openMushafSplitDetail(suraId, ayahId) {
  state.mushafSplitMode = true;
  document.body.classList.add('split-mushaf-mode');
  const sidebar = document.getElementById('sidebar');
  if (sidebar) sidebar.classList.add('collapsed');
  window.location.hash = `#sura/${suraId}/verse/${ayahId}`;
}
window.openMushafSplitDetail = openMushafSplitDetail;
window.togglePlayAyah = togglePlayAyah;

// =====================================================================
// --- AUTH CONTROLLER ---
// =====================================================================
async function initAuth() {
  if (!supabaseClient) return;

  const { data: { session } } = await supabaseClient.auth.getSession();
  if (session) await handleAuthSession(session);

  supabaseClient.auth.onAuthStateChange(async (event, session) => {
    if (session) {
      await handleAuthSession(session);
      if (event === 'SIGNED_IN') {
        // Clean up hash fragment after OAuth login
        const restoreHash = localStorage.getItem('auth_redirect_hash');
        if (restoreHash && !restoreHash.includes('access_token')) {
          localStorage.removeItem('auth_redirect_hash');
          window.location.hash = restoreHash;
        } else if (window.location.hash.includes('access_token')) {
          window.location.hash = '#home';
        }
      }
    } else if (event === 'SIGNED_OUT') {
      handleAuthSignOut();
    }
  });

  document.getElementById('auth-login-btn')?.addEventListener('click', async () => {
    const email = document.getElementById('auth-email')?.value.trim();
    const password = document.getElementById('auth-password')?.value;
    const errEl = document.getElementById('auth-error');
    if (!email || !password) { if (errEl) { errEl.textContent = 'Please enter email and password.'; errEl.style.display = 'block'; } return; }
    if (errEl) errEl.style.display = 'none';
    const { error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error && errEl) { errEl.textContent = error.message; errEl.style.display = 'block'; }
  });

  document.getElementById('auth-logout-btn')?.addEventListener('click', async () => {
    await supabaseClient.auth.signOut();
  });

  // Google OAuth sign-in
  document.getElementById('auth-google-login')?.addEventListener('click', async () => {
    const errEl = document.getElementById('auth-error');
    if (errEl) errEl.style.display = 'none';
    const btn = document.getElementById('auth-google-login');
    if (btn) { btn.disabled = true; btn.style.opacity = '0.7'; }
    localStorage.setItem('auth_redirect_hash', window.location.hash || '#home');
    const { error } = await supabaseClient.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: window.location.origin + '/'
      }
    });
    if (error) {
      if (errEl) { errEl.textContent = 'Google sign-in failed: ' + error.message; errEl.style.display = 'block'; }
      if (btn) { btn.disabled = false; btn.style.opacity = ''; }
    }
  });
}

async function handleAuthSession(session) {
  if (!session || !session.user) return;
  currentUser = session.user;
  
  try {
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('display_name, role, avatar_url')
      .eq('id', currentUser.id)
      .maybeSingle();
    currentUserProfile = profile;
  } catch (e) {
    console.warn('Profile fetch error:', e);
  }

  const name = currentUserProfile?.display_name || currentUser.email.split('@')[0];
  const elOut = document.getElementById('auth-logged-out');
  const elIn = document.getElementById('auth-logged-in');
  if (elOut) elOut.style.display = 'none';
  if (elIn) elIn.style.display = 'block';

  const nameEl = document.getElementById('auth-user-name');
  const emailEl = document.getElementById('auth-user-email');
  const avatarEl = document.getElementById('auth-avatar-initial');
  if (nameEl) nameEl.textContent = name;
  if (emailEl) emailEl.textContent = currentUser.email;
  if (avatarEl) avatarEl.textContent = name[0].toUpperCase();

  const isAdmin = currentUserProfile?.role === 'admin' || currentUser.app_metadata?.role === 'admin' || currentUser.user_metadata?.role === 'admin';
  const adminTab = document.getElementById('tab-admin');
  if (adminTab) {
    adminTab.style.display = isAdmin ? '' : 'none';
  }
}

function handleAuthSignOut() {
  currentUser = null; currentUserProfile = null;
  const elOut = document.getElementById('auth-logged-out');
  const elIn = document.getElementById('auth-logged-in');
  if (elOut) elOut.style.display = 'block';
  if (elIn) elIn.style.display = 'none';
  const adminTab = document.getElementById('tab-admin');
  if (adminTab) adminTab.style.display = 'none';
}

// =====================================================================
// --- ADMIN CMS CONTROLLER (full-screen overlay) ---
// =====================================================================

let cmsActiveSurahId = 1;
let cmsActiveVerseId = null;

// Open / close the full-screen CMS overlay
function openAdminCms() {
  if (!currentUser || currentUserProfile?.role !== 'admin') {
    alert('Admin access requires signing in with an Admin account. Please sign in under Settings > Account.');
    // Switch to settings panel
    document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
    document.getElementById('tab-settings')?.classList.add('active');
    document.querySelectorAll('.sidebar-content .panel').forEach(p => p.classList.remove('active'));
    document.getElementById('panel-settings')?.classList.add('active');
    window.location.hash = '#home';
    return;
  }

  const overlay = document.getElementById('cms-overlay');
  if (!overlay) return;
  overlay.style.display = 'flex';
  document.body.style.overflow = 'hidden';

  // Populate user info from current session
  const name = currentUserProfile.display_name || currentUser?.email || 'Admin';
  const el = document.getElementById('cms-user-name');
  const elEmail = document.getElementById('cms-user-email');
  const elAvatar = document.getElementById('cms-user-avatar');
  if (el) el.textContent = name;
  if (elEmail) elEmail.textContent = currentUser?.email || '';
  if (elAvatar) elAvatar.textContent = name[0].toUpperCase();

  cmsLoadDashboardStats();
}

function closeAdminCms() {
  const overlay = document.getElementById('cms-overlay');
  if (overlay) overlay.style.display = 'none';
  document.body.style.overflow = '';
}

// CMS Nav routing
document.querySelectorAll('.cms-nav-item').forEach(item => {
  item.addEventListener('click', e => {
    e.preventDefault();
    const viewId = item.getAttribute('data-cms-view');
    document.querySelectorAll('.cms-nav-item').forEach(n => n.classList.remove('active'));
    item.classList.add('active');
    document.querySelectorAll('.cms-view').forEach(v => v.classList.remove('active'));
    const view = document.getElementById(viewId);
    if (view) view.classList.add('active');
    const titles = {
      'cms-dashboard': 'Dashboard Overview',
      'cms-verses': 'Verse Content Editor',
      'cms-config': 'Site Settings CMS',
      'cms-tags': 'Tags Manager',
      'cms-database': 'Database Tool (CSV)',
    };
    const titleEl = document.getElementById('cms-view-title');
    if (titleEl) titleEl.textContent = titles[viewId] || '';
    if (viewId === 'cms-dashboard') cmsLoadDashboardStats();
    if (viewId === 'cms-verses') cmsLoadSurahsDropdown();
    if (viewId === 'cms-config') cmsLoadSiteConfig();
    if (viewId === 'cms-tags') cmsLoadTags();
  });
});

// Refresh button
document.getElementById('cms-refresh-btn')?.addEventListener('click', () => {
  const active = document.querySelector('.cms-view.active')?.id;
  if (active === 'cms-dashboard') cmsLoadDashboardStats();
  if (active === 'cms-verses') { cmsLoadSurahsDropdown(); cmsResetVerseEditor(); }
  if (active === 'cms-config') cmsLoadSiteConfig();
  if (active === 'cms-tags') cmsLoadTags();
});

// ── A. DASHBOARD STATS ────────────────────────────────────────────────────
async function cmsLoadDashboardStats() {
  if (!supabaseClient) return;
  const targets = [
    { id: 'cms-stat-verses', table: 'verses' },
    { id: 'cms-stat-translations', table: 'translations' },
    { id: 'cms-stat-tafsirs', table: 'tafsirs' },
    { id: 'cms-stat-tags', table: 'tags' },
    { id: 'cms-stat-verse-tags', table: 'verse_tags' },
    { id: 'cms-stat-nuzul', table: 'asbabun_nuzul' },
  ];
  for (const t of targets) {
    try {
      const { count } = await supabaseClient.from(t.table).select('*', { count: 'exact', head: true });
      const el = document.getElementById(t.id);
      if (el && count !== null) el.textContent = count >= 1000000 ? (count/1000000).toFixed(1)+'M' : count >= 1000 ? (count/1000).toFixed(1)+'K' : count;
    } catch (_) {}
  }
}

// ── B. VERSE EDITOR ───────────────────────────────────────────────────────
async function cmsLoadSurahsDropdown() {
  const select = document.getElementById('cms-select-surah');
  if (!select || !supabaseClient) return;
  select.innerHTML = '<option>Loading…</option>';
  try {
    const { data } = await supabaseClient.from('surahs').select('id,name_en,name_id').order('id');
    select.innerHTML = data.map(s => `<option value="${s.id}">${s.id}. ${s.name_en} (${s.name_id||''})</option>`).join('');
    cmsActiveVerseId = data[0]?.id;
    cmsLoadVersesList(data[0]?.id);
  } catch(_) { select.innerHTML = '<option>Error</option>'; }
}

document.getElementById('cms-select-surah')?.addEventListener('change', e => {
  cmsActiveSurahId = parseInt(e.target.value);
  cmsLoadVersesList(cmsActiveSurahId);
  cmsResetVerseEditor();
});

async function cmsLoadVersesList(surahId) {
  const tbody = document.getElementById('cms-verse-list-body');
  if (!tbody || !supabaseClient) return;
  cmsActiveSurahId = surahId;
  tbody.innerHTML = '<tr><td colspan="2" style="text-align:center;padding:1.5rem;color:var(--text-muted)">Loading…</td></tr>';
  try {
    const { data } = await supabaseClient.from('verses').select('id,sura_id,ayah_number,text_ar').eq('sura_id', surahId).order('ayah_number');
    tbody.innerHTML = '';
    data.forEach(v => {
      const tr = document.createElement('tr');
      tr.innerHTML = `<td>${v.ayah_number}</td><td style="font-family:'Noto Naskh Arabic',serif;font-size:1rem;direction:rtl">${(v.text_ar||'').substring(0,35)}…</td>`;
      tr.addEventListener('click', () => {
        tbody.querySelectorAll('tr').forEach(r => r.classList.remove('cms-selected'));
        tr.classList.add('cms-selected');
        cmsLoadVerseDetail(v.id, v.ayah_number);
      });
      tbody.appendChild(tr);
    });
  } catch(_) { tbody.innerHTML = '<tr><td colspan="2" class="cms-empty">Error loading verses</td></tr>'; }
}

function cmsResetVerseEditor() {
  const empty = document.getElementById('cms-editor-empty');
  const form = document.getElementById('cms-editor-form');
  if (empty) empty.style.display = '';
  if (form) form.style.display = 'none';
  cmsActiveVerseId = null;
}

async function cmsLoadVerseDetail(verseId, ayahNum) {
  cmsActiveVerseId = verseId;
  const empty = document.getElementById('cms-editor-empty');
  const form = document.getElementById('cms-editor-form');
  if (empty) empty.style.display = 'none';
  if (form) form.style.display = 'flex';
  document.getElementById('cms-edit-verse-label').textContent = `${cmsActiveSurahId}:${ayahNum}`;
  ['cms-edit-arabic','cms-edit-trans-id','cms-edit-trans-en','cms-edit-tafsir-jalalayn','cms-edit-tafsir-katsir','cms-edit-nuzul'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = id === 'cms-edit-arabic' ? 'Loading…' : '';
  });
  try {
    const [{ data: verse }, { data: trans }, { data: tafsirs }, { data: nuzul }] = await Promise.all([
      supabaseClient.from('verses').select('text_ar').eq('id', verseId).maybeSingle(),
      supabaseClient.from('translations').select('source_id,text').eq('verse_id', verseId),
      supabaseClient.from('tafsirs').select('tafsir_id,text').eq('verse_id', verseId),
      supabaseClient.from('asbabun_nuzul').select('source,text').eq('verse_id', verseId),
    ]);
    const ar = document.getElementById('cms-edit-arabic');
    if (ar) ar.value = verse?.text_ar || '';
    const transMap = Object.fromEntries((trans||[]).map(t => [t.source_id, t.text]));
    const tafsirMap = Object.fromEntries((tafsirs||[]).map(t => [t.tafsir_id, t.text]));
    const nuzulMap = Object.fromEntries((nuzul||[]).map(n => [n.source, n.text]));
    const set = (id, val) => { const el = document.getElementById(id); if (el) el.value = val || ''; };
    set('cms-edit-trans-id', transMap['id.kemenag']);
    set('cms-edit-trans-en', transMap['en.sahih'] || transMap['en.sahih-international']);
    set('cms-edit-tafsir-jalalayn', tafsirMap['id.jalalayn']);
    set('cms-edit-tafsir-katsir', tafsirMap['en.katsir'] || tafsirMap['en.ibn-kathir']);
    set('cms-edit-nuzul', nuzulMap['en.wahidi'] || nuzulMap['id.wahidi']);
  } catch(_) {}
}

document.getElementById('cms-btn-save-verse')?.addEventListener('click', async () => {
  if (!cmsActiveVerseId || !supabaseClient) return;
  const get = id => document.getElementById(id)?.value?.trim() || '';
  const upsertTrans = async (sourceId, text) => {
    if (!text) return;
    await supabaseClient.from('translations').upsert({ verse_id: cmsActiveVerseId, source_id: sourceId, text }, { onConflict: 'verse_id,source_id' });
  };
  const upsertTafsir = async (tafsirId, text) => {
    if (!text) return;
    await supabaseClient.from('tafsirs').upsert({ verse_id: cmsActiveVerseId, tafsir_id: tafsirId, text }, { onConflict: 'verse_id,tafsir_id' });
  };
  const btn = document.getElementById('cms-btn-save-verse');
  btn.textContent = 'Saving…'; btn.disabled = true;
  try {
    await Promise.all([
      upsertTrans('id.kemenag', get('cms-edit-trans-id')),
      upsertTrans('en.sahih', get('cms-edit-trans-en')),
      upsertTafsir('id.jalalayn', get('cms-edit-tafsir-jalalayn')),
      upsertTafsir('en.katsir', get('cms-edit-tafsir-katsir')),
      (async () => {
        const text = get('cms-edit-nuzul');
        if (text) await supabaseClient.from('asbabun_nuzul').upsert({ verse_id: cmsActiveVerseId, source: 'en.wahidi', text }, { onConflict: 'verse_id,source' });
      })(),
    ]);
    btn.textContent = '✓ Saved!';
    setTimeout(() => { btn.textContent = 'Save Changes'; btn.disabled = false; }, 2000);
  } catch(_) { btn.textContent = 'Error'; btn.disabled = false; }
});

// ── C. SITE CONFIG ────────────────────────────────────────────────────────
const _CFG_KEYS = ['home_hero_title','home_hero_subtitle','app_tagline','featured_rotation_mode','featured_ayah_key','featured_ayah_note','announcement_text'];
const _CFG_INPUT_MAP = {
  home_hero_title: 'cfg-hero-title',
  home_hero_subtitle: 'cfg-hero-subtitle',
  app_tagline: 'cfg-tagline',
  featured_rotation_mode: 'cfg-featured-rotation-mode',
  featured_ayah_key: 'cfg-featured-key',
  featured_ayah_note: 'cfg-featured-note',
  announcement_text: 'cfg-announcement',
};

async function cmsLoadSiteConfig() {
  if (!supabaseClient) return;
  const { data } = await supabaseClient.from('site_config').select('key,value').in('key', _CFG_KEYS);
  (data||[]).forEach(({ key, value }) => {
    const inputId = _CFG_INPUT_MAP[key];
    if (!inputId) return;
    const el = document.getElementById(inputId);
    if (el) el.value = value;
  });
  cmsLoadPlaylist();
}

document.getElementById('cms-config-form')?.addEventListener('submit', async e => {
  e.preventDefault();
  if (!supabaseClient) return;
  const configs = Object.entries(_CFG_INPUT_MAP).map(([key, inputId]) => ({
    key, value: document.getElementById(inputId)?.value?.trim() || ''
  }));
  const { error } = await supabaseClient.from('site_config').upsert(configs, { onConflict: 'key' });
  const statusEl = document.getElementById('cms-config-status');
  if (!error && statusEl) {
    statusEl.style.display = 'block';
    setTimeout(() => statusEl.style.display = 'none', 3000);
  }
});

async function cmsLoadPlaylist() {
  const tbody = document.getElementById('cms-playlist-tbody');
  if (!tbody || !supabaseClient) return;
  try {
    const { data } = await supabaseClient.from('featured_playlist').select('*').order('sort_order');
    if (!data || data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="cms-empty">No playlist entries yet</td></tr>'; return;
    }
    tbody.innerHTML = data.map(row => `
      <tr>
        <td>${row.verse_key}</td>
        <td>${row.note||'—'}</td>
        <td><button class="cms-btn cms-btn-danger" style="padding:3px 8px;font-size:0.78rem" onclick="cmsDeletePlaylistRow(${row.id})">Delete</button></td>
      </tr>`).join('');
  } catch(_) { tbody.innerHTML = '<tr><td colspan="3" class="cms-empty">Table not found</td></tr>'; }
}

async function cmsDeletePlaylistRow(id) {
  if (!supabaseClient) return;
  await supabaseClient.from('featured_playlist').delete().eq('id', id);
  cmsLoadPlaylist();
}

document.getElementById('cms-playlist-add-form')?.addEventListener('submit', async e => {
  e.preventDefault();
  if (!supabaseClient) return;
  const key = document.getElementById('cms-play-verse-key')?.value?.trim();
  const note = document.getElementById('cms-play-note')?.value?.trim();
  if (!key) return;
  await supabaseClient.from('featured_playlist').insert({ verse_key: key, note: note||null });
  document.getElementById('cms-play-verse-key').value = '';
  document.getElementById('cms-play-note').value = '';
  cmsLoadPlaylist();
});

// ── D. TAGS MANAGER ───────────────────────────────────────────────────────
let _allTags = [];

async function cmsLoadTags() {
  const tbody = document.getElementById('cms-tags-tbody');
  if (!tbody || !supabaseClient) return;
  tbody.innerHTML = '<tr><td colspan="5" class="cms-empty">Loading…</td></tr>';
  const { data } = await supabaseClient.from('tags').select('id,name,lang,parent_id').order('id');
  _allTags = data || [];
  cmsRenderTags();
}

function cmsRenderTags() {
  const tbody = document.getElementById('cms-tags-tbody');
  const langFilter = document.getElementById('cms-tags-lang-filter')?.value || 'all';
  const search = (document.getElementById('cms-tags-search')?.value || '').toLowerCase();
  const filtered = _allTags.filter(t =>
    (langFilter === 'all' || t.lang === langFilter) &&
    (!search || t.name.toLowerCase().includes(search) || (t.id+'').includes(search))
  );
  if (!filtered.length) { tbody.innerHTML = '<tr><td colspan="5" class="cms-empty">No tags found</td></tr>'; return; }
  tbody.innerHTML = filtered.slice(0, 200).map(t => `
    <tr>
      <td>${t.id}</td>
      <td>${t.name}</td>
      <td><span style="font-size:0.75rem;font-weight:600;text-transform:uppercase;color:var(--accent)">${t.lang}</span></td>
      <td>${t.parent_id||'—'}</td>
      <td><button class="cms-btn cms-btn-danger" style="padding:3px 8px;font-size:0.78rem" onclick="cmsDeleteTag('${t.id}','${t.lang}')">Delete</button></td>
    </tr>`).join('');
}

document.getElementById('cms-tags-lang-filter')?.addEventListener('change', cmsRenderTags);
document.getElementById('cms-tags-search')?.addEventListener('input', cmsRenderTags);

async function cmsDeleteTag(id, lang) {
  if (!confirm(`Delete tag "${id}" (${lang})?`)) return;
  await supabaseClient.from('tags').delete().eq('id', id).eq('lang', lang);
  await cmsLoadTags();
}

document.getElementById('cms-tag-create-form')?.addEventListener('submit', async e => {
  e.preventDefault();
  if (!supabaseClient) return;
  const name = document.getElementById('cms-tag-name')?.value?.trim();
  const lang = document.getElementById('cms-tag-lang')?.value;
  const parent = document.getElementById('cms-tag-parent')?.value?.trim() || null;
  if (!name) return;
  const { error } = await supabaseClient.from('tags').insert({ name, lang, parent_id: parent });
  const statusEl = document.getElementById('cms-tag-status');
  if (!error && statusEl) {
    statusEl.style.display = 'block';
    document.getElementById('cms-tag-name').value = '';
    document.getElementById('cms-tag-parent').value = '';
    setTimeout(() => statusEl.style.display = 'none', 2000);
    cmsLoadTags();
  }
});

// ── E. DATABASE TOOL (CSV IMPORT / EXPORT) ───────────────────────────────

document.getElementById('cms-btn-start-import')?.addEventListener('click', async () => {
  const fileInput = document.getElementById('cms-import-file');
  const type = document.getElementById('cms-import-type')?.value;
  const statusEl = document.getElementById('cms-import-status');
  const progressWrap = document.getElementById('cms-import-progress-wrap');
  const progressBar = document.getElementById('cms-import-progress-bar');
  const progressStatus = document.getElementById('cms-import-progress-status');
  if (!fileInput?.files[0]) { if(statusEl){ statusEl.style.display='block'; statusEl.className='cms-error-msg'; statusEl.textContent='Please select a CSV file first.'; } return; }
  const text = await fileInput.files[0].text();
  const lines = text.split('\n').filter(l => l.trim());
  const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g,''));
  const rows = lines.slice(1).map(l => {
    const vals = []; let cur='', inQ=false;
    for (const ch of l) { if(ch==='"') inQ=!inQ; else if(ch===','&&!inQ){vals.push(cur.trim());cur='';} else cur+=ch; }
    vals.push(cur.trim());
    return Object.fromEntries(headers.map((h,i) => [h, (vals[i]||'').replace(/^"|"$/g,'')]));
  });
  progressWrap.style.display='block'; statusEl.style.display='none';
  const BATCH = 50;
  let done = 0;
  for (let i=0; i<rows.length; i+=BATCH) {
    const batch = rows.slice(i, i+BATCH).map(r => ({
      verse_id: parseInt(r.verse_id||'0'),
      ...(type==='translations' ? { source_id: r.source_id, text: r.text } : {}),
      ...(type==='tafsirs' ? { tafsir_id: r.tafsir_id, text: r.text } : {}),
      ...(type==='asbabun_nuzul' ? { source: r.source, text: r.text } : {}),
    }));
    const conflictCol = type==='translations' ? 'verse_id,source_id' : type==='tafsirs' ? 'verse_id,tafsir_id' : 'verse_id,source';
    await supabaseClient.from(type==='asbabun_nuzul'?'asbabun_nuzul':type).upsert(batch, { onConflict: conflictCol });
    done += batch.length;
    const pct = Math.round((done/rows.length)*100);
    progressBar.style.width = pct+'%';
    progressStatus.textContent = `Processing: ${done} / ${rows.length} rows`;
  }
  statusEl.style.display='block'; statusEl.className='cms-success-msg';
  statusEl.textContent = `✓ Import complete: ${done} rows processed.`;
  progressWrap.style.display='none';
});

document.getElementById('cms-btn-start-export')?.addEventListener('click', async () => {
  const type = document.getElementById('cms-export-type')?.value;
  if (!supabaseClient || !type) return;
  const { data } = await supabaseClient.from(type).select('*').limit(100000);
  if (!data || !data.length) return;
  const cols = Object.keys(data[0]);
  const csv = [cols.join(','), ...data.map(row => cols.map(c => {
    const v = String(row[c]??''); return v.includes(',') || v.includes('"') || v.includes('\n') ? `"${v.replace(/"/g,'""')}"` : v;
  }).join(','))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href=url; a.download=`${type}_export.csv`; a.click();
  URL.revokeObjectURL(url);
});

function cmsGenerateTemplate(type) {
  const templates = {
    translations: 'verse_id,source_id,text',
    tafsirs: 'verse_id,tafsir_id,text',
    nuzul: 'verse_id,source,text',
  };
  const header = templates[type];
  const rows = Array.from({length:6236}, (_,i) => `${i+1},,`).join('\n');
  const csv = header+'\n'+rows;
  const blob = new Blob([csv], {type:'text/csv'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a'); a.href=url; a.download=`template_${type}.csv`; a.click();
  URL.revokeObjectURL(url);
}

document.getElementById('cms-btn-tpl-translations')?.addEventListener('click', () => cmsGenerateTemplate('translations'));
document.getElementById('cms-btn-tpl-tafsirs')?.addEventListener('click', () => cmsGenerateTemplate('tafsirs'));
document.getElementById('cms-btn-tpl-nuzul')?.addEventListener('click', () => cmsGenerateTemplate('nuzul'));



// =====================================================================
// --- ADVANCED SEARCH (Supabase-powered) ---
// =====================================================================
function initAdvancedSearch() {
  const btn   = document.getElementById('adv-search-btn');
  const input = document.getElementById('adv-search-input');
  if (!btn || !input) return;

  // ── Mode pills ──────────────────────────────────────────────────────
  const pillKeyword  = document.getElementById('mode-pill-keyword');
  const pillSemantic = document.getElementById('mode-pill-semantic');
  const optionsPanel = document.getElementById('adv-search-options-panel');
  const advToggleBtn = document.getElementById('adv-toggle-btn');

  let advOpen = false;  // advanced panel open state

  function applyMode(mode) {
    // 'keyword' or 'semantic'
    state.searchOptions.semantic = (mode === 'semantic');

    // Update hidden checkbox (kept for JS routing compat)
    const semCb = document.getElementById('adv-search-semantic');
    if (semCb) semCb.checked = state.searchOptions.semantic;

    // Toggle pill active class
    if (pillKeyword)  pillKeyword.classList.toggle('active',  mode === 'keyword');
    if (pillSemantic) pillSemantic.classList.toggle('active', mode === 'semantic');

    // Semantic mode: always hide source checkboxes
    // Keyword mode: show if advOpen
    if (optionsPanel) {
      const shouldShow = (mode === 'keyword') && advOpen;
      optionsPanel.style.display = shouldShow ? 'flex' : 'none';
    }
    if (advToggleBtn) {
      // hide advanced toggle in semantic mode
      advToggleBtn.style.display = (mode === 'semantic') ? 'none' : '';
    }

    saveSettings();
  }

  function toggleAdvPanel() {
    advOpen = !advOpen;
    if (optionsPanel) {
      optionsPanel.style.display = advOpen ? 'flex' : 'none';
    }
    if (advToggleBtn) {
      advToggleBtn.classList.toggle('active', advOpen);
      advToggleBtn.setAttribute('aria-expanded', advOpen);
    }
  }

  if (pillKeyword)  pillKeyword.addEventListener('click',  () => applyMode('keyword'));
  if (pillSemantic) pillSemantic.addEventListener('click', () => applyMode('semantic'));
  if (advToggleBtn) advToggleBtn.addEventListener('click', toggleAdvPanel);

  // Restore saved mode
  const savedMode = state.searchOptions.semantic ? 'semantic' : 'keyword';
  applyMode(savedMode);

  // ── Source checkboxes ────────────────────────────────────────────────
  const sourceOpts = ['quran', 'trans', 'tafsir', 'nuzul', 'tags'];
  sourceOpts.forEach(opt => {
    const el = document.getElementById(`adv-search-${opt}`);
    if (el) {
      el.checked = !!state.searchOptions[opt];
      el.onchange = () => {
        state.searchOptions[opt] = el.checked;
        saveSettings();
      };
    }
  });

  // ── Trigger search ───────────────────────────────────────────────────
  const doSearch = () => {
    const q = input.value.trim();
    if (q.length >= 2) window.location.hash = `#search/${encodeURIComponent(q)}`;
  };
  btn.addEventListener('click', doSearch);
  input.addEventListener('keypress', (e) => { if (e.key === 'Enter') doSearch(); });
}

// =====================================================================
// --- 10. Initialization Flow ---
// =====================================================================
async function initApp() {
  const progressFill = document.getElementById('splash-progress');
  const progressText = document.getElementById('splash-text');

  function updateProgress(percent, text) {
    if (progressFill) progressFill.style.width = percent + '%';
    if (progressText) progressText.textContent = text;
  }

  try {
    // 0. Init Supabase client
    initSupabase();

    // 1. Initialize database (loads static files + Supabase tags)
    await db.init(updateProgress);

    // 2. Build lookups
    tagLookup = new Map(db.tags.map(t => [t.id, t.name]));
    tagCounts = {};
    for (const verseKey in db.verseTags) {
      db.verseTags[verseKey].forEach(id => { tagCounts[id] = (tagCounts[id] || 0) + 1; });
    }

    // 3. Set styles and theme
    applyStyles();
    updateThemeButtons();
    applyLocalization();

    // 4. Populate sidebar content
    renderSidebarSuraList();
    renderSidebarTopicList();
    renderBookmarksList();

    // 5. Populate Comparison Settings Panel selectors
    populateSelects();

    // 6. Event bindings
    setupEventBindings();

    // 7. Initialize new controllers
    initAdvancedSearch();
    initMushafView();
    initAuth(); // async — runs in background, does not block startup

    // 8. Launch App Shell
    setTimeout(() => {
      const splash = document.getElementById('splash');
      const appDiv = document.getElementById('app');
      if (splash) splash.classList.add('hidden');
      if (appDiv) appDiv.style.display = 'flex';
      triggerRouting();
    }, 500);

    // 9. Register PWA Service Worker
    registerServiceWorker();

  } catch (err) {
    console.error('Initialisation failed:', err);
    if (progressText) {
      progressText.textContent = 'Error loading. Please refresh.';
      progressText.style.color = '#ef4444';
    }
  }
}

// --- 10.5 Go To Ayah Modal Logic ---
const gotoModal = document.getElementById('goto-modal');
const gotoModalBackdrop = document.getElementById('goto-modal-backdrop');
const gotoModalClose = document.getElementById('goto-modal-close');
const gotoCancelBtn = document.getElementById('goto-cancel-btn');
const gotoSubmitBtn = document.getElementById('goto-submit-btn');
const gotoAyahInput = document.getElementById('goto-ayah-input');
const gotoSuraSelect = document.getElementById('goto-sura-select');

function getActiveSuraId() {
  const hash = window.location.hash || '';
  if (hash.startsWith('#sura/')) {
    const parts = hash.split('/');
    const suraId = parseInt(parts[1], 10);
    if (suraId >= 1 && suraId <= 114) {
      return suraId;
    }
  }
  return 1;
}

function rebuildSuraSearchableSelect() {
  const searchEl = document.getElementById('goto-sura-search');
  const dropdown = document.getElementById('goto-sura-dropdown');
  const hidden = document.getElementById('goto-sura-select');
  if (!searchEl || !dropdown || !hidden) return;

  const newSearchEl = searchEl.cloneNode(true);
  searchEl.parentNode.replaceChild(newSearchEl, searchEl);

  const newDropdown = dropdown.cloneNode(true);
  dropdown.parentNode.replaceChild(newDropdown, dropdown);

  const suraItems = db.suraList.map(s => ({
    id: s.id.toString(),
    name: `${s.id}. ${state.uiLang === 'id' ? s.name_id : s.name_en} (${s.name_ar})`
  }));

  const val = hidden.value || getActiveSuraId().toString();
  buildSearchableSelect('goto-sura-search', 'goto-sura-dropdown', 'goto-sura-select', suraItems, val, null);
}

function updateGotoModalMaxAyah() {
  const suraId = parseInt(gotoSuraSelect.value, 10);
  const sura = db.suraList.find(s => s.id === suraId);
  const maxHint = document.getElementById('goto-ayah-max-hint');
  if (sura && maxHint && gotoAyahInput) {
    maxHint.textContent = `/ ${sura.ayas}`;
    gotoAyahInput.max = sura.ayas;
    gotoAyahInput.placeholder = `1-${sura.ayas}`;
  }
}

function openGotoModal() {
  if (!gotoModal) return;

  const activeSura = getActiveSuraId();
  gotoSuraSelect.value = activeSura.toString();

  gotoAyahInput.value = '';
  gotoAyahInput.classList.remove('input-error');

  rebuildSuraSearchableSelect();
  updateGotoModalMaxAyah();

  gotoModal.classList.add('open');

  setTimeout(() => {
    gotoAyahInput.focus();
  }, 200);
}

function closeGotoModal() {
  if (gotoModal) {
    gotoModal.classList.remove('open');
  }
}

function submitGotoModal() {
  const suraId = parseInt(gotoSuraSelect.value, 10);
  const ayahNum = parseInt(gotoAyahInput.value, 10);

  const sura = db.suraList.find(s => s.id === suraId);
  if (!sura || isNaN(ayahNum) || ayahNum < 1 || ayahNum > sura.ayas) {
    gotoAyahInput.classList.remove('input-error');
    void gotoAyahInput.offsetWidth;
    gotoAyahInput.classList.add('input-error');
    gotoAyahInput.focus();
    return;
  }

  window.location.hash = `#sura/${suraId}/verse/${ayahNum}`;
  closeGotoModal();
}

// --- 11. Binding Handlers ---
function setupEventBindings() {
  // Close all searchable selects when clicking outside
  document.addEventListener('click', (e) => {
    document.querySelectorAll('.searchable-select').forEach(container => {
      if (!container.contains(e.target)) {
        const dropdown = container.querySelector('.ss-dropdown');
        if (dropdown) dropdown.classList.remove('open');

        // Restore search input display text
        const searchEl = container.querySelector('.ss-input');
        const hidden = container.querySelector('input[type="hidden"]');
        if (searchEl && hidden) {
          const selectedOpt = dropdown.querySelector('.ss-option.selected');
          if (selectedOpt) {
            searchEl.value = selectedOpt.textContent;
          } else {
            searchEl.value = '';
          }
          // Reset visibility of options when closed
          dropdown.querySelectorAll('.ss-option').forEach(o => o.classList.remove('hidden'));
          const noRes = dropdown.querySelector('.ss-no-results');
          if (noRes) noRes.remove();
        }
      }
    });
  });

  // Sidebar tab switching
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(tab => {
    tab.onclick = () => {
      const viewName = tab.dataset.view;

      if (viewName === 'credits') {
        const creditsModal = document.getElementById('credits-modal');
        if (creditsModal) creditsModal.classList.add('open');
        return;
      }

      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      if (viewName === 'sura-list' || viewName === 'topic-index' || viewName === 'bookmarks') {
        if (window.location.hash === '#mushaf' || window.location.hash === '#credits' || state.mushafSplitMode) {
          window.location.hash = '#home';
        }
      }

      // Mushaf and Admin tabs switch the main view area instead of the sidebar panel
      if (viewName === 'mushaf') {
        window.location.hash = '#mushaf';
        return;
      }
      if (viewName === 'bookmarks') {
        renderBookmarksList();
      }
      if (viewName === 'admin') {
        // Open full-screen Admin CMS overlay
        openAdminCms();
        return;
      }

      document.querySelectorAll('.sidebar-content .panel').forEach(p => {
        p.classList.remove('active');
      });
      const targetPanel = document.getElementById(`panel-${viewName}`);
      if (targetPanel) targetPanel.classList.add('active');
    };
  });

  // Sidebar Menu button trigger
  const sidebarOpen = document.getElementById('sidebar-open-btn');
  const sidebarClose = document.getElementById('sidebar-close-btn');
  
  if (sidebarOpen) {
    sidebarOpen.onclick = () => {
      if (window.innerWidth <= 900) {
        if (sidebar) sidebar.classList.add('open');
        if (overlay) overlay.classList.add('active');
      } else {
        if (sidebar) sidebar.classList.remove('collapsed');
      }
    };
  }
  if (sidebarClose) {
    sidebarClose.onclick = () => {
      if (window.innerWidth <= 900) {
        closeSidebarMobile();
      } else {
        if (sidebar) sidebar.classList.add('collapsed');
      }
    };
  }
  if (overlay) overlay.onclick = closeSidebarMobile;

  // Comparison Panel Toggle Drawer (Floating Overlay with backdrop)
  const compToggle = document.getElementById('comparison-toggle-btn');
  const compClose = document.getElementById('comparison-panel-close');
  const compPanel = document.getElementById('comparison-panel');
  const compBackdrop = document.getElementById('comparison-panel-backdrop');

  const openCompPanel = () => {
    if (compPanel) compPanel.classList.add('open');
    if (compBackdrop) compBackdrop.classList.add('active');
  };

  const closeCompPanel = () => {
    if (compPanel) compPanel.classList.remove('open');
    if (compBackdrop) compBackdrop.classList.remove('active');
  };

  if (compToggle) {
    compToggle.onclick = () => {
      if (compPanel && compPanel.classList.contains('open')) {
        closeCompPanel();
      } else {
        openCompPanel();
      }
    };
  }
  if (compClose) {
    compClose.onclick = closeCompPanel;
  }
  if (compBackdrop) {
    compBackdrop.onclick = closeCompPanel;
  }

  // Mushaf Detail close button trigger
  const mushafDetailClose = document.getElementById('mushaf-detail-close-btn');
  if (mushafDetailClose) {
    mushafDetailClose.onclick = closeMushafDetailPane;
  }

  // Ayah Detail close button (split view) — collapse split, show full Mushaf
  const ayahDetailClose = document.getElementById('ayah-detail-close-btn');
  if (ayahDetailClose) {
    ayahDetailClose.onclick = () => {
      state.mushafSplitMode = false;
      document.body.classList.remove('split-mushaf-mode');
      // Hide the ayah detail panel
      const viewAyah = document.getElementById('view-ayah');
      if (viewAyah) viewAyah.classList.remove('active');
      ayahDetailClose.style.display = 'none';
      // Directly switch to full-screen Mushaf without re-routing through hash
      switchView('mushaf');
    };
  }

  // Mushaf toolbar Exit button — fully close Mushaf, return to last page
  const mushafExitBtn = document.getElementById('mushaf-exit-btn');
  if (mushafExitBtn) {
    mushafExitBtn.onclick = () => {
      // Clean up all Mushaf/split state
      state.mushafSplitMode = false;
      document.body.classList.remove('split-mushaf-mode');
      const viewAyah = document.getElementById('view-ayah');
      if (viewAyah) viewAyah.classList.remove('active');
      const viewMushaf = document.getElementById('view-mushaf');
      if (viewMushaf) {
        viewMushaf.classList.remove('active');
        viewMushaf.style.setProperty('display', 'none', 'important');
      }
      const closeBtn2 = document.getElementById('ayah-detail-close-btn');
      if (closeBtn2) closeBtn2.style.display = 'none';
      const detailPane = document.getElementById('mushaf-detail-pane');
      if (detailPane) detailPane.style.display = 'none';
      // Restore sidebar
      const sidebarEl = document.getElementById('sidebar');
      if (sidebarEl) sidebarEl.classList.remove('collapsed');
      // Navigate to last real page (never #mushaf or /verse/ hashes)
      window.location.hash = lastActiveHash || '#home';
    };
  }

  // Topbar search button trigger (focuses search in sidebar)
  const topbarSearch = document.getElementById('topbar-search-btn');
  const searchInput = document.getElementById('search-input');
  if (topbarSearch && searchInput) {
    topbarSearch.onclick = () => {
      if (window.innerWidth <= 900) {
        if (sidebar) sidebar.classList.add('open');
        if (overlay) overlay.classList.add('active');
      } else {
        if (sidebar) sidebar.classList.remove('collapsed');
      }
      setTimeout(() => searchInput.focus(), 150);
    };
  }

  // Sidebar live filtering & clearing
  const searchClear = document.getElementById('search-clear-btn');
  if (searchInput) {
    searchInput.addEventListener('input', () => {
      const query = searchInput.value.toLowerCase().trim();
      if (searchClear) {
        searchClear.style.display = query.length > 0 ? 'inline-flex' : 'none';
      }

      // Sura Filtering
      document.querySelectorAll('.sura-item').forEach(item => {
        const name = item.querySelector('.sura-item-name-en').textContent.toLowerCase();
        const num = item.querySelector('.sura-item-num').textContent;
        item.style.display = (name.includes(query) || num.includes(query)) ? 'flex' : 'none';
      });

      // Topic Filtering
      document.querySelectorAll('.topic-tag-item').forEach(item => {
        const name = item.querySelector('span').textContent.toLowerCase();
        item.style.display = name.includes(query) ? 'flex' : 'none';
      });
    });

    searchInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        const query = searchInput.value.trim();
        if (query.length >= 3) {
          window.location.hash = `#search/${encodeURIComponent(query)}`;
        }
      }
    });
  }

  if (searchClear && searchInput) {
    searchClear.onclick = () => {
      searchInput.value = '';
      searchInput.dispatchEvent(new Event('input'));
      searchInput.focus();
    };
  }

  // Theme changes
  ['dark', 'light', 'sepia'].forEach(t => {
    const btn = document.getElementById(`theme-${t}`);
    if (btn) {
      btn.onclick = () => {
        state.theme = t;
        saveSettings();
        applyStyles();
        updateThemeButtons();
      };
    }
  });

  // Font sizes
  const arInc = document.getElementById('arabic-font-increase');
  const arDec = document.getElementById('arabic-font-decrease');
  const trInc = document.getElementById('trans-font-increase');
  const trDec = document.getElementById('trans-font-decrease');

  if (arInc) arInc.onclick = () => { if (state.arabicFontSize < 48) { state.arabicFontSize += 2; saveSettings(); applyStyles(); } };
  if (arDec) arDec.onclick = () => { if (state.arabicFontSize > 20) { state.arabicFontSize -= 2; saveSettings(); applyStyles(); } };
  if (trInc) trInc.onclick = () => { if (state.transFontSize < 28) { state.transFontSize += 1; saveSettings(); applyStyles(); } };
  if (trDec) trDec.onclick = () => { if (state.transFontSize > 11) { state.transFontSize -= 1; saveSettings(); applyStyles(); } };

  // UI Language switching — shared handler for both the settings select and topbar toggle
  async function handleLangChange(newLang) {
    state.uiLang = newLang;

    // Auto-suggest matching topic tags only if user has never manually overridden.
    if (!state.tagsUserPref) {
      const langTagMap = { en: 'en', id: 'id' };
      const suggestedTag = langTagMap[state.uiLang];
      const tagExists = db.registry.tags.some(t => t.id === suggestedTag);
      if (suggestedTag && tagExists && state.activeTags !== suggestedTag) {
        state.activeTags = suggestedTag;
        const tagSel = document.getElementById('tags-select');
        if (tagSel) tagSel.value = suggestedTag;
      }
    }

    // Auto-suggest translation defaults.
    applyLanguageDefaultTranslations(false);
    syncSearchableSelect('trans1-search', 'trans1-dropdown', 'trans1-select', db.registry.translations, state.activeTranslation1);
    syncSearchableSelect('trans2-search', 'trans2-dropdown', 'trans2-select', db.registry.translations, state.activeTranslation2);

    // Auto-suggest Transliteration defaults.
    applyLanguageDefaultTransliterations(false);
    syncSearchableSelect('translit-search', 'translit-dropdown', 'translit-select', db.registry.transliterations, state.activeTransliteration, '— none —');

    // Auto-suggest Tafsir defaults.
    applyLanguageDefaultTafsir(false);
    syncSearchableSelect('tafsir1-search', 'tafsir1-dropdown', 'tafsir1-select', db.registry.tafsirs, state.activeTafsir1);
    syncSearchableSelect('tafsir2-search', 'tafsir2-dropdown', 'tafsir2-select', db.registry.tafsirs, state.activeTafsir2);

    // Auto-suggest Asbabun Nuzul defaults.
    applyLanguageDefaultNuzul(false);
    syncSearchableSelect('nuzul1-search', 'nuzul1-dropdown', 'nuzul1-select', db.registry.asbabun_nuzul, state.activeNuzul1, '— none available —');
    syncSearchableSelect('nuzul2-search', 'nuzul2-dropdown', 'nuzul2-select', db.registry.asbabun_nuzul, state.activeNuzul2, '— none available —');

    // Sync both language selectors to the new value
    const uiLangSel = document.getElementById('ui-lang-select');
    const topbarLangToggle = document.getElementById('topbar-lang-toggle');
    if (uiLangSel) uiLangSel.value = newLang;
    if (topbarLangToggle) {
      topbarLangToggle.classList.remove('lang-en', 'lang-id');
      topbarLangToggle.classList.add(newLang === 'id' ? 'lang-id' : 'lang-en');
    }

    saveSettings();
    await reloadTagsDataset();
    applyLocalization();
    renderSidebarSuraList();
    renderBookmarksList();
    triggerRouting();
  }

  // Settings panel select
  const uiLangSel = document.getElementById('ui-lang-select');
  if (uiLangSel) {
    uiLangSel.value = state.uiLang;
    uiLangSel.onchange = (e) => handleLangChange(e.target.value);
  }

  // Topbar language slide switch
  const topbarLangToggle = document.getElementById('topbar-lang-toggle');
  if (topbarLangToggle) {
    topbarLangToggle.classList.remove('lang-en', 'lang-id');
    topbarLangToggle.classList.add(state.uiLang === 'id' ? 'lang-id' : 'lang-en');
    topbarLangToggle.onclick = () => handleLangChange(state.uiLang === 'en' ? 'id' : 'en');
  }

  // Comparison Panel Toggles
  const layers = ['trans1', 'trans2', 'transliteration', 'tafsir1', 'tafsir2', 'nuzul1', 'nuzul2', 'tags'];
  layers.forEach(layer => {
    const cb = document.getElementById(`${layer}-toggle`);
    if (cb) {
      cb.checked = state.layers[layer];
      cb.onchange = async () => {
        state.layers[layer] = cb.checked;
        saveSettings();
        await ensureActiveDatasets();
        triggerRouting();
      };
    }
  });

  // Comparison Panel Selects
  const selectBindings = {
    activeTranslation1: 'trans1-select',
    activeTranslation2: 'trans2-select',
    activeTransliteration: 'translit-select',
    activeReciter: 'reciter-select',
    activeTafsir1: 'tafsir1-select',
    activeTafsir2: 'tafsir2-select',
    activeNuzul1: 'nuzul1-select',
    activeNuzul2: 'nuzul2-select',
    activeTags: 'tags-select'
  };

  for (const stateProp in selectBindings) {
    const el = document.getElementById(selectBindings[stateProp]);
    if (el) {
      el.onchange = async () => {
        state[stateProp] = el.value;
        if (stateProp === 'activeTags') {
          // Mark that user has explicitly chosen a tag set.
          // This prevents language switches from overriding their preference.
          state.tagsUserPref = true;
          saveSettings();
          await reloadTagsDataset();
          // Visually indicate user has a custom tag selection active
          updateTagsSelectHint();
        } else {
          if (stateProp === 'activeTranslation1') {
            state.trans1UserPref = true;
          } else if (stateProp === 'activeTranslation2') {
            state.trans2UserPref = true;
          } else if (stateProp === 'activeTransliteration') {
            state.transliterationUserPref = true;
          } else if (stateProp === 'activeNuzul1') {
            state.nuzul1UserPref = true;
          } else if (stateProp === 'activeNuzul2') {
            state.nuzul2UserPref = true;
          } else if (stateProp === 'activeTafsir1') {
            state.tafsir1UserPref = true;
          } else if (stateProp === 'activeTafsir2') {
            state.tafsir2UserPref = true;
          }
          saveSettings();
          await ensureActiveDatasets();
        }
        triggerRouting();
      };
    }
  }

  // Routing changes
  window.addEventListener('hashchange', triggerRouting);

  // Go To Ayah Modal Bindings
  const gotoBtn = document.getElementById('topbar-goto-btn');
  if (gotoBtn) {
    gotoBtn.onclick = openGotoModal;
  }
  if (gotoModalClose) {
    gotoModalClose.onclick = closeGotoModal;
  }
  if (gotoModalBackdrop) {
    gotoModalBackdrop.onclick = closeGotoModal;
  }
  if (gotoCancelBtn) {
    gotoCancelBtn.onclick = closeGotoModal;
  }

  // Credits modal bindings
  const creditsClose = document.getElementById('credits-modal-close');
  const creditsBackdrop = document.getElementById('credits-modal-backdrop');
  const creditsModal = document.getElementById('credits-modal');
  if (creditsClose) {
    creditsClose.onclick = () => {
      if (creditsModal) creditsModal.classList.remove('open');
    };
  }
  if (creditsBackdrop) {
    creditsBackdrop.onclick = () => {
      if (creditsModal) creditsModal.classList.remove('open');
    };
  }
  if (gotoSubmitBtn) {
    gotoSubmitBtn.onclick = submitGotoModal;
  }
  if (gotoAyahInput) {
    gotoAyahInput.onkeydown = (e) => {
      if (e.key === 'Enter') {
        submitGotoModal();
      } else if (e.key === 'Escape') {
        closeGotoModal();
      }
    };
  }
  if (gotoSuraSelect) {
    gotoSuraSelect.addEventListener('change', updateGotoModalMaxAyah);
  }

  // Reset Defaults Button click handler
  const btnResetDefaults = document.getElementById('btn-reset-defaults');
  if (btnResetDefaults) {
    btnResetDefaults.onclick = async () => {
      // 1. Reset user preference locks
      state.trans1UserPref = false;
      state.trans2UserPref = false;
      state.transliterationUserPref = false;
      state.tafsir1UserPref = false;
      state.tafsir2UserPref = false;
      state.nuzul1UserPref = false;
      state.nuzul2UserPref = false;
      state.tagsUserPref = false;

      // 2. Reset layers to default values
      state.layers = { ...defaultState.layers };

      // 3. Reset common settings to defaultState values
      state.arabicFontSize = defaultState.arabicFontSize;
      state.transFontSize = defaultState.transFontSize;
      state.activeReciter = defaultState.activeReciter;

      // 4. Force default settings for active UI language
      applyLanguageDefaultTranslations(false);
      applyLanguageDefaultTransliterations(false);
      applyLanguageDefaultTafsir(false);
      applyLanguageDefaultNuzul(false);
      state.activeTags = state.uiLang === 'id' ? 'id' : 'en';

      saveSettings();

      // 5. Update UI checkboxes
      for (const layer in state.layers) {
        const cb = document.getElementById(`${layer}-toggle`);
        if (cb) cb.checked = state.layers[layer];
      }

      // 6. Update UI dropdown selections
      syncSearchableSelect('trans1-search', 'trans1-dropdown', 'trans1-select', db.registry.translations, state.activeTranslation1);
      syncSearchableSelect('trans2-search', 'trans2-dropdown', 'trans2-select', db.registry.translations, state.activeTranslation2);
      syncSearchableSelect('translit-search', 'translit-dropdown', 'translit-select', db.registry.transliterations, state.activeTransliteration, '— none —');
      syncSearchableSelect('tafsir1-search', 'tafsir1-dropdown', 'tafsir1-select', db.registry.tafsirs, state.activeTafsir1);
      syncSearchableSelect('tafsir2-search', 'tafsir2-dropdown', 'tafsir2-select', db.registry.tafsirs, state.activeTafsir2);
      syncSearchableSelect('nuzul1-search', 'nuzul1-dropdown', 'nuzul1-select', db.registry.asbabun_nuzul, state.activeNuzul1, '— none available —');
      syncSearchableSelect('nuzul2-search', 'nuzul2-dropdown', 'nuzul2-select', db.registry.asbabun_nuzul, state.activeNuzul2, '— none available —');

      const tagsSel = document.getElementById('tags-select');
      if (tagsSel) tagsSel.value = state.activeTags;
      updateTagsSelectHint();

      syncSearchableSelect('reciter-search', 'reciter-dropdown', 'reciter-select',
        (db.registry.reciters || []).map(r => ({ id: r.id, name: `${r.name} — ${r.style}` })),
        state.activeReciter);

      // Apply font/theme sizes
      applyStyles();

      // 7. Reload resources and re-route/re-render
      await reloadTagsDataset();
      await ensureActiveDatasets();
      triggerRouting();
    };
  }
}

// --- 12. SW Registration ---
function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./service-worker.js')
      .then(reg => console.log('[Service Worker] Scope:', reg.scope))
      .catch(err => console.error('[Service Worker] Failed:', err));
  }
}

// Kickstart App (ES module already runs after DOM is ready — no DOMContentLoaded needed)
initApp();
