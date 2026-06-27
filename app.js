/* ================================================
   TAFSIR APP - app.js
   Pure ES6 Module Logic for Tafsir PWA
   ================================================ */

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
    trans2: false,
    transliteration: true,
    tafsir1: false,
    tafsir2: false,
    nuzul1: false,
    nuzul2: false,
    tags: true
  }
};

// Per-sura pagination state (not persisted — resets on navigation)
let suraPage = 1;

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
    layers: { ...defaultState.layers, ...state.layers }
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
    gotoSubmit: "Go"
  },
  id: {
    heroTitle: "Al-Qur'an & Alat Kajian Tafsir",
    heroSubtitle: "Bandingkan terjemahan, baca tafsir, dan jelajahi berdasarkan topik",
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
    gotoSubmit: "Lompat"
  }
};

// --- 2. Database Manager ---
class Database {
  constructor() {
    this.cache = new Map();
    this.registry = null;
    this.suraList = null;
    this.quranArabic = null;
    this.tags = null;
    this.verseTags = null;
  }

  async init(onProgress) {
    onProgress(10, state.uiLang === 'id' ? i18n.id.loadingDb : i18n.en.loadingDb);
    const regRes = await fetch('data/registry.json');
    this.registry = await regRes.json();

    onProgress(30, state.uiLang === 'id' ? i18n.id.loadingChapters : i18n.en.loadingChapters);
    const suraRes = await fetch(this.registry.sura_list);
    this.suraList = await suraRes.json();

    onProgress(60, state.uiLang === 'id' ? i18n.id.loadingScript : i18n.en.loadingScript);
    const arRes = await fetch(this.registry.quran_arabic);
    this.quranArabic = await arRes.json();

    onProgress(85, state.uiLang === 'id' ? i18n.id.loadingTags : i18n.en.loadingTags);
    if (this.registry.tags && this.registry.tags.length > 0) {
      let tagInfo = this.registry.tags.find(t => t.id === state.activeTags);
      if (!tagInfo) tagInfo = this.registry.tags[0];
      const tagsRes = await fetch(tagInfo.file);
      this.tags = await tagsRes.json();
      
      const mapRes = await fetch(tagInfo.verse_map);
      this.verseTags = await mapRes.json();
    } else {
      this.tags = [];
      this.verseTags = {};
    }

    onProgress(100, state.uiLang === 'id' ? i18n.id.ready : i18n.en.ready);
  }

  async getResource(file) {
    if (this.cache.has(file)) {
      return this.cache.get(file);
    }
    const res = await fetch(file);
    const data = await res.json();
    this.cache.set(file, data);
    return data;
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
}

// --- 4. Lazy-loading Required Datasets ---
async function ensureActiveDatasets() {
  const promises = [];
  
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
    if (item) promises.push(db.getResource(item.file));
  }
  if (state.layers.tafsir2 && state.activeTafsir2) {
    const item = db.registry.tafsirs.find(t => t.id === state.activeTafsir2);
    if (item) promises.push(db.getResource(item.file));
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

// Dynamically reloads the tags dataset when lang or active tags dataset changes
async function reloadTagsDataset() {
  if (db.registry.tags && db.registry.tags.length > 0) {
    let tagInfo = db.registry.tags.find(t => t.id === state.activeTags);
    if (!tagInfo) tagInfo = db.registry.tags[0];
    
    const tagsRes = await fetch(tagInfo.file);
    db.tags = await tagsRes.json();
    
    const mapRes = await fetch(tagInfo.verse_map);
    db.verseTags = await mapRes.json();
    
    tagLookup = new Map(db.tags.map(t => [t.id, t.name]));
    
    tagCounts = {};
    for (const verseKey in db.verseTags) {
      const tags = db.verseTags[verseKey];
      tags.forEach(id => {
        tagCounts[id] = (tagCounts[id] || 0) + 1;
      });
    }
    
    renderSidebarTopicList();
  }
}

// --- 5. Navigation & Routing ---
function switchView(viewId) {
  document.querySelectorAll('.view-area .view').forEach(v => {
    v.classList.remove('active');
  });
  const view = document.getElementById(`view-${viewId}`);
  if (view) {
    view.classList.add('active');
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
function renderVerseList(container, versesToRender) {
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
      const card = createVerseCard(verseKey);
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

  // Wait a tick for renderVerseList to kick off, then place paginator
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

function createVerseCard(verseKey, isDetailMode = false) {
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

  // Card Header
  let headerHtml = `
    <div class="verse-card-header">
      <a href="#sura/${suraId}/verse/${ayaId}" class="verse-ref-link verse-ref">${refLabel}</a>
      <div class="verse-actions">
        <button class="btn-icon btn-play-ayah" data-key="${verseKey}" title="Play Ayah audio">
          <svg class="play-icon" viewBox="0 0 24 24" fill="currentColor" style="width: 18px; height: 18px;"><path d="M8 5v14l11-7z"/></svg>
          <svg class="pause-icon" viewBox="0 0 24 24" fill="currentColor" style="width: 18px; height: 18px; display: none;"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
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
        bodyHtml += `<div class="verse-transliteration">${trText}</div>`;
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

    // Topic Tags
    if (state.layers.tags && db.verseTags && db.verseTags[verseKey]) {
      const tagIds = db.verseTags[verseKey];
      if (tagIds && tagIds.length > 0) {
        let tagsHtml = '<div class="verse-tags">';
        tagIds.forEach(id => {
          const name = tagLookup.get(id) || id;
          tagsHtml += `<span class="verse-tag" data-tag-id="${id}">${name}</span>`;
        });
        tagsHtml += '</div>';
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
        const data = db.cache.get(tInfo.file);
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
        const data = db.cache.get(tInfo.file);
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

    // Topic Tags
    if (state.layers.tags && db.verseTags && db.verseTags[verseKey]) {
      const tagIds = db.verseTags[verseKey];
      if (tagIds && tagIds.length > 0) {
        let tagsHtml = '<div class="verse-tags">';
        tagIds.forEach(id => {
          const name = tagLookup.get(id) || id;
          tagsHtml += `<span class="verse-tag" data-tag-id="${id}">${name}</span>`;
        });
        tagsHtml += '</div>';
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

  // Add click listeners to tags
  card.querySelectorAll('.verse-tag').forEach(tagEl => {
    tagEl.onclick = (e) => {
      e.stopPropagation();
      window.location.hash = `#topic/${tagEl.dataset.tagId}`;
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

// --- 7. Router Trigger Handler ---
async function triggerRouting() {
  const hash = window.location.hash || '#home';
  closeSidebarMobile();
  
  if (hash === '#home' || hash === '' || hash === '#') {
    switchView('home');
    updateBreadcrumbs('home');
    highlightActiveSuraInSidebar(null);
    renderHomeGrid();
  } else if (hash.startsWith('#sura/')) {
    const parts = hash.split('/');
    const suraId = parseInt(parts[1], 10);
    const targetVerse = parts[3] ? parseInt(parts[3], 10) : null;
    
    if (suraId >= 1 && suraId <= 114) {
      const sura = db.suraList.find(s => s.id === suraId);
      highlightActiveSuraInSidebar(suraId);
      
      // Highlight corresponding tab
      const tabSura = document.getElementById('tab-sura-list');
      if (tabSura) tabSura.click();

      await ensureActiveDatasets();

      if (targetVerse) {
        // --- Single Ayah View Mode ---
        switchView('ayah');
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
        // --- Sura List Mode ---
        switchView('sura');
        updateBreadcrumbs('sura', { sura });

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
    const tagId = decodeURIComponent(hash.substring(7));
    switchView('topic');
    highlightActiveSuraInSidebar(null);

    // Switch active sidebar panel to Topic List
    const tabTopics = document.getElementById('tab-topics');
    if (tabTopics) tabTopics.click();

    const tag = db.tags.find(t => t.id === tagId);
    updateBreadcrumbs('topic', { topicName: tag ? tag.name : tagId });

    const topicResultsList = document.getElementById('topic-results-list');
    topicResultsList.innerHTML = `
      <div class="loading-wrap">
        <div class="spinner"></div>
        <div>Loading topic verses...</div>
      </div>
    `;

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

    const header = document.getElementById('topic-results-header');
    if (header) {
      header.innerHTML = `
        <h2 class="search-results-title">Topic: ${tag ? tag.name : tagId}</h2>
        <div class="search-results-count">${verses.length} verses tagged with this topic</div>
      `;
    }

    await ensureActiveDatasets();
    renderVerseList(topicResultsList, verses);
  } else if (hash.startsWith('#search/')) {
    const query = decodeURIComponent(hash.substring(8));
    switchView('search');
    highlightActiveSuraInSidebar(null);
    updateBreadcrumbs('search');

    const searchResultsList = document.getElementById('search-results-list');
    searchResultsList.innerHTML = `
      <div class="loading-wrap">
        <div class="spinner"></div>
        <div>Searching...</div>
      </div>
    `;

    await ensureActiveDatasets();

    // Query translation text
    const tInfo = db.registry.translations.find(t => t.id === state.activeTranslation1);
    if (tInfo && !db.cache.has(tInfo.file)) {
      await db.getResource(tInfo.file);
    }
    const transData = tInfo ? db.cache.get(tInfo.file) : {};
    const results = [];
    if (transData) {
      for (const key in transData) {
        if (transData[key].toLowerCase().includes(query.toLowerCase())) {
          results.push(key);
        }
      }
    }

    // Query tags
    const matchingTagIds = db.tags
      .filter(t => t.name.toLowerCase().includes(query.toLowerCase()))
      .map(t => t.id);

    const taggedVerses = [];
    for (const key in db.verseTags) {
      if (db.verseTags[key].some(t => matchingTagIds.includes(t))) {
        taggedVerses.push(key);
      }
    }

    // Merge & sort results
    const mergedResults = Array.from(new Set([...results, ...taggedVerses])).sort((a, b) => {
      const [s1, v1] = a.split(':').map(Number);
      const [s2, v2] = b.split(':').map(Number);
      if (s1 !== s2) return s1 - s2;
      return v1 - v2;
    });

    const header = document.getElementById('search-results-header');
    if (header) {
      header.innerHTML = `
        <h2 class="search-results-title">Search Results for "${query}"</h2>
        <div class="search-results-count">Found ${mergedResults.length} matches across translation and topic tags</div>
      `;
    }

    renderVerseList(searchResultsList, mergedResults);
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

function getAudioUrl(verseKey, reciterId) {
  const [sura, ayah] = verseKey.split(':');
  const suraPad = sura.padStart(3, '0');
  const ayahPad = ayah.padStart(3, '0');
  return `https://everyayah.com/data/${reciterId}/${suraPad}${ayahPad}.mp3`;
}

function playAyah(verseKey) {
  if (currentAudio) {
    currentAudio.pause();
  }
  
  currentPlayingKey = verseKey;
  isAudioPlaying = true;
  
  const url = getAudioUrl(verseKey, state.activeReciter);
  currentAudio = new Audio(url);
  currentAudio.play().then(() => {
    updateAudioUI();
  }).catch(err => {
    console.error("Audio playback failed:", err);
    isAudioPlaying = false;
    updateAudioUI();
  });
  
  // Auto-advance
  currentAudio.onended = () => {
    playNextAyah();
  };
}

function pauseAyah() {
  if (currentAudio) {
    currentAudio.pause();
    isAudioPlaying = false;
    updateAudioUI();
  }
}

function togglePlayAyah(verseKey) {
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
    const nextCard = document.getElementById(`v-${nextKey.replace(':', '-')}`);
    if (nextCard) {
      nextCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    playAyah(nextKey);
  } else {
    // End of sura, check for next sura
    if (sura < 114) {
      const nextSura = sura + 1;
      window.location.hash = `#sura/${nextSura}`;
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
    const prevCard = document.getElementById(`v-${prevKey.replace(':', '-')}`);
    if (prevCard) {
      prevCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    playAyah(prevKey);
  } else {
    if (sura > 1) {
      const prevSura = sura - 1;
      const prevSuraMeta = db.suraList.find(s => s.id === prevSura);
      if (prevSuraMeta) {
        window.location.hash = `#sura/${prevSura}`;
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
}

// --- 10. Initialization Flow ---
async function initApp() {
  const progressFill = document.getElementById('splash-progress');
  const progressText = document.getElementById('splash-text');

  function updateProgress(percent, text) {
    if (progressFill) progressFill.style.width = percent + '%';
    if (progressText) progressText.textContent = text;
  }

  try {
    // 1. Initialize databases
    await db.init(updateProgress);

    // 2. Build lookups
    tagLookup = new Map(db.tags.map(t => [t.id, t.name]));
    
    // 3. Count verses per tag
    tagCounts = {};
    for (const verseKey in db.verseTags) {
      const tags = db.verseTags[verseKey];
      tags.forEach(id => {
        tagCounts[id] = (tagCounts[id] || 0) + 1;
      });
    }

    // 4. Set styles and theme
    applyStyles();
    updateThemeButtons();
    applyLocalization();

    // 5. Populate sidebar content
    renderSidebarSuraList();
    renderSidebarTopicList();

    // 6. Populate Comparison Settings Panel selectors
    populateSelects();

    // 7. Event bindings
    setupEventBindings();

    // 8. Launch App Shell
    setTimeout(() => {
      const splash = document.getElementById('splash');
      const appDiv = document.getElementById('app');
      if (splash) splash.classList.add('hidden');
      if (appDiv) appDiv.style.display = 'flex';
      
      // Trigger initial routing
      triggerRouting();
    }, 500);

    // 9. Register PWA Service Worker
    registerServiceWorker();

  } catch (err) {
    console.error('Initialisation failed:', err);
    if (progressText) {
      progressText.textContent = 'Error loading database. Please refresh.';
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
      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      const viewName = tab.dataset.view;
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

  // Comparison Panel Toggle Drawer
  const compToggle = document.getElementById('comparison-toggle-btn');
  const compClose = document.getElementById('comparison-panel-close');
  const compPanel = document.getElementById('comparison-panel');

  if (compToggle && compPanel) {
    compToggle.onclick = () => compPanel.classList.toggle('open');
  }
  if (compClose && compPanel) {
    compClose.onclick = () => compPanel.classList.remove('open');
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
    if (topbarLangToggle) topbarLangToggle.textContent = newLang === 'id' ? 'ID' : 'EN';

    saveSettings();
    await reloadTagsDataset();
    applyLocalization();
    renderSidebarSuraList();
    triggerRouting();
  }

  // Settings panel select
  const uiLangSel = document.getElementById('ui-lang-select');
  if (uiLangSel) {
    uiLangSel.value = state.uiLang;
    uiLangSel.onchange = (e) => handleLangChange(e.target.value);
  }

  // Topbar language toggle button
  const topbarLangToggle = document.getElementById('topbar-lang-toggle');
  if (topbarLangToggle) {
    topbarLangToggle.textContent = state.uiLang === 'id' ? 'ID' : 'EN';
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
