/**
 * Standalone Certified Tajweed Engine & Mushaf Web Application
 * Ported & enhanced from certified Dart Tajweed Parser for tafseer.id
 */

(function () {
  'use strict';

  // ─────────────────────────────────────────────────────────────────────────────
  // Unicode Codepoints & Sets for Tajweed Rule Engine
  // ─────────────────────────────────────────────────────────────────────────────
  const CODE_ALEF_WASLA = 0x0671; // ٱ
  const CODE_SMALL_HIGH_ZERO = 0x06DF; // ۡ / ۬
  const CODE_MADDA_ABOVE = 0x0653; //  ٓ
  const CODE_SMALL_HIGH_MADDA = 0x06E4; // ۤ
  const CODE_ALEF_MADDA = 0x0622; // آ
  const CODE_SUPERSCRIPT_ALEF = 0x0670; // ٰ
  const CODE_SMALL_LOW_MEEM = 0x06ED; // ۭ
  const CODE_SMALL_HIGH_MEEM = 0x06E2; // ۢ
  const CODE_FATHAH = 0x064B; // ً
  const CODE_DAMMAH = 0x064C; // ٌ
  const CODE_KASRAH = 0x064D; // ٍ
  const CODE_FATHA = 0x064E; // َ
  const CODE_DAMMA = 0x064F; // ُ
  const CODE_KASRA = 0x0650; // ِ
  const CODE_SHADDA = 0x0651; // ّ
  const CODE_SUKUN = 0x0652; // ْ
  const CODE_SMALL_HIGH_ROUND_ZERO = 0x06E5;

  const NUN = 0x0646; // ن
  const MIM = 0x0645; // م
  const BA = 0x0628;  // ب
  const ALEF = 0x0627; // ا
  const ALEF_MAQSURA = 0x0649; // ى
  const WAW = 0x0648; // و
  const YA = 0x064A; // ي

  const HAMZAH_CODES = new Set([0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626]);
  const QALQALAH_CODES = new Set([0x0642, 0x0637, 0x0628, 0x062C, 0x062F]); // ق, ط, ب, ج, د
  const TANWIN_CODES = new Set([0x064B, 0x064C, 0x064D]);
  const SUKUN_CODES = new Set([0x0652, 0x06DF, 0x06E1]);

  const IDGHAM_GHUNNAH_CODES = new Set([0x064A, 0x0646, 0x0645, 0x0648]); // ي, ن, م, و
  const IDGHAM_NO_GHUNNAH_CODES = new Set([0x0644, 0x0631]); // ل, ر
  const IKHFA_CODES = new Set([
    0x062A, 0x062B, 0x062C, 0x062F, 0x0630, 0x0631, 0x0632, 0x0633,
    0x0634, 0x0635, 0x0636, 0x0637, 0x0638, 0x0641, 0x0642, 0x064A
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // Grapheme Clusterizer
  // ─────────────────────────────────────────────────────────────────────────────
  function clusterize(text) {
    const clusters = [];
    let current = '';

    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const code = char.charCodeAt(0);

      // Diacritics/combining marks range
      const isCombining = (code >= 0x0610 && code <= 0x061A) ||
        (code >= 0x064B && code <= 0x065F) ||
        (code >= 0x0670 && code <= 0x06DC) ||
        (code >= 0x06DF && code <= 0x06E8) ||
        (code >= 0x06EA && code <= 0x06ED);

      if (isCombining && current.length > 0) {
        current += char;
      } else {
        if (current.length > 0) clusters.push(current);
        current = char;
      }
    }
    if (current.length > 0) clusters.push(current);
    return clusters;
  }

  function getBaseCode(cluster) {
    if (!cluster) return 0;
    return cluster.charCodeAt(0);
  }

  function clusterHasCode(cluster, code) {
    for (let i = 0; i < cluster.length; i++) {
      if (cluster.charCodeAt(i) === code) return true;
    }
    return false;
  }

  function clusterHasAny(cluster, codeSet) {
    for (let i = 0; i < cluster.length; i++) {
      if (codeSet.has(cluster.charCodeAt(i))) return true;
    }
    return false;
  }

  function isVowelled(cluster) {
    return clusterHasAny(cluster, new Set([CODE_FATHA, CODE_DAMMA, CODE_KASRA, CODE_SHADDA])) ||
      clusterHasAny(cluster, TANWIN_CODES);
  }

  function hasSukun(cluster) {
    return clusterHasAny(cluster, SUKUN_CODES);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Core Tajweed Parser
  // ─────────────────────────────────────────────────────────────────────────────
  function parseTajweedText(arabicText) {
    if (!arabicText) return [];
    const clusters = clusterize(arabicText);
    const n = clusters.length;

    function nextBaseCode(i) {
      for (let j = i + 1; j < n; j++) {
        const b = getBaseCode(clusters[j]);
        if (b !== 0x0020) return b;
      }
      return 0;
    }

    function isAtPause(i) {
      if (i === n - 1) return true;
      return getBaseCode(clusters[i + 1]) === 0x0020;
    }

    function getColorClass(i) {
      const cl = clusters[i];
      const b = getBaseCode(cl);

      // 1. Hamzat Wasl / Silent
      if (b === CODE_ALEF_WASLA || clusterHasCode(cl, CODE_SMALL_HIGH_ZERO)) {
        return 'tajweed-hamzat-wasl';
      }

      // 2. Madd Rules
      if (b === CODE_ALEF_MADDA || clusterHasCode(cl, CODE_MADDA_ABOVE) || clusterHasCode(cl, CODE_SMALL_HIGH_MADDA)) {
        const nb = nextBaseCode(i);
        if (HAMZAH_CODES.has(nb)) {
          return 'tajweed-madd-wajib';
        }
        return 'tajweed-madd-munfasil';
      }

      if (clusterHasCode(cl, CODE_SUPERSCRIPT_ALEF)) {
        return 'tajweed-madd-thabii';
      }

      if (!isVowelled(cl) && !hasSukun(cl) && i > 0) {
        const prevCl = clusters[i - 1];
        if ((b === ALEF || b === ALEF_MAQSURA) && clusterHasCode(prevCl, CODE_FATHA)) return 'tajweed-madd-thabii';
        if (b === WAW && clusterHasCode(prevCl, CODE_DAMMA)) return 'tajweed-madd-thabii';
        if (b === YA && clusterHasCode(prevCl, CODE_KASRA)) return 'tajweed-madd-thabii';
      }

      // 3. Iqlab indicator meem
      if (clusterHasCode(cl, CODE_SMALL_LOW_MEEM) || clusterHasCode(cl, CODE_SMALL_HIGH_MEEM)) {
        return 'tajweed-iqlab';
      }

      // 4. Ghunnah (Nun or Mim Mushaddad)
      if ((b === NUN || b === MIM) && clusterHasCode(cl, CODE_SHADDA)) {
        return 'tajweed-ghunnah';
      }

      // 5. Qalqalah
      if (QALQALAH_CODES.has(b)) {
        if (hasSukun(cl) || (!isVowelled(cl) && isAtPause(i))) {
          return 'tajweed-qalqalah';
        }
      }

      // 6. Meem Sukun rules
      if (b === MIM && (hasSukun(cl) || (!isVowelled(cl) && !clusterHasCode(cl, CODE_SHADDA)))) {
        const nb = nextBaseCode(i);
        if (nb === MIM) return 'tajweed-idgham-shafawi';
        if (nb === BA) return 'tajweed-ikhfa-shafawi';
      }

      // 7. Nun Sukun / Tanwin rules
      const isTanwin = clusterHasAny(cl, TANWIN_CODES);
      const isNunSukun = (b === NUN) && (hasSukun(cl) || (!isVowelled(cl) && cl.length === 1));

      if (isTanwin || isNunSukun) {
        const nb = nextBaseCode(i);
        if (nb !== 0) {
          if (nb === BA) return 'tajweed-iqlab';
          if (IDGHAM_GHUNNAH_CODES.has(nb)) return 'tajweed-idgham';
          if (IDGHAM_NO_GHUNNAH_CODES.has(nb)) return 'tajweed-idgham-no-ghunnah';
          if (IKHFA_CODES.has(nb)) return 'tajweed-ikhfa';
        }
      }

      return null;
    }

    const spans = [];
    let currentBuf = '';
    let currentClass = null;

    for (let i = 0; i < n; i++) {
      const cls = getColorClass(i);
      if (cls === currentClass) {
        currentBuf += clusters[i];
      } else {
        if (currentBuf) spans.push({ text: currentBuf, className: currentClass });
        currentBuf = clusters[i];
        currentClass = cls;
      }
    }
    if (currentBuf) spans.push({ text: currentBuf, className: currentClass });

    return spans;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Application State & Controller
  // ─────────────────────────────────────────────────────────────────────────────
  const TAJWEED_RULES = [
    { id: 'tajweed-madd-wajib', color: '#000EBC', nameEn: 'Madd Wajib Muttasil (6 Harakat)', nameId: 'Madd Wajib Muttasil (6 Harakat)' },
    { id: 'tajweed-madd-munfasil', color: '#2144C1', nameEn: 'Madd Munfasil (4-5 Harakat)', nameId: 'Madd Ja\'iz Munfasil (4-5 Harakat)' },
    { id: 'tajweed-madd-thabii', color: '#4A73E8', nameEn: 'Madd Thabi\'i (2 Harakat)', nameId: 'Madd Thabi\'i (2 Harakat)' },
    { id: 'tajweed-ghunnah', color: '#D32F2F', nameEn: 'Ghunnah (Nasalization)', nameId: 'Ghunnah (Dengung)' },
    { id: 'tajweed-qalqalah', color: '#E65100', nameEn: 'Qalqalah (Echo Sound)', nameId: 'Qalqalah (Memantul)' },
    { id: 'tajweed-ikhfa', color: '#8E24AA', nameEn: 'Ikhfa\' Haqiqi (Concealment)', nameId: 'Ikhfa\' Samar' },
    { id: 'tajweed-ikhfa-shafawi', color: '#C2185B', nameEn: 'Ikhfa\' Shafawi', nameId: 'Ikhfa\' Syafawi' },
    { id: 'tajweed-idgham', color: '#00897B', nameEn: 'Idgham with Ghunnah', nameId: 'Idgham Bighunnah (Dengung)' },
    { id: 'tajweed-idgham-no-ghunnah', color: '#2E7D32', nameEn: 'Idgham without Ghunnah', nameId: 'Idgham Bilaghunnah' },
    { id: 'tajweed-idgham-shafawi', color: '#689F38', nameEn: 'Idgham Shafawi', nameId: 'Idgham Syafawi' },
    { id: 'tajweed-iqlab', color: '#0288D1', nameEn: 'Iqlab (Conversion)', nameId: 'Iqlab (Menukar Nun ke Mim)' },
    { id: 'tajweed-hamzat-wasl', color: '#78909C', nameEn: 'Hamzat Wasl / Silent', nameId: 'Hamzat Wasl / Huruf Silent' }
  ];

  let state = {
    surahList: [],
    quranData: {},
    currentSurahId: 1,
    fontSize: 32,
    enableTajweed: true,
    showTranslation: true,
    selectedFilterRule: null,
    activeAudioAyah: null,
    theme: 'cream'
  };

  const audioPlayer = new Audio();

  // Fallback initial dataset if offline/local file
  const SAMPLE_SURAH_LIST = [
    { id: 1, name_ar: "الفاتحة", name_id: "Al-Fatihah", meaning_id: "Pembukaan", ayas: 7 },
    { id: 36, name_ar: "يس", name_id: "Ya Sin", meaning_id: "Yaasiin", ayas: 83 },
    { id: 67, name_ar: "الملك", name_id: "Al-Mulk", meaning_id: "Kerajaan", ayas: 30 },
    { id: 112, name_ar: "الإخلاص", name_id: "Al-Ikhlas", meaning_id: "Ikhlas", ayas: 4 },
    { id: 113, name_ar: "الفلق", name_id: "Al-Falaq", meaning_id: "Waktu Subuh", ayas: 5 },
    { id: 114, name_ar: "الناس", name_id: "An-Nas", meaning_id: "Manusia", ayas: 6 }
  ];

  async function initApp() {
    setupEventListeners();
    renderLegend();
    loadTheme(state.theme);

    try {
      const resSura = await fetch('../data/sura_list.json');
      if (resSura.ok) state.surahList = await resSura.json();
      else state.surahList = SAMPLE_SURAH_LIST;
    } catch (e) {
      state.surahList = SAMPLE_SURAH_LIST;
    }

    populateSurahDropdown();

    try {
      const resQuran = await fetch('../data/quran_arabic.json');
      if (resQuran.ok) state.quranData = await resQuran.json();
    } catch (e) {
      console.warn("Using sample Quran data.");
    }

    renderSurahView(state.currentSurahId);
  }

  function setupEventListeners() {
    document.getElementById('surahSelect').addEventListener('change', (e) => {
      state.currentSurahId = parseInt(e.target.value, 10);
      renderSurahView(state.currentSurahId);
    });

    document.getElementById('tajweedToggle').addEventListener('change', (e) => {
      state.enableTajweed = e.target.checked;
      renderSurahView(state.currentSurahId);
    });

    document.getElementById('translationToggle').addEventListener('change', (e) => {
      state.showTranslation = e.target.checked;
      renderSurahView(state.currentSurahId);
    });

    document.getElementById('fontSizeSlider').addEventListener('input', (e) => {
      state.fontSize = parseInt(e.target.value, 10);
      document.documentElement.style.setProperty('--arabic-font-size', state.fontSize + 'px');
    });

    document.querySelectorAll('.theme-opt').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const th = e.target.getAttribute('data-theme');
        loadTheme(th);
      });
    });
  }

  function loadTheme(themeName) {
    state.theme = themeName;
    document.documentElement.setAttribute('data-theme', themeName);
    document.querySelectorAll('.theme-opt').forEach(b => {
      b.classList.toggle('active', b.getAttribute('data-theme') === themeName);
    });
  }

  function renderLegend() {
    const container = document.getElementById('legendList');
    if (!container) return;

    container.innerHTML = TAJWEED_RULES.map(rule => `
      <div class="legend-item ${state.selectedFilterRule === rule.id ? 'active' : ''}" data-rule="${rule.id}">
        <div class="legend-badge-group">
          <span class="legend-dot" style="background-color: ${rule.color}"></span>
          <span class="legend-name">${rule.nameId}</span>
        </div>
        <span class="legend-count" id="count-${rule.id}">0</span>
      </div>
    `).join('');

    container.querySelectorAll('.legend-item').forEach(item => {
      item.addEventListener('click', () => {
        const ruleId = item.getAttribute('data-rule');
        if (state.selectedFilterRule === ruleId) {
          state.selectedFilterRule = null;
        } else {
          state.selectedFilterRule = ruleId;
        }
        renderLegend();
        applyFilterHighlight();
      });
    });
  }

  function populateSurahDropdown() {
    const sel = document.getElementById('surahSelect');
    if (!sel) return;

    sel.innerHTML = state.surahList.map(s => `
      <option value="${s.id}">${s.id}. ${s.name_id} (${s.name_ar}) - ${s.ayas} Ayah</option>
    `).join('');

    sel.value = state.currentSurahId;
  }

  function renderSurahView(surahId) {
    const surahMeta = state.surahList.find(s => s.id === surahId) || SAMPLE_SURAH_LIST[0];
    document.getElementById('surahTitleAr').textContent = surahMeta.name_ar;
    document.getElementById('surahTitleEn').textContent = `${surahMeta.id}. Surah ${surahMeta.name_id} (${surahMeta.meaning_id})`;
    document.getElementById('surahMetaInfo').textContent = `${surahMeta.type || 'Meccan'} • ${surahMeta.ayas} Verses`;

    const bismillahContainer = document.getElementById('bismillahContainer');
    if (surahId !== 1 && surahId !== 9) {
      bismillahContainer.style.display = 'block';
    } else {
      bismillahContainer.style.display = 'none';
    }

    const ayahContainer = document.getElementById('ayahListContainer');
    const ayahCount = surahMeta.ayas;

    let html = '';
    const counts = {};
    TAJWEED_RULES.forEach(r => counts[r.id] = 0);

    for (let a = 1; a <= ayahCount; a++) {
      const key = `${surahId}:${a}`;
      const textAr = state.quranData[key] || getSampleText(surahId, a);
      const parsedSpans = parseTajweedText(textAr);

      let renderedArabic = '';
      parsedSpans.forEach(span => {
        if (state.enableTajweed && span.className) {
          counts[span.className] = (counts[span.className] || 0) + 1;
          renderedArabic += `<span class="tajweed-span ${span.className}">${span.text}</span>`;
        } else {
          renderedArabic += `<span>${span.text}</span>`;
        }
      });

      html += `
        <div class="ayah-item" id="ayah-${a}">
          <div class="ayah-arabic">
            ${renderedArabic}
            <span class="ayah-num-symbol">﴿${toArabicNumerals(a)}﴾</span>
          </div>
          ${state.showTranslation ? `<div class="ayah-translation">Ayah ${a}: [Surah ${surahMeta.name_id}]</div>` : ''}
          <div class="ayah-actions">
            <button class="btn-sm btn-play" data-surah="${surahId}" data-ayah="${a}">
              ▶ Play Audio
            </button>
            <button class="btn-sm btn-copy" data-text="${textAr.replace(/"/g, '&quot;')}">
              📋 Copy
            </button>
          </div>
        </div>
      `;
    }

    ayahContainer.innerHTML = html;

    // Update rule counts in legend
    TAJWEED_RULES.forEach(r => {
      const el = document.getElementById(`count-${r.id}`);
      if (el) el.textContent = counts[r.id] || 0;
    });

    applyFilterHighlight();
    setupAyahActions();
  }

  function applyFilterHighlight() {
    const mushafCard = document.getElementById('mushafCard');
    if (!state.selectedFilterRule) {
      mushafCard.classList.remove('filtering');
      document.querySelectorAll('.tajweed-span').forEach(el => el.classList.remove('highlighted'));
      return;
    }

    mushafCard.classList.add('filtering');
    document.querySelectorAll('.tajweed-span').forEach(el => {
      if (el.classList.contains(state.selectedFilterRule)) {
        el.classList.add('highlighted');
      } else {
        el.classList.remove('highlighted');
      }
    });
  }

  function setupAyahActions() {
    document.querySelectorAll('.btn-play').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const s = btn.getAttribute('data-surah');
        const a = btn.getAttribute('data-ayah');
        playAudio(parseInt(s, 10), parseInt(a, 10));
      });
    });

    document.querySelectorAll('.btn-copy').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const text = btn.getAttribute('data-text');
        navigator.clipboard.writeText(text);
        btn.textContent = '✓ Copied';
        setTimeout(() => btn.textContent = '📋 Copy', 2000);
      });
    });
  }

  function playAudio(surah, ayah) {
    const sPad = String(surah).padStart(3, '0');
    const aPad = String(ayah).padStart(3, '0');
    const url = `https://everyayah.com/data/Alafasy_128kbps/${sPad}${aPad}.mp3`;

    audioPlayer.src = url;
    audioPlayer.play();

    document.querySelectorAll('.ayah-item').forEach(el => el.classList.remove('active-audio'));
    const activeEl = document.getElementById(`ayah-${ayah}`);
    if (activeEl) activeEl.classList.add('active-audio');

    const audioBar = document.getElementById('audioBar');
    if (audioBar) {
      audioBar.classList.add('visible');
      document.getElementById('audioTrackInfo').textContent = `Playing Surah ${surah}:${ayah} (Mishary Alafasy)`;
    }
  }

  function toArabicNumerals(num) {
    const id = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return String(num).replace(/[0-9]/g, w => id[+w]);
  }

  function getSampleText(surah, ayah) {
    if (surah === 1) {
      const sampleFatihah = [
        "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ",
        "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ",
        "ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ",
        "مَـٰلِكِ يَوْمِ ٱلدِّينِ",
        "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
        "ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ",
        "صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ"
      ];
      return sampleFatihah[ayah - 1] || "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ";
    }
    return "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ";
  }

  // Initialize on page load
  window.addEventListener('DOMContentLoaded', initApp);
})();
