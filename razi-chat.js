/* ============================================================
   Razi — floating web chat for tafseer.id and hadeeth.id

   A single self-contained module. Drop the script tag on any page:

     <script src="razi-chat.js" defer></script>

   Optional attributes on the tag itself:
     data-avatar   path to the profile picture   (default: razi-avatar.jpg)
     data-api      chat endpoint                 (default: razi.hadeeth.id)
     data-lang     "en" | "id"                   (default: <html lang> / browser)

   The widget talks to the razi-bridge Worker on Cloudflare, which forwards
   to the Hermes agent (persona: Razi) on whichever InstaBox is active. The
   browser never sees the Hermes API key; the Worker holds it.
   ============================================================ */
(function () {
  'use strict';

  if (window.__raziChatLoaded) return;
  window.__raziChatLoaded = true;

  var scriptEl = document.currentScript || (function () {
    var all = document.getElementsByTagName('script');
    for (var i = all.length - 1; i >= 0; i--) {
      if (all[i].src && all[i].src.indexOf('razi-chat') !== -1) return all[i];
    }
    return null;
  })();

  function attr(name, fallback) {
    var v = scriptEl && scriptEl.getAttribute(name);
    return (v === null || v === '') ? fallback : v;
  }

  var CONFIG = {
    api: attr('data-api', 'https://razi.hadeeth.id/api/chat'),
    avatar: attr('data-avatar', 'razi-avatar.jpg'),
    lang: (attr('data-lang', '') ||
      document.documentElement.getAttribute('lang') ||
      navigator.language ||
      'en').toLowerCase().slice(0, 2) === 'id' ? 'id' : 'en',
    requestTimeoutMs: 100000,
    slowNoticeMs: 20000,
    sessionKey: 'razi_web_session',
    openKey: 'razi_web_open',
    maxChars: 3000,
  };

  var STRINGS = {
    en: {
      launcherTitle: 'Ask Razi — Qur\u2019an & Hadith research assistant',
      name: 'Razi',
      role: 'Qur\u2019an & Hadith research assistant',
      close: 'Close chat',
      send: 'Send',
      placeholder: 'Ask about a verse, a hadith, or a topic\u2026',
      intro: 'Assalamu\u2019alaikum. I can search the Qur\u2019an and the hadith collections of tafseer.id and hadeeth.id. Every answer is grounded in the texts \u2014 ask away.',
      chips: [
        'What does the Qur\u2019an say about patience?',
        'Hadith about intention (niat)',
        'Verses about the rights of parents'
      ],
      thinking: 'Searching the texts\u2026',
      slow: 'Still searching \u2014 this one is taking a while\u2026',
      error: 'Could not reach the assistant. Please try again.',
      rateLimit: 'Too many messages just now. Please wait a little, then try again.',
      offline: 'The assistant is waking up. Please try again in a moment.',
      tooLong: 'That message is too long. Please shorten it.',
      disclaimer: 'Answers are AI-generated. Always verify the reference.',
    },
    id: {
      launcherTitle: 'Tanya Razi \u2014 asisten riset Al-Qur\u2019an & Hadis',
      name: 'Razi',
      role: 'Asisten riset Al-Qur\u2019an & Hadis',
      close: 'Tutup obrolan',
      send: 'Kirim',
      placeholder: 'Tanya tentang ayat, hadis, atau sebuah tema\u2026',
      intro: 'Assalamu\u2019alaikum. Saya bisa menelusuri Al-Qur\u2019an dan kitab-kitab hadis di tafseer.id dan hadeeth.id. Setiap jawaban bersandar pada teksnya \u2014 silakan bertanya.',
      chips: [
        'Apa kata Al-Qur\u2019an tentang sabar?',
        'Hadis tentang niat',
        'Ayat tentang berbakti kepada orang tua'
      ],
      thinking: 'Menelusuri teks\u2026',
      slow: 'Masih mencari \u2014 yang ini butuh waktu sebentar\u2026',
      error: 'Tidak dapat menghubungi asisten. Silakan coba lagi.',
      rateLimit: 'Terlalu banyak pesan. Mohon tunggu sebentar, lalu coba lagi.',
      offline: 'Asisten sedang bangun. Coba lagi sesaat lagi.',
      tooLong: 'Pesan terlalu panjang. Mohon dipersingkat.',
      disclaimer: 'Jawaban dihasilkan AI. Selalu periksa rujukannya.',
    },
  };
  var T = STRINGS[CONFIG.lang];

  var CSS = [
    '#razi-chat-root{position:fixed;right:20px;bottom:20px;z-index:2147483000;',
    'font-family:inherit;font-size:15px;line-height:1.55;color-scheme:light dark;}',
    '#razi-chat-root *{box-sizing:border-box;}',
    '#razi-launcher{position:relative;display:flex;align-items:center;justify-content:center;',
    'width:62px;height:62px;padding:0;border:none;border-radius:50%;cursor:pointer;',
    'background:transparent;box-shadow:0 10px 30px rgba(0,0,0,.28);',
    'transition:transform .18s ease,box-shadow .18s ease;}',
    '#razi-launcher:hover{transform:translateY(-2px) scale(1.03);box-shadow:0 14px 36px rgba(0,0,0,.34);}',
    '#razi-launcher:focus-visible{outline:3px solid #10b981;outline-offset:3px;}',
    '#razi-launcher img{width:62px;height:62px;border-radius:50%;object-fit:cover;display:block;',
    'border:2px solid rgba(255,255,255,.9);}',
    '#razi-launcher .razi-dot{position:absolute;right:2px;bottom:3px;width:13px;height:13px;',
    'border-radius:50%;background:#10b981;border:2px solid #fff;}',
    '#razi-chat-panel{position:absolute;right:0;bottom:76px;width:390px;max-width:calc(100vw - 32px);',
    'height:min(620px,calc(100vh - 120px));display:flex;flex-direction:column;overflow:hidden;',
    'border-radius:18px;background:var(--razi-bg,#fff);color:var(--razi-fg,#111827);',
    'border:1px solid var(--razi-border,rgba(15,23,42,.12));',
    'box-shadow:0 24px 60px rgba(0,0,0,.28);transform-origin:bottom right;',
    'transition:opacity .16s ease,transform .16s ease;}',
    '#razi-chat-panel[hidden]{display:none;}',
    '#razi-chat-panel.razi-closed{opacity:0;transform:scale(.94) translateY(8px);pointer-events:none;}',
    '.razi-head{display:flex;align-items:center;gap:10px;padding:12px 14px;',
    'background:linear-gradient(135deg,#0f766e,#10b981);color:#fff;flex:0 0 auto;}',
    '.razi-head img{width:38px;height:38px;border-radius:50%;object-fit:cover;border:2px solid rgba(255,255,255,.75);flex:0 0 auto;}',
    '.razi-head-text{min-width:0;flex:1 1 auto;}',
    '.razi-head-name{font-weight:700;font-size:15px;line-height:1.2;}',
    '.razi-head-role{font-size:11.5px;opacity:.9;line-height:1.3;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
    '.razi-close{background:rgba(255,255,255,.16);border:none;color:#fff;width:30px;height:30px;',
    'border-radius:9px;cursor:pointer;font-size:17px;line-height:1;display:flex;align-items:center;justify-content:center;flex:0 0 auto;}',
    '.razi-close:hover{background:rgba(255,255,255,.3);}',
    '.razi-body{flex:1 1 auto;overflow-y:auto;padding:14px;display:flex;flex-direction:column;gap:10px;',
    'background:var(--razi-body,#f8fafc);}',
    '.razi-msg{max-width:86%;padding:9px 12px;border-radius:14px;white-space:pre-wrap;word-wrap:break-word;',
    'overflow-wrap:anywhere;font-size:14px;line-height:1.55;}',
    '.razi-msg.razi-user{align-self:flex-end;background:#10b981;color:#fff;border-bottom-right-radius:5px;}',
    '.razi-msg.razi-bot{align-self:flex-start;background:var(--razi-bot,#fff);color:var(--razi-fg,#111827);',
    'border:1px solid var(--razi-border,rgba(15,23,42,.10));border-bottom-left-radius:5px;}',
    '.razi-msg.razi-err{align-self:flex-start;background:#fef2f2;color:#991b1b;border:1px solid #fecaca;}',
    '.razi-msg a{color:#0f766e;text-decoration:underline;}',
    '.razi-msg code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12.5px;',
    'background:rgba(15,23,42,.06);padding:1px 4px;border-radius:4px;}',
    '.razi-typing{align-self:flex-start;display:inline-flex;gap:4px;padding:11px 14px;border-radius:14px;',
    'background:var(--razi-bot,#fff);border:1px solid var(--razi-border,rgba(15,23,42,.10));}',
    '.razi-typing i{width:6px;height:6px;border-radius:50%;background:#94a3b8;animation:razi-bounce 1.2s infinite;}',
    '.razi-typing i:nth-child(2){animation-delay:.16s}.razi-typing i:nth-child(3){animation-delay:.32s}',
    '@keyframes razi-bounce{0%,60%,100%{transform:translateY(0);opacity:.55}30%{transform:translateY(-4px);opacity:1}}',
    '.razi-chips{display:flex;flex-direction:column;gap:7px;align-self:stretch;}',
    '.razi-chip{text-align:left;background:var(--razi-bot,#fff);border:1px solid var(--razi-border,rgba(15,23,42,.14));',
    'border-radius:11px;padding:9px 11px;font-size:13px;cursor:pointer;color:inherit;font-family:inherit;}',
    '.razi-chip:hover{border-color:#10b981;color:#0f766e;}',
    '.razi-foot{flex:0 0 auto;border-top:1px solid var(--razi-border,rgba(15,23,42,.10));',
    'background:var(--razi-bg,#fff);padding:9px 10px;}',
    '.razi-inputrow{display:flex;align-items:flex-end;gap:7px;}',
    '.razi-input{flex:1 1 auto;resize:none;max-height:110px;min-height:40px;padding:9px 11px;font-family:inherit;',
    'font-size:14px;line-height:1.45;border-radius:11px;border:1px solid var(--razi-border,rgba(15,23,42,.16));',
    'background:var(--razi-body,#f8fafc);color:inherit;outline:none;}',
    '.razi-input:focus{border-color:#10b981;}',
    '.razi-send{flex:0 0 auto;width:40px;height:40px;border-radius:11px;border:none;cursor:pointer;',
    'background:#10b981;color:#fff;display:flex;align-items:center;justify-content:center;font-size:17px;}',
    '.razi-send:disabled{opacity:.45;cursor:default;}',
    '.razi-note{margin-top:6px;font-size:10.5px;color:#94a3b8;text-align:center;}',
    '@media (prefers-color-scheme:dark){',
    '#razi-chat-root{--razi-bg:#111827;--razi-body:#0b1220;--razi-fg:#e5e7eb;--razi-bot:#16203a;',
    '--razi-border:rgba(148,163,184,.22);}',
    '.razi-msg.razi-err{background:#2a1215;color:#fca5a5;border-color:#7f1d1d;}',
    '.razi-msg code{background:rgba(148,163,184,.14);}',
    '}',
    '@media (max-width:520px){',
    '#razi-chat-root{right:14px;bottom:14px;}',
    '#razi-chat-panel{position:fixed;right:8px;left:8px;bottom:8px;top:8px;width:auto;height:auto;max-width:none;}',
    '}',
    '@media (prefers-reduced-motion:reduce){#razi-launcher,#razi-chat-panel{transition:none}',
    '.razi-typing i{animation:none}}'
  ].join('');

  /* ---------- helpers ---------- */

  function el(tag, cls, attrs) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'text') node.textContent = attrs[k];
      else node.setAttribute(k, attrs[k]);
    });
    return node;
  }

  // Only text is inserted into the transcript. The reply arrives from a model,
  // so it is escaped first and a tiny subset of markup is re-applied on top.
  function formatReply(text) {
    var safe = String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
    safe = safe.replace(/```([\s\S]*?)```/g, function (_m, code) {
      return '<code>' + code.trim() + '</code>';
    });
    safe = safe.replace(/`([^`\n]+)`/g, '<code>$1</code>');
    safe = safe.replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>');
    // Markdown links become anchors with a readable label, so a citation reads
    // as "Sahih al-Bukhari #4" instead of a long URL in the narrow panel.
    // They are parked on placeholders so the bare-URL pass cannot re-wrap them.
    var links = [];
    safe = safe.replace(/\[([^\]\n]{1,90})\]\((https?:\/\/[^\s)]+)\)/g, function (_m, label, url) {
      links.push('<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + label + '</a>');
      return '\u0000L' + (links.length - 1) + '\u0000';
    });
    safe = safe.replace(/(https?:\/\/[^\s<]+)/g, function (url) {
      return '<a href="' + url + '" target="_blank" rel="noopener noreferrer">' + url + '</a>';
    });
    safe = safe.replace(/\u0000L(\d+)\u0000/g, function (_m, i) {
      return links[+i] || '';
    });
    return safe;
  }

  function newSessionId() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID().replace(/-/g, '');
    return 's' + Date.now().toString(36) + Math.random().toString(36).slice(2, 10);
  }

  function sessionId() {
    var id = null;
    try { id = localStorage.getItem(CONFIG.sessionKey); } catch (e) {}
    if (!id) {
      id = newSessionId();
      try { localStorage.setItem(CONFIG.sessionKey, id); } catch (e) {}
    }
    return id;
  }

  /* ---------- build ---------- */

  var style = el('style');
  style.textContent = CSS;
  document.head.appendChild(style);

  var root = el('div', null, { id: 'razi-chat-root' });

  var launcher = el('button', null, {
    id: 'razi-launcher',
    type: 'button',
    'aria-label': T.launcherTitle,
    title: T.launcherTitle,
    'aria-expanded': 'false',
    'aria-controls': 'razi-chat-panel'
  });
  var launcherImg = el('img', null, { src: CONFIG.avatar, alt: T.name, width: '62', height: '62' });
  launcher.appendChild(launcherImg);
  launcher.appendChild(el('span', 'razi-dot', { 'aria-hidden': 'true' }));

  var panel = el('div', null, {
    id: 'razi-chat-panel',
    role: 'dialog',
    'aria-modal': 'false',
    'aria-label': T.name + ' — ' + T.role,
    hidden: '',
    class: 'razi-closed'
  });

  var head = el('div', 'razi-head');
  head.appendChild(el('img', null, { src: CONFIG.avatar, alt: '', width: '38', height: '38' }));
  var headText = el('div', 'razi-head-text');
  headText.appendChild(el('div', 'razi-head-name', { text: T.name }));
  headText.appendChild(el('div', 'razi-head-role', { text: T.role }));
  head.appendChild(headText);
  var closeBtn = el('button', 'razi-close', { type: 'button', 'aria-label': T.close, title: T.close, text: '\u00d7' });
  head.appendChild(closeBtn);

  var body = el('div', 'razi-body', { role: 'log', 'aria-live': 'polite', 'aria-relevant': 'additions' });

  var foot = el('div', 'razi-foot');
  var inputRow = el('div', 'razi-inputrow');
  var input = el('textarea', 'razi-input', { rows: '1', placeholder: T.placeholder, 'aria-label': T.placeholder });
  var sendBtn = el('button', 'razi-send', { type: 'button', 'aria-label': T.send, title: T.send, text: '\u27a4' });
  inputRow.appendChild(input);
  inputRow.appendChild(sendBtn);
  foot.appendChild(inputRow);
  foot.appendChild(el('div', 'razi-note', { text: T.disclaimer }));

  panel.appendChild(head);
  panel.appendChild(body);
  panel.appendChild(foot);
  root.appendChild(panel);
  root.appendChild(launcher);

  function mount() {
    if (!document.body) return;
    document.body.appendChild(root);
  }
  if (document.body) mount();
  else document.addEventListener('DOMContentLoaded', mount);

  /* ---------- transcript ---------- */

  var started = false;
  var busy = false;

  function addUser(text) {
    var node = el('div', 'razi-msg razi-user');
    node.textContent = text;
    body.appendChild(node);
    scrollDown();
    return node;
  }

  function addBot(html) {
    var node = el('div', 'razi-msg razi-bot');
    node.innerHTML = formatReply(html);
    body.appendChild(node);
    scrollDown();
    return node;
  }

  function addError(text) {
    var node = el('div', 'razi-msg razi-err');
    node.textContent = text;
    body.appendChild(node);
    scrollDown();
  }

  function scrollDown() {
    requestAnimationFrame(function () {
      body.scrollTop = body.scrollHeight;
    });
  }

  function seed() {
    if (started) return;
    started = true;
    addBot(T.intro);
    var chips = el('div', 'razi-chips');
    T.chips.forEach(function (prompt) {
      var chip = el('button', 'razi-chip', { type: 'button', text: prompt });
      chip.addEventListener('click', function () {
        chips.remove();
        submit(prompt);
      });
      chips.appendChild(chip);
    });
    body.appendChild(chips);
    scrollDown();
  }

  /* ---------- request ---------- */

  var typing = null;

  function showTyping() {
    if (typing) return;
    typing = el('div', 'razi-typing', { 'aria-label': T.thinking });
    typing.appendChild(el('i'));
    typing.appendChild(el('i'));
    typing.appendChild(el('i'));
    body.appendChild(typing);
    scrollDown();
  }

  function hideTyping() {
    if (!typing) return;
    typing.remove();
    typing = null;
  }

  function setBusy(value) {
    busy = value;
    sendBtn.disabled = value;
    input.disabled = value;
  }

  async function submit(text) {
    var message = String(text == null ? input.value : text).trim();
    if (!message || busy) return;
    if (message.length > CONFIG.maxChars) {
      addError(T.tooLong);
      return;
    }

    addUser(message);
    input.value = '';
    autoGrow();
    setBusy(true);
    showTyping();

    var slowTimer = setTimeout(function () {
      if (typing) {
        var note = el('div', 'razi-msg razi-bot');
        note.textContent = T.slow;
        body.appendChild(note);
        scrollDown();
      }
    }, CONFIG.slowNoticeMs);

    var controller = new AbortController();
    var timeout = setTimeout(function () { controller.abort(); }, CONFIG.requestTimeoutMs);

    try {
      var res = await fetch(CONFIG.api, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: message, session_id: sessionId() }),
        signal: controller.signal,
      });

      var data = null;
      try { data = await res.json(); } catch (e) {}

      hideTyping();

      if (res.status === 429) {
        addError(T.rateLimit);
      } else if (res.status === 503) {
        addError(T.offline);
      } else if (!res.ok || !data || !data.reply) {
        addError((data && data.error) ? data.error : T.error);
      } else {
        addBot(data.reply);
      }
    } catch (err) {
      hideTyping();
      addError(T.error);
    } finally {
      clearTimeout(slowTimer);
      clearTimeout(timeout);
      setBusy(false);
      input.focus();
    }
  }

  /* ---------- chrome ---------- */

  function autoGrow() {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 110) + 'px';
  }

  function open() {
    seed();
    panel.hidden = false;
    panel.classList.remove('razi-closed');
    launcher.setAttribute('aria-expanded', 'true');
    try { localStorage.setItem(CONFIG.openKey, '1'); } catch (e) {}
    setTimeout(function () { input.focus(); }, 60);
  }

  function close() {
    panel.classList.add('razi-closed');
    launcher.setAttribute('aria-expanded', 'false');
    try { localStorage.setItem(CONFIG.openKey, '0'); } catch (e) {}
    setTimeout(function () {
      if (panel.classList.contains('razi-closed')) panel.hidden = true;
    }, 170);
    launcher.focus();
  }

  function toggle() {
    if (panel.hidden || panel.classList.contains('razi-closed')) open();
    else close();
  }

  launcher.addEventListener('click', toggle);
  closeBtn.addEventListener('click', close);
  sendBtn.addEventListener('click', function () { submit(); });

  input.addEventListener('input', autoGrow);
  input.addEventListener('keydown', function (event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      submit();
    }
  });

  panel.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') {
      event.stopPropagation();
      close();
    }
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && !panel.hidden && !panel.classList.contains('razi-closed')) close();
  });

  // Re-open when the reader left it open last visit, but never steal focus.
  try {
    if (localStorage.getItem(CONFIG.openKey) === '1') {
      seed();
      panel.hidden = false;
      panel.classList.remove('razi-closed');
      launcher.setAttribute('aria-expanded', 'true');
    }
  } catch (e) {}

  // Image fallback: if the avatar is missing, keep the button usable.
  launcherImg.addEventListener('error', function () {
    launcherImg.style.display = 'none';
    launcher.style.background = 'linear-gradient(135deg,#0f766e,#10b981)';
    launcher.textContent = 'R';
    launcher.style.color = '#fff';
    launcher.style.fontWeight = '700';
    launcher.style.fontSize = '24px';
  });

  window.RaziChat = {
    open: open,
    close: close,
    toggle: toggle,
    reset: function () {
      try { localStorage.removeItem(CONFIG.sessionKey); } catch (e) {}
      body.textContent = '';
      started = false;
      seed();
    },
    config: CONFIG,
  };
})();
