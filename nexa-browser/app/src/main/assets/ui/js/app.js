/* ==========================================================================
   NexaBrowser — Connected Mobile Browser UI + Native Android Services
   Vanilla JS by design: lightweight, no framework runtime, no network CDN.
   ========================================================================== */
(function () {
  "use strict";

  const store = window.NexaStore;
  const $ = (selector, root) => (root || document).querySelector(selector);
  const $$ = (selector, root) => Array.from((root || document).querySelectorAll(selector));
  const esc = (value) => String(value == null ? "" : value).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const t = (key) => (window.NEXA_I18N[store.state.lang] || window.NEXA_I18N.ar)[key] || key;
  const isAr = () => store.state.lang === "ar";
  const nowIso = () => new Date().toISOString();
  let toastTimer = null;
  let tabsFilter = "normal";
  let downloadsFilter = "all";
  let extensionFilter = "all";
  let extensionSearch = "";
  let libraryTab = "bookmarks";
  let bookmarkFolder = "الكل";
  let editingShortcuts = false;
  let readerArticle = null;
  let downloadPollTimer = null;
  let lastDownloadSamples = {};
  let currentSearchPrefix = "";
  let hardwareBackPending = false;

  const ICONS = {
    home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/><path d="M9 21v-6h6v6"/>',
    incognito: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M9 12v3M15 12v3"/><path d="M7.5 8.5 6 5M16.5 8.5 18 5"/><circle cx="8.5" cy="16" r="1.4"/><circle cx="15.5" cy="16" r="1.4"/>',
    search: '<circle cx="10.8" cy="10.8" r="6.8"/><path d="m16 16 4.5 4.5"/>',
    tabs: '<rect x="4" y="5" width="15" height="15" rx="3"/><path d="M8 3h10a3 3 0 0 1 3 3v10"/>',
    layers: '<path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5M3 16l9 5 9-5"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5M12 15V3"/>',
    menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
    more: '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    close: '<path d="m18 6-12 12M6 6l12 12"/>',
    mic: '<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8"/>',
    qr: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14v3M14 20h3M20 20v1"/>',
    sparkles: '<path d="m12 3 1.9 5.8L20 11l-6.1 2.2L12 19l-1.9-5.8L4 11l6.1-2.2L12 3Z"/><path d="m19 14 1.1 2.9L23 18l-2.9 1.1L19 22l-1.1-2.9L15 18l2.9-1.1L19 14Z"/>',
    shield: '<path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/>',
    'shield-check': '<path d="M12 22s8-4 8-11V5l-8-3-8 3v6c0 7 8 11 8 11Z"/><path d="m9 12 2 2 4-4"/>',
    lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    unlock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 7.5-2"/>',
    key: '<circle cx="8" cy="15" r="5"/><path d="m11.5 11.5 9-9M17 6l3 3M14 9l3 3"/>',
    bookmark: '<path d="M6 4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18l-6-4-6 4z"/>',
    history: '<path d="M3 12a9 9 0 1 0 2.6-6.4L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>',
    globe: '<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/>',
    puzzle: '<path d="M19 13v6a2 2 0 0 1-2 2h-3v-2a2 2 0 0 0-4 0v2H7a2 2 0 0 1-2-2v-3H3a2 2 0 0 1 0-4h2V8a2 2 0 0 1 2-2h3V4a2 2 0 0 1 4 0v2h3a2 2 0 0 1 2 2v3h2a2 2 0 0 1 0 4z"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1 1.4 1.1-1.4 2.4-1.7-.6a8 8 0 0 1-1.5.9L16 21h-8l-.3-2.1a8 8 0 0 1-1.5-.9l-1.7.6-1.4-2.4 1.4-1.1a8 8 0 0 1 0-1.8l-1.4-1.1 1.4-2.4 1.7.6a8 8 0 0 1 1.5-.9L8 7h8l.3 2.1a8 8 0 0 1 1.5.9l1.7-.6 1.4 2.4-1.4 1.1a8 8 0 0 1-.1 2.1Z"/>',
    code: '<path d="m8 17-5-5 5-5M16 7l5 5-5 5M14 4l-4 16"/>',
    desktop: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
    memory: '<rect x="4" y="5" width="16" height="14" rx="2"/><path d="M9 9h6v6H9zM8 2v3M16 2v3M8 19v3M16 19v3M2 9h2M2 15h2M20 9h2M20 15h2"/>',
    reload: '<path d="M20 7v5h-5M4 17v-5h5"/><path d="M5.6 9a7 7 0 0 1 11.5-2L20 12M4 12l2.9 5a7 7 0 0 0 11.5-2"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    forward: '<path d="m9 18 6-6-6-6"/>',
    chevron: '<path d="m9 18 6-6-6-6"/>',
    'arrow-go': '<path d="M5 12h14M13 5l7 7-7 7"/>',
    'arrow-left-small': '<path d="m14 18-6-6 6-6"/>',
    trash: '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v5M14 11v5"/>',
    star: '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2L12 17.3l-5.6 2.9 1.1-6.2L3 9.6l6.2-.9L12 3Z"/>',
    external: '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 13v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h5"/>',
    share: '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.7 10.7 6.6-4.4M8.7 13.3l6.6 4.4"/>',
    info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
    alert: '<path d="m10.3 3.9-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.7-3.1l-8-14a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
    bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
    cookie: '<path d="M12 2a4 4 0 0 0 4 4 4 4 0 0 0 4 4 8 8 0 1 1-8-8Z"/><circle cx="8" cy="12" r=".7"/><circle cx="12" cy="16" r=".7"/><circle cx="16" cy="12" r=".7"/>',
    radar: '<circle cx="12" cy="12" r="9"/><path d="M12 3v9l6.4 6.4M12 12l7-7"/><circle cx="12" cy="12" r="1"/>',
    adblock: '<path d="M5 5l14 14M9 4h6a3 3 0 0 1 3 3v4M6 8v9a3 3 0 0 0 3 3h6"/><path d="M12 3 5 6v5c0 5 3.5 8 7 10 1.3-.6 2.6-1.4 3.7-2.4"/>',
    sync: '<path d="M20 7v5h-5M4 17v-5h5"/><path d="M5.6 9A7 7 0 0 1 18 7l2 5M4 12l2 5a7 7 0 0 0 12.4-2"/>',
    devices: '<rect x="3" y="4" width="13" height="11" rx="2"/><path d="M6 19h7M9 15v4M18 8h3v12h-7v-2"/>',
    text: '<path d="M4 7V4h16v3M12 4v16M8 20h8"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    grid: '<rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="8" rx="1"/><rect x="3" y="13" width="8" height="8" rx="1"/><rect x="13" y="13" width="8" height="8" rx="1"/>',
    pin: '<path d="m16 3 5 5-4 1-4 4-1 4-3-3-6 6-1-1 6-6-3-3 4-1 4-4 1-4Z"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    power: '<path d="M12 2v10M6.2 5.5a8 8 0 1 0 11.6 0"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    copy: '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
    pause: '<path d="M8 5h3v14H8zM15 5h3v14h-3z"/>',
    play: '<path d="m7 4 14 8-14 8V4Z"/>',
    translate: '<path d="m5 8 6 6M4 14l6-6 2-3M2 5h12M7 2v3M13 21l5-11 5 11M14 18h8"/>',
    camera: '<path d="M14 4h-4l-2 3H5a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2-3Z"/><circle cx="12" cy="13" r="3"/>',
    minimize: '<path d="M5 12h14"/>',
    sort: '<path d="M4 6h16M7 12h10M10 18h4"/>',
    keyboard: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M6 13h.01M10 13h.01M14 13h.01M18 13h.01M8 16h8"/>',
    x: '<path d="m18 6-12 12M6 6l12 12"/>'
  };

  function svg(name, size) {
    return '<svg width="' + (size || 18) + '" height="' + (size || 18) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (ICONS[name] || ICONS.info) + '</svg>';
  }

  function hydrateIcons(root) {
    $$('[data-icon]', root || document).forEach(node => {
      const key = node.getAttribute('data-icon');
      node.innerHTML = svg(key, Number(node.getAttribute('data-icon-size')) || 18);
    });
  }

  function applyTranslations() {
    const dict = window.NEXA_I18N[store.state.lang] || window.NEXA_I18N.ar;
    document.documentElement.lang = store.state.lang;
    document.documentElement.dir = dict.dir;
    $$('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      if (dict[key]) el.textContent = dict[key];
    });
    $$('[data-i18n-placeholder]').forEach(el => {
      const key = el.getAttribute('data-i18n-placeholder');
      if (dict[key]) el.setAttribute('placeholder', dict[key]);
    });
    document.body.dataset.wallpaper = store.state.wallpaper || 'cyber-neon';
  }

  function persist() {
    store.save();
  }

  function toast(message, duration) {
    const node = $('#toast');
    if (!node) return;
    node.textContent = message;
    node.classList.add('visible');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.remove('visible'), duration || 2300);
  }

  function nativeCall(name, ...args) {
    try {
      if (window.NexaNative && typeof window.NexaNative[name] === 'function') {
        return window.NexaNative[name](...args);
      }
    } catch (err) {
      store.logDev('native-error', name + ': ' + err.message);
    }
    return null;
  }

  function haptic(type) {
    nativeCall('triggerHaptic', type || 'light');
  }

  function humanSize(bytes) {
    const n = Number(bytes) || 0;
    if (n < 1024) return n + ' B';
    if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB';
    if (n < 1024 * 1024 * 1024) return (n / 1024 / 1024).toFixed(1) + ' MB';
    return (n / 1024 / 1024 / 1024).toFixed(2) + ' GB';
  }

  function hostOf(url) {
    try { return new URL(url).hostname.replace(/^www\./, ''); } catch (_) { return url || ''; }
  }

  function screenNavActive(screen) {
    const bottomScreen = {
      home: 'home', search: 'search', tabs: 'tabs', downloads: 'downloads',
      browser: 'home', extensions: 'menu', privacy: 'menu', vpn: 'menu',
      bookmarks: 'menu', passwords: 'menu', reader: 'menu', sync: 'menu', settings: 'menu'
    }[screen] || 'menu';
    $$('.nav-item').forEach(btn => btn.classList.toggle('active', btn.dataset.screen === bottomScreen || (btn.dataset.action === 'open-menu' && bottomScreen === 'menu')));
  }

  function navigate(screen, options) {
    const allowed = ['home', 'search', 'tabs', 'downloads', 'extensions', 'privacy', 'vpn', 'bookmarks', 'passwords', 'reader', 'sync', 'settings', 'browser'];
    if (!allowed.includes(screen)) screen = 'home';
    store.state.activeScreen = screen;
    $$('.screen-view').forEach(el => el.classList.toggle('active', el.id === 'screen-' + screen));
    screenNavActive(screen);
    if (screen !== 'browser') nativeCall('setViewportVisible', false, 0, 0);
    if (screen === 'home') renderHome();
    if (screen === 'search') { renderSearch(); setTimeout(() => { const input = $('#search-page-input'); if (options && options.focus && input) input.focus(); }, 80); }
    if (screen === 'tabs') renderTabs();
    if (screen === 'downloads') renderDownloads();
    if (screen === 'extensions') renderExtensions();
    if (screen === 'privacy') renderPrivacy();
    if (screen === 'vpn') renderVpn();
    if (screen === 'bookmarks') renderLibrary();
    if (screen === 'passwords') renderPasswords();
    if (screen === 'reader') renderReader();
    if (screen === 'sync') renderSync();
    if (screen === 'settings') renderSettings();
    persist();
  }

  function ensureTab() {
    if (!store.state.tabs || !store.state.tabs.length) {
      const tab = makeTab(false);
      store.state.tabs = [tab];
      store.state.activeTabId = tab.id;
    }
    let active = store.state.tabs.find(tab => tab.id === store.state.activeTabId);
    if (!active) {
      active = store.state.tabs[0];
      store.state.activeTabId = active.id;
    }
    return active;
  }

  function makeTab(isPrivate) {
    return {
      id: 'tab-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 7),
      title: isAr() ? (isPrivate ? 'تبويب خاص جديد' : 'تبويب جديد') : (isPrivate ? 'New Private Tab' : 'New Tab'),
      url: 'nexa://home',
      isPrivate: !!isPrivate,
      pinned: false,
      hibernated: false,
      desktopMode: false,
      zoom: 100,
      createdAt: Date.now(),
      lastActive: Date.now()
    };
  }

  function createTab(isPrivate, url) {
    const tab = makeTab(isPrivate);
    if (url) tab.url = normalizeAddress(url);
    store.state.tabs.unshift(tab);
    store.state.activeTabId = tab.id;
    store.state.incognitoMode = !!isPrivate;
    document.body.classList.toggle('incognito-active', !!isPrivate);
    persist();
    if (tab.url === 'nexa://home') navigate('home'); else openTab(tab);
    haptic('light');
    return tab;
  }

  function closeTab(tabId) {
    const idx = store.state.tabs.findIndex(x => x.id === tabId);
    if (idx < 0) return;
    const tab = store.state.tabs[idx];
    if (tab.pinned) {
      toast(isAr() ? 'أزل التثبيت أولًا لإغلاق هذا التبويب' : 'Unpin this tab before closing it');
      return;
    }
      if (tab.url && !tab.url.startsWith('nexa://') && !tab.isPrivate) {
        store.state.recentlyClosedTabs = [{ id: 'closed-' + Date.now(), title: tab.title || tab.url, url: tab.url, isPrivate: false, closedAt: isAr() ? 'الآن' : 'just now' }].concat(store.state.recentlyClosedTabs || []).slice(0, 12);
      }
    nativeCall('closeTab', tabId);
    store.state.tabs.splice(idx, 1);
    if (store.state.activeTabId === tabId) {
      store.state.activeTabId = store.state.tabs.length ? store.state.tabs[0].id : '';
      const next = ensureTab();
      if (next.url && !next.url.startsWith('nexa://')) openTab(next); else navigate('home');
    }
    persist();
    if (store.state.activeScreen === 'tabs') renderTabs();
    renderNavBadge();
    haptic('light');
  }

  function openTab(tab) {
    if (!tab) return;
    store.state.activeTabId = tab.id;
    tab.lastActive = Date.now();
    store.state.incognitoMode = !!tab.isPrivate;
    document.body.classList.toggle('incognito-active', !!tab.isPrivate);
    if (!tab.url || tab.url.startsWith('nexa://')) {
      navigate('home');
      return;
    }
    navigate('browser');
    const urlInput = $('#browser-url-input');
    if (urlInput) urlInput.value = tab.url;
    const placeholder = $('#browser-native-placeholder');
    if (placeholder) placeholder.style.display = 'flex';
    nativeCall('openOrSwitchTab', tab.id, tab.url, !!tab.isPrivate, !!tab.desktopMode);
    nativeCall('setViewportVisible', true, 62, 68);
    renderNavBadge();
  }

  function closeAllTabs() {
    const closable = store.state.tabs.filter(tab => !tab.pinned);
    if (!closable.length) {
      toast(isAr() ? 'لا توجد تبويبات قابلة للإغلاق' : 'No unpinned tabs to close');
      return;
    }
    showSheet('<h2>' + esc(t('closeAllTabs')) + '</h2><p class="sheet-subtitle">' + (isAr() ? 'سيتم إغلاق ' + closable.length + ' تبويب غير مثبّت.' : 'Close ' + closable.length + ' unpinned tabs?') + '</p><div class="sheet-form-actions"><button class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" data-action="confirm-close-all">' + esc(t('closeAllTabs')) + '</button></div>');
  }

  function confirmCloseAll() {
    store.state.tabs.filter(tab => !tab.pinned).forEach(tab => {
      nativeCall('closeTab', tab.id);
      if (tab.url && !tab.url.startsWith('nexa://') && !tab.isPrivate) {
        store.state.recentlyClosedTabs.unshift({ id: 'closed-' + Date.now() + Math.random(), title: tab.title || tab.url, url: tab.url, closedAt: isAr() ? 'الآن' : 'just now' });
      }
    });
    store.state.tabs = store.state.tabs.filter(tab => tab.pinned);
    if (!store.state.tabs.length) store.state.tabs.push(makeTab(false));
    store.state.activeTabId = store.state.tabs[0].id;
    store.state.recentlyClosedTabs = (store.state.recentlyClosedTabs || []).slice(0, 12);
    closeSheet();
    navigate('tabs');
    toast(isAr() ? 'أُغلقت التبويبات غير المثبتة' : 'Unpinned tabs closed');
  }

  function restoreClosed(id) {
    const idx = store.state.recentlyClosedTabs.findIndex(x => x.id === id);
    if (idx < 0) return;
    const old = store.state.recentlyClosedTabs.splice(idx, 1)[0];
    createTab(!!old.isPrivate, old.url);
  }

  function normalizeAddress(value) {
    const raw = String(value || '').trim();
    if (!raw) return '';
    if (/^(https?|file|about):/i.test(raw)) return raw;
    if (/^(mailto|tel):/i.test(raw)) return raw;
    if (/^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?([/?#].*)?$/i.test(raw) || /^(\[?[a-f0-9:]+\]?)(:\d+)?([/?#].*)?$/i.test(raw) && raw.includes(':')) return 'http://' + raw;
    if (/^[^\s.]+\.[^\s]+/.test(raw) && !raw.includes(' ')) return 'https://' + raw;
    return searchUrl(raw);
  }

  function searchUrl(query) {
    const engine = store.state.searchEngine || 'google';
    const q = encodeURIComponent(query);
    const engines = {
      google: 'https://www.google.com/search?q=' + q,
      bing: 'https://www.bing.com/search?q=' + q,
      duckduckgo: 'https://duckduckgo.com/?q=' + q,
      brave: 'https://search.brave.com/search?q=' + q
    };
    if (engines[engine]) return engines[engine];
    const custom = (store.state.customSearchEngines || []).find(item => item.id === engine);
    if (custom && custom.urlTemplate && /^https?:\/\//i.test(custom.urlTemplate)) return custom.urlTemplate.replace('%s', q);
    return engines.google;
  }

  function submitSearch(value, prefix) {
    const raw = String(value || '').trim();
    if (!raw) return;
    const searchTerm = (prefix ? prefix + ' ' : '') + raw;
    const looksLikeUrl = /^(https?:\/\/|localhost(?::\d+)?(?:\/|$)|\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?(?:\/|$))/i.test(raw)
      || (/^[^\s]+\.[^\s]+(?:[/?#][^\s]*)?$/.test(raw) && raw.indexOf(' ') < 0);
    if (prefix || !looksLikeUrl) moveSearchHistory(searchTerm);
    let target;
    if (prefix !== undefined && prefix !== null) target = searchUrl(searchTerm);
    else target = normalizeAddress(raw);
    if (!/^https?:\/\//i.test(target)) {
      try { target = normalizeAddress(target); } catch (_) { target = searchUrl(raw); }
    }
    closeSheet();
    loadInActiveTab(target);
  }

  function loadInActiveTab(url) {
    if (!url) return;
    if (/^(mailto|tel):/i.test(url)) {
      nativeCall('openInExternalBrowser', url);
      return;
    }
    let tab = ensureTab();
    if (tab.url && !tab.url.startsWith('nexa://') && store.state.activeScreen !== 'home' && store.state.activeScreen !== 'search' && store.state.activeScreen !== 'tabs') {
      // Current browser tab is reused for address-bar edits.
    }
    tab.url = url;
    tab.title = hostOf(url) || url;
    tab.hibernated = false;
    tab.lastActive = Date.now();
    if (!tab.isPrivate && !store.state.privacy.doNotSaveHistory) {
      const entry = { id: 'h-' + Date.now(), title: tab.title, url: url, type: 'page', time: new Date().toLocaleTimeString(store.state.lang === 'ar' ? 'ar' : 'en', { hour: '2-digit', minute: '2-digit' }), visitedAt: nowIso() };
      const existing = store.state.history.findIndex(item => item.url === url);
      if (existing >= 0) store.state.history.splice(existing, 1);
      store.state.history.unshift(entry);
      store.state.history = store.state.history.slice(0, 250);
      store.state.recentSites = [{ id: 'r-' + Date.now(), title: tab.title, url: url, time: isAr() ? 'الآن' : 'just now' }].concat((store.state.recentSites || []).filter(item => item.url !== url)).slice(0, 6);
    }
    persist();
    if (window.NexaNative) openTab(tab);
    else {
      navigate('browser');
      const label = $('#browser-loading-label');
      if (label) label.textContent = url;
      window.open(url, '_blank');
    }
    renderHome();
  }

  function renderNavBadge() {
    const badge = $('#nav-tabs-badge');
    if (badge) badge.textContent = String((store.state.tabs || []).length);
    const active = ensureTab();
    const btn = $('#home-incognito-btn');
    if (btn) btn.classList.toggle('active', !!active.isPrivate);
  }

  function renderHome() {
    const active = ensureTab();
    document.body.classList.toggle('incognito-active', !!active.isPrivate);
    renderNavBadge();
    const engineButton = $('.engine-selector-btn');
    if (engineButton) engineButton.textContent = engineShortName(store.state.searchEngine);
    const shortcuts = $('#shortcuts-grid');
    if (shortcuts) {
      const list = store.state.shortcuts || [];
      shortcuts.innerHTML = list.map((item, index) => {
        const ctrls = editingShortcuts ? '<div class="shortcut-edit-controls"><button class="tiny-ctrl-btn" data-action="move-shortcut" data-index="' + index + '" data-delta="-1" aria-label="Move left">' + (isAr() ? '‹' : '‹') + '</button><button class="tiny-ctrl-btn" data-action="move-shortcut" data-index="' + index + '" data-delta="1" aria-label="Move right">›</button><button class="tiny-ctrl-btn danger" data-action="delete-shortcut" data-id="' + esc(item.id) + '" aria-label="Delete">×</button></div>' : '';
        return '<article class="shortcut-item ' + (editingShortcuts ? 'is-editing' : '') + '" data-shortcut-id="' + esc(item.id) + '" data-action="open-shortcut" data-url="' + esc(item.url) + '"><div class="shortcut-icon-box" style="background:' + esc(item.color || 'linear-gradient(135deg,#00e5ff,#8b5cf6)') + '">' + esc(item.icon || firstLetter(item.title)) + '</div><div class="shortcut-label">' + esc(item.title) + '</div>' + ctrls + '</article>';
      }).join('');
      if (!list.length) shortcuts.innerHTML = '<div class="empty-state" style="grid-column:1/-1"><strong>' + esc(isAr() ? 'أضف اختصارك الأول' : 'Add your first shortcut') + '</strong></div>';
    }
    const fav = $('#favorites-strip');
    if (fav) {
      const favorites = (store.state.bookmarks || []).filter(b => b.favorite).slice(0, 8);
      if (!favorites.length) {
        fav.innerHTML = '<div class="empty-inline">' + esc(isAr() ? 'احفظ صفحة في المفضلة لتظهر هنا' : 'Bookmark a page as a favorite to see it here') + '</div>';
      } else {
        fav.innerHTML = favorites.map(b => '<button class="fav-chip-card" data-action="open-url" data-url="' + esc(b.url) + '"><span class="fav-icon">' + svg('star', 15) + '</span><span class="fav-chip-copy"><strong>' + esc(b.title) + '</strong><small>' + esc(hostOf(b.url)) + '</small></span></button>').join('');
      }
    }
    const recents = $('#home-recents');
    if (recents) {
      const rows = (store.state.recentSites || []).slice(0, 4);
      recents.innerHTML = rows.length ? rows.map(item => '<button class="recent-row" data-action="open-url" data-url="' + esc(item.url) + '"><span class="recent-leading-icon">' + svg('history', 15) + '</span><span class="recent-main"><strong>' + esc(item.title || hostOf(item.url)) + '</strong><small>' + esc(hostOf(item.url)) + '</small></span><time>' + esc(item.time || '') + '</time></button>').join('') : '<div class="empty-inline">' + esc(isAr() ? 'ستظهر المواقع التي تزورها هنا على هذا الجهاز.' : 'Sites you visit will appear here on this device.') + '</div>';
    }
    renderPrivacyStats();
    if ($('#home-search-input')) $('#home-search-input').setAttribute('aria-label', t('searchPlaceholder'));
    const note = $('#home-privacy-note');
    if (note) note.textContent = isAr() ? (active.isPrivate ? 'تبويب خاص: لا يُحفظ السجل؛ قد تبقى Cookies مشتركة في WebView النظام' : 'بياناتك محفوظة على هذا الجهاز — دون مزامنة خفية') : (active.isPrivate ? 'Private tab: history is not saved; Android WebView cookies may remain shared' : 'Your data stays on this device — no hidden sync');
  }

  function firstLetter(value) { return String(value || 'N').trim().slice(0, 1).toUpperCase(); }

  function renderPrivacyStats() {
    let ads = Number(store.state.privacy.adsBlocked || 0);
    let trackers = Number(store.state.privacy.trackersBlocked || 0);
    let nativeStats = nativeCall('getNativePrivacyStats');
    if (nativeStats) {
      try {
        const parsed = JSON.parse(nativeStats);
        ads = Math.max(ads, Number(parsed.adsBlocked || 0));
        trackers = Math.max(trackers, Number(parsed.trackersBlocked || 0));
        store.state.privacy.adsBlocked = ads;
        store.state.privacy.trackersBlocked = trackers;
      } catch (_) { }
    }
    const savedKb = Math.round((ads * 18 + trackers * 2) / 1024 * 10) / 10;
    const saved = savedKb >= 1024 ? (savedKb / 1024).toFixed(1) + ' MB' : savedKb + ' KB';
    ['#home-ads-blocked', '#privacy-ads-stat'].forEach(id => { const n = $(id); if (n) n.textContent = ads.toLocaleString(); });
    ['#home-trackers-blocked', '#privacy-trackers-stat'].forEach(id => { const n = $(id); if (n) n.textContent = trackers.toLocaleString(); });
    ['#home-data-saved', '#privacy-saved-stat'].forEach(id => { const n = $(id); if (n) n.textContent = '~' + saved; });
  }

  function renderSearch() {
    const name = engineName(store.state.searchEngine);
    const logo = engineShortName(store.state.searchEngine);
    const summary = $('#search-engine-summary');
    if (summary) summary.innerHTML = '<div class="search-engine-meta"><span class="engine-logo">' + esc(logo) + '</span><div><strong>' + esc(isAr() ? 'محرك البحث الحالي' : 'Current search engine') + '</strong><div class="setting-sub">' + esc(name) + '</div></div></div><button class="secondary-btn" style="flex:0 0 auto" data-action="choose-engine">' + esc(isAr() ? 'تغيير' : 'Change') + '</button>';
    const list = $('#search-history-list');
    const searches = (store.state.history || []).filter(item => item.type === 'search').slice(0, 7);
    if (list) list.innerHTML = searches.length ? searches.map(item => '<button class="recent-row" data-action="search-again" data-query="' + esc(extractQuery(item.url) || item.title) + '"><span class="recent-leading-icon">' + svg('search', 15) + '</span><span class="recent-main"><strong>' + esc(item.title) + '</strong><small>' + esc(item.time || '') + '</small></span><span class="row-chevron">' + svg('arrow-go', 15) + '</span></button>').join('') : '<div class="empty-state"><div class="empty-icon">' + svg('search', 26) + '</div><strong>' + esc(isAr() ? 'لا توجد عمليات بحث محفوظة' : 'No recent searches') + '</strong><p>' + esc(isAr() ? 'ستبقى عمليات البحث الخاصة خارج السجل.' : 'Searches from private tabs are not recorded.') + '</p></div>';
    const engineButton = $('#screen-search .engine-selector-btn');
    if (engineButton) engineButton.textContent = logo;
  }

  function extractQuery(url) {
    try {
      const parsed = new URL(url);
      return parsed.searchParams.get('q') || parsed.searchParams.get('query') || '';
    } catch (_) { return ''; }
  }

  function renderTabs() {
    const all = store.state.tabs || [];
    const normal = all.filter(tab => !tab.isPrivate);
    const privateTabs = all.filter(tab => tab.isPrivate);
    $('#normal-tab-count').textContent = String(normal.length);
    $('#private-tab-count').textContent = String(privateTabs.length);
    $('#tab-filter-normal').classList.toggle('active', tabsFilter === 'normal');
    $('#tab-filter-private').classList.toggle('active', tabsFilter === 'private');
    $('#tabs-subtitle').textContent = isAr() ? (all.length + ' تبويب مفتوح · ذاكرة WebView مُدارة') : (all.length + ' open tabs · WebView memory managed');
    const statsRaw = nativeCall('getMemoryStats');
    if (statsRaw) {
      try { const stats = JSON.parse(statsRaw); $('#ram-stats').textContent = isAr() ? stats.liveWebViews + ' نشط · ' + stats.hibernatedTabs + ' مُجمّد' : stats.liveWebViews + ' live · ' + stats.hibernatedTabs + ' hibernated'; } catch (_) { }
    }
    const visible = (tabsFilter === 'private' ? privateTabs : normal);
    const grid = $('#tabs-grid');
    if (grid) {
      grid.className = store.state.tabsViewMode === 'list' ? 'tabs-list' : 'tabs-grid';
      grid.innerHTML = visible.length ? visible.map(tab => renderTabCard(tab)).join('') : '<div class="empty-state" style="grid-column:1/-1"><div class="empty-icon">' + svg(tabsFilter === 'private' ? 'incognito' : 'tabs', 28) + '</div><strong>' + esc(isAr() ? 'لا توجد تبويبات هنا' : 'No tabs here') + '</strong><p>' + esc(isAr() ? 'أنشئ تبويبًا جديدًا للمتابعة.' : 'Create a new tab to get started.') + '</p></div>';
      attachTabSwipe(grid);
    }
    const closed = $('#recently-closed-list');
    const list = (store.state.recentlyClosedTabs || []).filter(tab => !tab.isPrivate);
    if (closed) closed.innerHTML = list.length ? list.slice(0, 5).map(tab => '<div class="recent-row"><span class="recent-leading-icon">' + svg('history', 15) + '</span><span class="recent-main"><strong>' + esc(tab.title) + '</strong><small>' + esc(hostOf(tab.url)) + '</small></span><button class="tiny-ctrl-btn" data-action="restore-closed" data-id="' + esc(tab.id) + '">' + esc(t('restoreTab')) + '</button></div>').join('') : '<div class="empty-inline">' + esc(isAr() ? 'ستظهر التبويبات المغلقة هنا للاستعادة.' : 'Closed tabs will appear here for restore.') + '</div>';
    renderNavBadge();
  }

  function renderTabCard(tab) {
    const active = tab.id === store.state.activeTabId;
    const home = !tab.url || tab.url.startsWith('nexa://');
    let preview = '';
    if (!home && window.NexaNative && typeof window.NexaNative.getTabPreview === 'function') {
      try { preview = window.NexaNative.getTabPreview(tab.id) || ''; } catch (_) { preview = ''; }
    }
    const previewImage = /^data:image\//.test(preview) ? '<img class="tab-preview-img" alt="" src="' + preview + '">' : '';
    const label = tab.isPrivate ? (isAr() ? 'خاص' : 'Private') : (home ? 'NexaBrowser' : hostOf(tab.url));
    return '<article class="tab-card ' + (active ? 'active-tab ' : '') + (tab.isPrivate ? 'private-tab' : '') + '" data-tab-card="' + esc(tab.id) + '">' +
      '<div class="tab-card-header"><div class="tab-card-title-row"><span class="tab-preview-favicon">' + (tab.isPrivate ? '◉' : esc(firstLetter(hostOf(tab.url) || 'N'))) + '</span><div class="tab-card-title">' + esc(tab.title || (home ? 'NexaBrowser' : hostOf(tab.url))) + '</div></div><button class="tab-close-btn" data-action="close-tab" data-id="' + esc(tab.id) + '" aria-label="Close">' + svg('close', 15) + '</button></div>' +
      '<button class="tab-preview-box" data-action="switch-tab" data-id="' + esc(tab.id) + '"><div class="tab-preview-gradient"></div>' + previewImage + '<span class="tab-preview-domain">' + esc(label) + '</span></button>' +
      '<div class="tab-card-footer"><div class="tab-domain">' + (tab.isPrivate ? '<span class="private-label">' + esc(t('privateTabs')) + '</span>' : esc(home ? 'nexa://home' : hostOf(tab.url))) + (tab.hibernated ? ' · ' + esc(isAr() ? 'نائم' : 'hibernated') : '') + '</div><div class="tab-card-controls"><button class="tab-pin-btn ' + (tab.pinned ? 'pinned' : '') + '" data-action="pin-tab" data-id="' + esc(tab.id) + '" aria-label="Pin">' + svg('pin', 13) + '</button></div></div></article>';
  }

  function attachTabSwipe(root) {
    let startX = 0, startY = 0, target = null;
    root.querySelectorAll('.tab-card').forEach(card => {
      card.addEventListener('touchstart', e => { if (!e.touches.length) return; startX = e.touches[0].clientX; startY = e.touches[0].clientY; target = card; }, { passive: true });
      card.addEventListener('touchend', e => {
        if (!target || !e.changedTouches.length) return;
        const dx = e.changedTouches[0].clientX - startX;
        const dy = e.changedTouches[0].clientY - startY;
        if (Math.abs(dx) > 90 && Math.abs(dx) > Math.abs(dy) * 1.4) {
          const id = target.dataset.tabCard;
          const tab = store.state.tabs.find(x => x.id === id);
          if (tab && !tab.pinned) {
            target.style.transform = 'translateX(' + (dx > 0 ? 110 : -110) + 'px)';
            target.style.opacity = '0';
            setTimeout(() => closeTab(id), 140);
          }
        }
        target = null;
      }, { passive: true });
    });
  }

  function renderDownloads() {
    const items = store.state.downloads || [];
    const filtered = downloadsFilter === 'all' ? items : items.filter(item => item.category === downloadsFilter);
    const completed = items.filter(item => item.status === 'completed');
    const totalBytes = completed.reduce((sum, item) => sum + (Number(item.totalBytes || item.sizeBytes || 0)), 0);
    $('#downloads-count').textContent = String(items.length);
    $('#downloads-total-size').textContent = humanSize(totalBytes);
    $('#downloads-active').textContent = String(items.filter(item => ['downloading', 'pending', 'paused'].includes(item.status)).length);
    $$('#downloads-filters .chip-pill').forEach(btn => btn.classList.toggle('active', btn.dataset.filter === downloadsFilter));
    const list = $('#downloads-list');
    if (!filtered.length) {
      list.innerHTML = '<div class="empty-state"><div class="empty-icon">' + svg('download', 28) + '</div><strong>' + esc(isAr() ? 'لا توجد تنزيلات' : 'No downloads yet') + '</strong><p>' + esc(isAr() ? 'ستظهر الملفات التي تنزلها من صفحات الويب هنا. يمكنك إضافة رابط تنزيل يدويًا.' : 'Files downloaded from web pages appear here. You can also add a direct download URL.') + '</p><button class="btn-neon" style="margin-top:12px" data-action="new-download">' + esc(t('newDownloadBtn')) + '</button></div>';
      return;
    }
    list.innerHTML = filtered.map(item => {
      const total = Number(item.totalBytes || item.sizeBytes || 0);
      const down = Number(item.downloadedBytes || 0);
      const pct = total > 0 ? Math.max(0, Math.min(100, Math.round(down / total * 100))) : (item.status === 'completed' ? 100 : 0);
      const statusText = ({ completed: t('downloadComplete'), downloading: t('downloadActive'), pending: t('downloadPending'), paused: t('downloadPaused'), failed: t('downloadFailed'), canceled: t('downloadCanceled') })[item.status] || item.status || t('downloadUnknown');
      const fileIcon = ({ apk: 'APK', zip: 'ZIP', images: 'IMG', videos: 'VID', documents: 'DOC', audio: 'AUD', other: 'FILE' })[item.category] || 'FILE';
      const nativeId = item.nativeDownloadId || '';
      const progress = ['downloading', 'pending', 'paused'].includes(item.status) ? '<div class="download-progress"><i style="width:' + pct + '%"></i></div>' : '';
      return '<article class="download-card"><div class="download-file-icon">' + esc(fileIcon) + '</div><div class="download-main"><div class="download-name">' + esc(item.name || item.fileName || hostOf(item.url)) + '</div><div class="download-meta">' + esc(statusText) + (item.isPrivate ? ' · ' + esc(t('privateDownload')) : '') + ' · ' + esc(total ? humanSize(down) + (item.status === 'completed' ? '' : ' / ' + humanSize(total)) : humanSize(down)) + (item.speedBps > 0 ? ' · ' + esc(humanSize(item.speedBps) + '/s') : '') + '</div>' + progress + '</div><div class="download-actions">' +
        (item.status === 'completed' ? '<button data-action="open-download" data-id="' + esc(item.id) + '" aria-label="Open">' + svg('eye', 15) + '</button><button data-action="share-download" data-id="' + esc(item.id) + '" aria-label="Share">' + svg('share', 15) + '</button>' : item.status === 'failed' || item.status === 'canceled' ? '<button data-action="retry-download" data-id="' + esc(item.id) + '" aria-label="Retry">' + svg('reload', 15) + '</button>' : '') +
        (['downloading', 'pending', 'paused'].includes(item.status) ? '<button data-action="cancel-download" data-id="' + esc(item.id) + '" data-native-id="' + esc(nativeId) + '" aria-label="Cancel">' + svg('close', 15) + '</button>' : '') + '<button data-action="delete-download" data-id="' + esc(item.id) + '" aria-label="Delete">' + svg('trash', 14) + '</button></div></article>';
    }).join('');
  }

  function renderExtensions() {
    const catalog = window.NEXA_EXTENSIONS_CATALOG || [];
    const cats = [
      ['all', isAr() ? 'الكل' : 'All'], ['privacy', isAr() ? 'الخصوصية' : 'Privacy'],
      ['appearance', isAr() ? 'المظهر' : 'Appearance'], ['productivity', isAr() ? 'الإنتاجية' : 'Productivity'],
      ['video', isAr() ? 'الفيديو' : 'Video'], ['developer', isAr() ? 'المطورين' : 'Developer'], ['userscripts', isAr() ? 'Userscripts' : 'Userscripts']
    ];
    const catsNode = $('#extension-categories');
    if (catsNode) catsNode.innerHTML = cats.map(([id, label]) => '<button class="chip-pill ' + (extensionFilter === id ? 'active' : '') + '" data-action="extension-filter" data-filter="' + id + '">' + esc(label) + '</button>').join('');
    const matches = catalog.filter(item => {
      const q = extensionSearch.toLowerCase();
      const textMatch = !q || [item.name, item.nameAr, item.descAr, item.descEn, item.category].join(' ').toLowerCase().includes(q);
      const catMatch = extensionFilter === 'all' || item.category === extensionFilter;
      return textMatch && catMatch;
    });
    const featured = matches.filter(item => item.featured);
    const featuredWrap = $('#extension-featured-wrap');
    featuredWrap.style.display = extensionSearch || extensionFilter !== 'all' ? 'none' : '';
    $('#extension-featured').innerHTML = featured.map(renderExtensionCard).join('');
    const popular = extensionSearch || extensionFilter !== 'all' ? matches : matches.filter(item => !item.featured);
    $('#extension-list-heading').textContent = extensionSearch ? (isAr() ? 'نتائج البحث' : 'Search Results') : (extensionFilter === 'all' ? t('extPopular') : cats.find(c => c[0] === extensionFilter)[1]);
    $('#extension-list').innerHTML = popular.length ? popular.map(renderExtensionCard).join('') : '<div class="empty-state"><strong>' + esc(isAr() ? 'لا توجد إضافات مطابقة' : 'No matching extensions') + '</strong><p>' + esc(isAr() ? 'جرّب كلمة بحث أو فئة أخرى.' : 'Try a different search or category.') + '</p></div>';
    $('#extension-search').value = extensionSearch;
  }

  function renderExtensionCard(item) {
    const status = (store.state.installedExtensions || {})[item.id] || {};
    const installed = !!status.installed;
    const enabled = installed && status.enabled !== false;
    const name = isAr() ? item.nameAr : item.name;
    const desc = isAr() ? item.descAr : item.descEn;
    const controls = item.requiresProvider ? '<button class="btn-neon provider-needed" data-action="extension-detail" data-id="' + esc(item.id) + '">' + esc(isAr() ? 'مزود مطلوب' : 'Provider needed') + '</button>' : (installed ? '<div class="ext-toggle-row"><button class="nexa-switch ' + (enabled ? 'on' : '') + '" data-action="toggle-extension" data-id="' + esc(item.id) + '" aria-label="Enable extension"></button></div>' : '<button class="btn-neon" data-action="install-extension" data-id="' + esc(item.id) + '">' + esc(t('extInstall')) + '</button>');
    return '<article class="ext-card"><button class="ext-icon-wrap ext-open" style="background:' + esc(item.gradient) + '" data-action="extension-detail" data-id="' + esc(item.id) + '" aria-label="' + esc(name) + '">' + esc(item.icon) + '</button><button class="ext-info ext-open" data-action="extension-detail" data-id="' + esc(item.id) + '"><span class="ext-name-row"><span class="ext-name">' + esc(name) + '</span>' + (item.featured ? '<span class="ext-badge">' + esc(isAr() ? 'مميز' : 'FEATURED') + '</span>' : '') + '</span><span class="ext-desc">' + esc(desc) + '</span><span class="ext-meta"><span>' + esc(isAr() ? 'إضافة محلية' : 'Local add-on') + '</span><span>v' + esc(item.version) + '</span><span>' + esc(item.size) + '</span></span></button>' + controls + '</article>';
  }

  function extensionById(id) { return (window.NEXA_EXTENSIONS_CATALOG || []).find(item => item.id === id); }

  function extensionDetail(id) {
    const item = extensionById(id);
    if (!item) return;
    const name = isAr() ? item.nameAr : item.name;
    const desc = isAr() ? item.descAr : item.descEn;
    const status = (store.state.installedExtensions || {})[id] || {};
    const action = item.requiresProvider ? '<button class="ghost-action" disabled>' + esc(isAr() ? 'مزود مطلوب' : 'Provider needed') + '</button>' : (status.installed ? '<button class="ghost-action" data-action="uninstall-extension" data-id="' + esc(id) + '">' + esc(t('extUninstall')) + '</button>' : '<button class="primary-action" data-action="install-extension" data-id="' + esc(id) + '">' + esc(t('extInstall')) + '</button>');
    const permissions = (item.permissions || []).map(p => '<li>' + esc(p) + '</li>').join('');
    showSheet('<div class="detail-extension-head"><div class="ext-icon-wrap" style="background:' + esc(item.gradient) + '">' + esc(item.icon) + '</div><div><h2>' + esc(name) + '</h2><div class="ext-meta">' + esc(isAr() ? 'إضافة محلية' : 'Local add-on') + ' · v' + esc(item.version) + ' · ' + esc(item.size) + '</div></div></div><p class="sheet-subtitle">' + esc(desc) + '</p><h3 class="sheet-subheading">' + esc(t('extPermissions')) + '</h3><ul class="permission-list">' + permissions + '</ul><p class="permission-note">' + esc(isAr() ? 'هذه إضافة مدمجة في NexaBrowser وتعمل عبر Content Script محدود في WebView. دعم حزم Chromium WebExtensions الخارجية (CRX) غير متاح على Android WebView.' : 'This is a built-in NexaBrowser content script. Arbitrary Chromium CRX packages are not supported by Android WebView.') + '</p><div class="sheet-form-actions" style="margin-top:15px">' + action + '<button class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button></div>');
  }

  function installExtension(id) {
    const item = extensionById(id);
    if (!item) return;
    if (item.id === 'ext-ai-translator') {
      toast(isAr() ? 'الترجمة تحتاج إلى مزود خارجي غير مُهيأ' : 'Translation requires a provider that is not configured');
      return;
    }
    store.state.installedExtensions[id] = { installed: true, enabled: true, installedAt: Date.now() };
    nativeCall('setExtensionEnabled', id, true);
    store.logDev('ext', 'Installed ' + item.name + ' content script');
    persist();
    renderExtensions();
    closeSheet();
    toast((isAr() ? 'تم تثبيت ' : 'Installed ') + (isAr() ? item.nameAr : item.name));
    haptic('light');
  }

  function toggleExtension(id) {
    const status = store.state.installedExtensions[id];
    if (!status || !status.installed) return;
    status.enabled = !status.enabled;
    nativeCall('setExtensionEnabled', id, status.enabled);
    persist();
    renderExtensions();
    toast(status.enabled ? (isAr() ? 'الإضافة مفعلة' : 'Extension enabled') : (isAr() ? 'الإضافة متوقفة' : 'Extension disabled'));
  }

  function uninstallExtension(id) {
    delete store.state.installedExtensions[id];
    nativeCall('setExtensionEnabled', id, false);
    persist();
    closeSheet();
    renderExtensions();
    toast(isAr() ? 'تمت إزالة الإضافة' : 'Extension uninstalled');
  }

  function renderPrivacy() {
    const privacy = store.state.privacy;
    $$('[data-action="toggle-privacy"]').forEach(btn => btn.classList.toggle('on', !!privacy[btn.dataset.key]));
    $$('[data-action="toggle-setting"]').forEach(btn => btn.classList.toggle('on', !!store.state.settings[btn.dataset.key]));
    const list = $('#whitelist-list');
    if (list) list.innerHTML = (privacy.whitelist || []).length ? privacy.whitelist.map(domain => '<span class="chip-pill whitelist-chip">' + esc(domain) + '<button data-action="remove-whitelist" data-domain="' + esc(domain) + '" aria-label="Remove">×</button></span>').join('') : '<span class="empty-inline">' + esc(isAr() ? 'لا توجد مواقع مستثناة' : 'No sites in the allowlist') + '</span>';
    renderPrivacyStats();
  }

  function togglePrivacy(key) {
    store.state.privacy[key] = !store.state.privacy[key];
    if (key === 'adBlockEnabled') nativeCall('setAdBlockEnabled', store.state.privacy[key]);
    if (key === 'trackerBlockEnabled') nativeCall('setTrackerBlockEnabled', store.state.privacy[key]);
    if (key === 'safeBrowsingEnabled') nativeCall('setSafeBrowsingEnabled', store.state.privacy[key]);
    persist();
    renderPrivacy();
    toast(isAr() ? 'تم تحديث إعداد الخصوصية' : 'Privacy setting updated');
  }

  function renderVpn() {
    const list = $('#vpn-servers-list');
    const servers = (store.state.vpn && store.state.vpn.servers) || [];
    list.innerHTML = servers.map(server => '<button class="server-card ' + (server.id === store.state.vpn.selectedServer ? 'selected' : '') + '" data-action="select-vpn-server" data-id="' + esc(server.id) + '"><span class="server-flag">' + esc(server.flag) + '</span><span class="server-copy"><strong>' + esc(isAr() ? server.countryAr : server.countryEn) + '</strong><small>' + esc(server.ping) + ' · ' + esc(isAr() ? 'موقع مفضل فقط' : 'preference only') + '</small></span><span class="server-ping">' + (server.id === store.state.vpn.selectedServer ? svg('check', 16) : '') + '</span></button>').join('');
    $('#vpn-power').classList.remove('connected');
    $('#vpn-power').innerHTML = svg('power', 36) + '<strong>' + esc(t('vpnUnavailable')) + '</strong><small>' + esc(t('vpnTapDetails')) + '</small>';
    $('#vpn-status-caption').textContent = isAr() ? 'لا يوجد نفق VPN فعّال — لم يُهيأ مزود' : 'No active VPN tunnel — provider not configured';
  }

  function showVpnNotice() {
    const nativeStatus = nativeCall('getVpnArchitectureStatus');
    let detail = '';
    if (nativeStatus) {
      try { detail = JSON.parse(nativeStatus).modeDescription || ''; } catch (_) { }
    }
    showSheet('<h2>' + esc(isAr() ? 'حالة VPN بشفافية' : 'VPN status, transparently') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'خدمة Android VpnService موجودة كهيكل قابل للتوسعة فقط. لا يوجد خادم نفق أو WireGuard مدمج؛ لذلك لا يتم إنشاء اتصال أو تغيير عنوان IP.' : 'Android VpnService is an extension point only. No tunnel backend or WireGuard profile is bundled, so no VPN connection is made and your IP is not changed.') + '</p><div class="sheet-note">' + esc(detail || (isAr() ? 'البنية: جاهزة للربط بخدمة VPN حقيقية لاحقًا.' : 'Architecture: ready for a real VPN provider integration.')) + '</div><div class="sheet-form-actions"><button class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button><button class="primary-action" data-action="configure-vpn">' + esc(t('configure')) + '</button></div>');
  }

  function renderLibrary() {
    const tabs = $$('.library-segments .segment');
    tabs.forEach(btn => btn.classList.toggle('active', btn.dataset.tab === libraryTab));
    const folderWrap = $('#bookmark-folders');
    if (libraryTab === 'bookmarks') {
      const folders = ['الكل'].concat(store.state.bookmarksFolders || []);
      folderWrap.innerHTML = folders.map(folder => '<button class="chip-pill ' + (bookmarkFolder === folder ? 'active' : '') + '" data-action="bookmark-folder" data-folder="' + esc(folder) + '">' + esc(folder) + '</button>').join('');
      const entries = (store.state.bookmarks || []).filter(item => bookmarkFolder === 'الكل' || item.folder === bookmarkFolder);
      renderLibraryEntries(entries, 'bookmark');
    } else {
      folderWrap.innerHTML = '';
      let entries = [];
      if (libraryTab === 'history') entries = store.state.history || [];
      if (libraryTab === 'closed') entries = (store.state.recentlyClosedTabs || []).filter(item => !item.isPrivate);
      renderLibraryEntries(entries, libraryTab === 'history' ? 'history' : 'closed');
    }
  }

  function renderLibraryEntries(entries, type) {
    const list = $('#library-list');
    if (!entries.length) {
      list.innerHTML = '<div class="empty-state"><div class="empty-icon">' + svg(type === 'bookmark' ? 'bookmark' : 'history', 27) + '</div><strong>' + esc(type === 'bookmark' ? (isAr() ? 'لا توجد إشارات مرجعية بعد' : 'No bookmarks yet') : (isAr() ? 'القائمة فارغة' : 'Nothing here yet')) + '</strong><p>' + esc(isAr() ? 'احفظ صفحاتك من شريط المتصفح لتظهر هنا.' : 'Save pages from the browser toolbar to see them here.') + '</p></div>';
      return;
    }
    list.innerHTML = entries.map(item => {
      let actions = '';
      if (type === 'bookmark') actions = '<button data-action="toggle-favorite" data-id="' + esc(item.id) + '" aria-label="Favorite">' + svg('star', 15) + '</button><button data-action="delete-bookmark" data-id="' + esc(item.id) + '" aria-label="Delete">' + svg('trash', 15) + '</button>';
      else if (type === 'history') actions = '<button data-action="delete-history" data-id="' + esc(item.id) + '" aria-label="Delete">' + svg('close', 15) + '</button>';
      else actions = '<button data-action="restore-closed" data-id="' + esc(item.id) + '" aria-label="Restore">' + svg('reload', 15) + '</button>';
      const isHistory = type === 'history';
      return '<article class="library-entry"><span class="library-entry-icon">' + svg(type === 'bookmark' ? (item.favorite ? 'star' : 'bookmark') : type === 'history' ? (item.type === 'search' ? 'search' : 'history') : 'tabs', 15) + '</span><button class="library-entry-main" data-action="open-url" data-url="' + esc(item.url) + '"><span class="library-entry-title">' + esc(item.title || hostOf(item.url)) + '</span><span class="library-entry-url">' + esc(hostOf(item.url)) + '</span><span class="library-entry-meta">' + esc(item.folder || (isHistory ? item.time || '' : item.closedAt || '')) + '</span></button><span class="library-entry-actions">' + actions + '</span></article>';
    }).join('');
  }

  function saveCurrentBookmark() {
    const active = ensureTab();
    if (!active.url || active.url.startsWith('nexa://')) {
      toast(isAr() ? 'افتح صفحة ويب أولًا لحفظها' : 'Open a web page to bookmark it');
      return;
    }
    const existing = store.state.bookmarks.find(item => item.url === active.url);
    if (existing) {
      toast(isAr() ? 'هذه الصفحة محفوظة بالفعل' : 'This page is already bookmarked');
      return;
    }
    showSheet('<h2>' + esc(isAr() ? 'حفظ إشارة مرجعية' : 'Save bookmark') + '</h2><form id="bookmark-form" class="sheet-form"><label>' + esc(isAr() ? 'اسم الصفحة' : 'Page title') + '<input name="title" value="' + esc(active.title || hostOf(active.url)) + '" required></label><label>' + esc(isAr() ? 'المجلد' : 'Folder') + '<select name="folder">' + (store.state.bookmarksFolders || []).map(folder => '<option value="' + esc(folder) + '">' + esc(folder) + '</option>').join('') + '<option value="__new__">' + esc(isAr() ? '+ مجلد جديد' : '+ New folder') + '</option></select></label><label class="toggle-row"><input type="checkbox" name="favorite"> ' + esc(isAr() ? 'إضافة إلى المفضلة' : 'Add to Favorites') + '</label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button type="submit" class="primary-action">' + esc(isAr() ? 'حفظ' : 'Save') + '</button></div></form>');
    $('#bookmark-form').dataset.url = active.url;
  }

  function saveBookmarkForm(form) {
    const data = new FormData(form);
    let folder = String(data.get('folder') || 'الكل');
    if (folder === '__new__') {
      folder = prompt(isAr() ? 'اسم المجلد الجديد' : 'New folder name', isAr() ? 'مجلد جديد' : 'New folder');
      if (!folder) return;
      if (!store.state.bookmarksFolders.includes(folder)) store.state.bookmarksFolders.push(folder);
    }
    store.state.bookmarks.unshift({ id: 'bm-' + Date.now(), title: String(data.get('title') || ''), url: form.dataset.url, folder, favorite: data.has('favorite'), createdAt: nowIso() });
    persist(); closeSheet(); renderHome(); renderLibrary();
    toast(isAr() ? 'تم حفظ الإشارة المرجعية' : 'Bookmark saved');
    haptic('light');
  }

  function exportBookmarks() {
    const payload = JSON.stringify({ version: 1, exportedAt: nowIso(), folders: store.state.bookmarksFolders, bookmarks: store.state.bookmarks }, null, 2);
    downloadBlob(payload, 'nexabrowser-bookmarks.json', 'application/json');
    toast(isAr() ? 'تم تجهيز ملف التصدير' : 'Bookmark export prepared');
  }

  function downloadBlob(text, fileName, mime) {
    if (window.NexaNative && typeof window.NexaNative.exportTextFile === 'function') {
      const savedUri = nativeCall('exportTextFile', fileName, mime || 'text/plain', text);
      if (savedUri) {
        toast(isAr() ? 'حُفظ ملف الإشارات على هذا الجهاز' : 'Bookmark file saved on this device');
        return;
      }
    }
    try {
      const blob = new Blob([text], { type: mime || 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a'); a.href = url; a.download = fileName; a.style.display = 'none';
      document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 4000);
    } catch (_) { toast(isAr() ? 'تعذر إنشاء الملف' : 'Could not create the file'); }
  }

  function importBookmarksFile(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = JSON.parse(String(reader.result || '{}'));
        const imported = Array.isArray(parsed) ? parsed : parsed.bookmarks;
        if (!Array.isArray(imported)) throw new Error('Invalid bookmark file');
        const seen = new Set(store.state.bookmarks.map(item => item.url));
        let added = 0;
        imported.forEach(item => {
          if (item && /^https?:\/\//i.test(item.url || '') && !seen.has(item.url)) {
            store.state.bookmarks.push({ id: 'bm-' + Date.now() + '-' + added, title: String(item.title || hostOf(item.url)), url: item.url, folder: String(item.folder || 'Imported'), favorite: !!item.favorite });
            seen.add(item.url); added++;
          }
        });
        persist(); renderLibrary(); renderHome();
        toast(isAr() ? ('تم استيراد ' + added + ' إشارة') : ('Imported ' + added + ' bookmarks'));
      } catch (_) { toast(isAr() ? 'ملف الإشارات غير صالح' : 'Invalid bookmark file'); }
    };
    reader.readAsText(file);
  }

  function renderPasswords() {
    const locked = !store.vaultUnlocked;
    $('#vault-locked-panel').hidden = !locked;
    $('#vault-open-panel').hidden = locked;
    if (locked) return;
    const list = $('#credentials-list');
    const creds = store.vault || [];
    list.innerHTML = creds.length ? creds.map(item => '<article class="credential-card"><span class="library-entry-icon">' + svg('key', 15) + '</span><div class="credential-main"><div class="credential-site">' + esc(item.site) + '</div><div class="credential-user">' + esc(item.username) + '</div></div><div class="credential-actions"><button data-action="fill-credential" data-id="' + esc(item.id) + '" title="' + esc(isAr() ? 'تعبئة في الصفحة الحالية' : 'Fill current page') + '">' + svg('upload', 15) + '</button><button data-action="delete-credential" data-id="' + esc(item.id) + '">' + svg('trash', 15) + '</button></div></article>').join('') : '<div class="empty-state"><div class="empty-icon">' + svg('key', 26) + '</div><strong>' + esc(isAr() ? 'الخزنة فارغة' : 'Your vault is empty') + '</strong><p>' + esc(isAr() ? 'أضف بيانات الدخول يدويًا. لن تُقرأ أو تُحفظ كلمات مرور المواقع تلقائيًا.' : 'Add a login manually. Site passwords are never read or saved automatically.') + '</p></div>';
  }

  function unlockVault() {
    const pinConfigured = nativeCall('hasVaultPinConfigured');
    const setupMode = !pinConfigured;
    showSheet('<h2>' + esc(setupMode ? (isAr() ? 'إنشاء رمز للخزنة' : 'Create a vault PIN') : (isAr() ? 'فتح خزنة كلمات المرور' : 'Unlock password vault')) + '</h2><p class="sheet-subtitle">' + esc(setupMode ? (isAr() ? 'اختر رمزًا من 6 أحرف أو أكثر. يتم تخزين مشتقه فقط.' : 'Choose at least 6 characters. Only a derived hash is stored.') : (isAr() ? 'أدخل رمز PIN الذي اخترته.' : 'Enter your vault PIN.')) + '</p><form id="vault-pin-form" class="sheet-form"><label>' + esc(isAr() ? 'رمز PIN' : 'PIN') + '<input name="pin" type="password" inputmode="numeric" minlength="6" autocomplete="current-password" required></label>' + (setupMode ? '<label>' + esc(isAr() ? 'تأكيد الرمز' : 'Confirm PIN') + '<input name="confirm" type="password" inputmode="numeric" minlength="6" required></label>' : '') + '<div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button type="submit" class="primary-action">' + esc(setupMode ? (isAr() ? 'إنشاء وفتح' : 'Create & unlock') : (isAr() ? 'فتح' : 'Unlock')) + '</button></div></form>');
    $('#vault-pin-form').dataset.setup = setupMode ? '1' : '0';
  }

  function handleVaultPinForm(form) {
    const data = new FormData(form);
    const pin = String(data.get('pin') || '');
    if (form.dataset.setup === '1') {
      if (pin.length < 6 || pin !== String(data.get('confirm') || '')) {
        toast(isAr() ? 'تأكد من تطابق الرمز وأن يتكون من 6 أحرف على الأقل' : 'PINs must match and contain at least 6 characters'); return;
      }
      if (!nativeCall('setVaultPin', pin)) { toast(isAr() ? 'تعذر إنشاء PIN في Android KeyStore' : 'Could not create a PIN with Android Keystore'); return; }
    } else if (!nativeCall('verifyVaultPin', pin)) {
      toast(isAr() ? 'رمز PIN غير صحيح' : 'Incorrect PIN'); return;
    }
    store.vaultUnlocked = true;
    closeSheet();
    const decrypted = nativeCall('loadDecryptedVault');
    if (decrypted) {
      try { store.vault = JSON.parse(decrypted); } catch (_) { store.vault = []; }
    } else if (!window.NexaNative) {
      toast(isAr() ? 'الخزنة المشفرة تتطلب تطبيق Android الأصلي' : 'Encrypted vault requires the Android app');
    }
    renderPasswords();
    toast(isAr() ? 'تم فتح الخزنة محليًا' : 'Vault unlocked on this device');
  }

  function addCredential() {
    showSheet('<h2>' + esc(isAr() ? 'إضافة بيانات دخول' : 'Add login') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'تأكد من اختيار الموقع الصحيح. خزنتك مشفرة محليًا.' : 'Verify the site before saving. Your vault is encrypted on-device.') + '</p><form id="credential-form" class="sheet-form"><label>' + esc(isAr() ? 'الموقع / النطاق' : 'Website / domain') + '<input name="site" placeholder="example.com" autocomplete="url" required></label><label>' + esc(isAr() ? 'اسم المستخدم أو البريد' : 'Username or email') + '<input name="username" autocomplete="username" required></label><label>' + esc(isAr() ? 'كلمة المرور' : 'Password') + '<input name="password" type="password" autocomplete="new-password" required></label><label>' + esc(isAr() ? 'ملاحظة (اختياري)' : 'Note (optional)') + '<input name="notes"></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button type="submit" class="primary-action">' + esc(isAr() ? 'حفظ مشفر' : 'Save encrypted') + '</button></div></form>');
  }

  function saveCredentialForm(form) {
    const data = new FormData(form);
    store.vault.unshift({ id: 'cred-' + Date.now(), site: String(data.get('site')).trim(), username: String(data.get('username')).trim(), password: String(data.get('password')), notes: String(data.get('notes') || '') });
    const ok = nativeCall('saveEncryptedVault', JSON.stringify(store.vault));
    if (ok === false) { store.vault.shift(); toast(isAr() ? 'تعذر حفظ الخزنة المشفرة' : 'Could not save encrypted vault'); return; }
    closeSheet(); renderPasswords();
    toast(isAr() ? 'تم حفظ بيانات الدخول مشفرة على الجهاز' : 'Login saved encrypted on this device');
  }

  function deleteCredential(id) {
    const before = store.vault.length;
    store.vault = store.vault.filter(item => item.id !== id);
    if (store.vault.length !== before) nativeCall('saveEncryptedVault', JSON.stringify(store.vault));
    renderPasswords();
  }

  function fillCredential(id) {
    const cred = store.vault.find(item => item.id === id);
    if (!cred) return;
    const active = ensureTab();
    if (!active.url || active.url.startsWith('nexa://')) { toast(isAr() ? 'افتح صفحة تسجيل الدخول أولًا' : 'Open a login page first'); return; }
    showSheet('<h2>' + esc(isAr() ? 'تعبئة يدويّة بعد التأكيد' : 'Confirm login fill') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'سيتم إدخال بيانات ' + cred.site + ' في حقول صفحة التبويب الحالي. تحقق من النطاق قبل المتابعة.' : 'Fill credentials for ' + cred.site + ' into the current page. Check the domain before continuing.') + '</p><div class="sheet-note">' + esc(hostOf(active.url)) + '</div><div class="sheet-form-actions"><button class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" data-action="confirm-fill-credential" data-id="' + esc(id) + '">' + esc(isAr() ? 'تعبئة الآن' : 'Fill now') + '</button></div>');
  }

  function confirmFillCredential(id) {
    const cred = store.vault.find(item => item.id === id);
    if (!cred) return;
    nativeCall('fillCredentialOnActiveWebView', cred.username, cred.password);
    closeSheet();
    toast(isAr() ? 'أُرسلت البيانات إلى حقول الصفحة الحالية' : 'Credentials filled into the current page');
  }

  function renderReader(article) {
    if (article) readerArticle = article;
    const surface = $('#reader-article');
    const source = readerArticle || store.state.reader.currentArticle;
    const theme = store.state.reader.theme || 'dark';
    surface.dataset.theme = theme;
    surface.style.fontSize = (store.state.reader.fontSize || 18) + 'px';
    surface.style.fontFamily = store.state.reader.fontFamily || 'system-ui';
    $('#reader-font-size').textContent = (store.state.reader.fontSize || 18) + ' px';
    $('#reader-font-family').value = store.state.reader.fontFamily || 'system-ui';
    $$('.reader-theme-dot').forEach(btn => btn.classList.toggle('active', btn.dataset.theme === theme));
    if (source && source.blocks && source.blocks.length) {
      $('#reader-origin').textContent = source.site || hostOf(source.url || '') || (isAr() ? 'مقال محفوظ محليًا' : 'Saved article');
      surface.innerHTML = '<h2>' + esc(source.title || '') + '</h2><div class="reader-meta">' + esc(source.site || '') + (source.url ? ' · ' + esc(hostOf(source.url)) : '') + '</div>' + source.blocks.map(block => '<p>' + esc(typeof block === 'string' ? block : block.text || '') + '</p>').join('');
    } else {
      $('#reader-origin').textContent = t('readerOrigin');
      surface.innerHTML = '<div class="empty-state"><div class="empty-icon">' + svg('text', 27) + '</div><strong>' + esc(isAr() ? 'لا يوجد مقال للاستخراج' : 'No article to extract') + '</strong><p>' + esc(isAr() ? 'افتح صفحة ويب ثم من القائمة اختر «وضع القراءة».' : 'Open a webpage and choose Reading Mode from the menu.') + '</p><button class="btn-neon" data-action="extract-reader">' + esc(isAr() ? 'استخراج من الصفحة الحالية' : 'Extract current page') + '</button></div>';
    }
    renderSavedArticles();
  }

  function renderSavedArticles() {
    const target = $('#saved-articles-list');
    const items = (store.state.reader.savedArticles || []);
    target.innerHTML = items.length ? items.map((item, idx) => '<article class="saved-article-row"><span class="library-entry-icon">' + svg('bookmark', 14) + '</span><div><strong>' + esc(item.title) + '</strong><small>' + esc(item.site || '') + '</small></div><button class="tiny-ctrl-btn" data-action="open-saved-article" data-index="' + idx + '">' + esc(isAr() ? 'فتح' : 'Open') + '</button><button class="tiny-ctrl-btn danger" data-action="delete-saved-article" data-index="' + idx + '">×</button></article>').join('') : '<div class="empty-inline">' + esc(isAr() ? 'لا توجد مقالات محفوظة.' : 'No saved articles yet.') + '</div>';
  }

  function extractReader() {
    if (!window.NexaNative) { toast(isAr() ? 'يتطلب وضع القراءة صفحة ويب داخل تطبيق Android' : 'Reading mode requires a page in the Android app'); return; }
    nativeCall('requestReaderArticle');
    toast(isAr() ? 'جارٍ استخراج نص المقال…' : 'Extracting article text…');
  }

  function saveReaderArticle() {
    const article = readerArticle;
    if (!article || !article.blocks || !article.blocks.length) { toast(isAr() ? 'استخرج مقالًا أولًا' : 'Extract an article first'); return; }
    const clone = JSON.parse(JSON.stringify(article));
    clone.id = 'article-' + Date.now();
    clone.savedAt = nowIso();
    const exists = store.state.reader.savedArticles.some(item => item.url && item.url === clone.url);
    if (!exists) store.state.reader.savedArticles.unshift(clone);
    persist(); renderSavedArticles();
    toast(isAr() ? 'حُفظ المقال محليًا للقراءة دون اتصال' : 'Article saved locally for offline reading');
  }

  function renderSync() {
    $$('[data-action="toggle-sync"]').forEach(btn => btn.classList.toggle('on', !!store.state.sync[btn.dataset.key]));
  }

  function renderSettings() {
    $('#settings-engine-name').textContent = engineName(store.state.searchEngine);
    $('#homepage-setting-value').textContent = store.state.settings.homepage === 'nexa://home' ? (isAr() ? 'الصفحة الرئيسية NexaBrowser' : 'NexaBrowser Home') : store.state.settings.homepage;
    $('#language-setting-name').textContent = store.state.lang === 'ar' ? 'العربية · English' : 'English · العربية';
    $('#font-size-setting-value').textContent = store.state.settings.fontSizeScale + '%';
    $$('[data-action="toggle-setting"]').forEach(btn => btn.classList.toggle('on', !!store.state.settings[btn.dataset.key]));
    const jsBtn = $('[data-action="toggle-javascript"]');
    if (jsBtn) jsBtn.classList.toggle('on', store.state.settings.javascriptEnabled !== false);
  }

  function engineShortName(id) {
    const custom = (store.state.customSearchEngines || []).find(e => e.id === id);
    return ({ google: 'G', bing: 'b', duckduckgo: 'D', brave: 'B' })[id] || (custom && custom.name ? custom.name.slice(0, 1) : 'G');
  }

  function engineName(id) {
    const known = { google: 'Google', bing: 'Microsoft Bing', duckduckgo: 'DuckDuckGo', brave: 'Brave Search' };
    return known[id] || ((store.state.customSearchEngines || []).find(e => e.id === id) || {}).name || 'Google';
  }

  function showSheet(html) {
    const backdrop = $('#sheet-backdrop');
    $('#sheet-content').innerHTML = html;
    hydrateIcons($('#sheet-content'));
    backdrop.classList.add('open');
    backdrop.setAttribute('aria-hidden', 'false');
    const focusable = $('#sheet-content input, #sheet-content textarea, #sheet-content select');
    if (focusable) setTimeout(() => focusable.focus(), 120);
  }

  function closeSheet() {
    const backdrop = $('#sheet-backdrop');
    backdrop.classList.remove('open');
    backdrop.setAttribute('aria-hidden', 'true');
  }

  function openMenu() {
    const tiles = [
      ['new-tab', 'plus', isAr() ? 'تبويب جديد' : 'New Tab'],
      ['new-private-tab', 'incognito', isAr() ? 'تبويب خاص' : 'Private Tab'],
      ['navigate', 'bookmark', t('bookmarksTitle'), 'bookmarks'],
      ['navigate', 'history', isAr() ? 'السجل' : 'History', 'bookmarks'],
      ['navigate', 'download', t('downloadsTitle'), 'downloads'],
      ['navigate', 'puzzle', t('extensionsTitle'), 'extensions'],
      ['navigate', 'key', isAr() ? 'كلمات المرور' : 'Passwords', 'passwords'],
      ['navigate', 'shield-check', t('privacyTitle'), 'privacy'],
      ['navigate', 'settings', t('settingsTitle'), 'settings'],
      ['browser-tools', 'sparkles', isAr() ? 'أدوات الصفحة' : 'Page Tools'],
      ['navigate', 'globe', t('vpnTitle'), 'vpn'],
      ['navigate', 'sync', t('syncTitle'), 'sync']
    ];
    const tileHtml = tiles.map(([action, iconName, label, screen]) => '<button data-action="' + action + '" ' + (screen ? 'data-screen="' + screen + '"' : '') + '><span data-icon="' + iconName + '"></span><span>' + esc(label) + '</span></button>').join('');
    showSheet('<h2>' + esc(isAr() ? 'قائمة NexaBrowser' : 'NexaBrowser Menu') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'أدواتك المهمة في مكان واحد' : 'Your browser tools, all in one place') + '</p><div class="menu-sheet-primary">' + tileHtml + '</div><button class="sheet-menu-row" data-action="browser-tools"><span data-icon="sparkles"></span>' + esc(t('toolsTitle')) + '</button><button class="sheet-menu-row" data-action="translate-page"><span data-icon="translate"></span>' + esc(isAr() ? 'ترجمة الصفحة' : 'Translate page') + '<span class="read-only-tag">' + esc(isAr() ? 'مزود مطلوب' : 'provider needed') + '</span></button><button class="sheet-menu-row" data-action="navigate" data-screen="reader"><span data-icon="text"></span>' + esc(t('readerTitle')) + '</button><button class="sheet-menu-row" data-action="about"><span data-icon="info"></span>' + esc(isAr() ? 'حول NexaBrowser' : 'About NexaBrowser') + '</button>');
  }

  function openBrowserTools() {
    const current = ensureTab();
    const hasPage = current.url && !current.url.startsWith('nexa://');
    showSheet('<h2>' + esc(t('toolsTitle')) + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'تعمل الأدوات على الصفحة المفتوحة عند دعمها.' : 'Tools operate on the current page when supported.') + '</p><div class="menu-grid tools-menu-grid"><button class="menu-tile" data-action="qr-scan"><span data-icon="qr"></span>QR Scanner</button><button class="menu-tile" data-action="screenshot"><span data-icon="camera"></span>' + esc(isAr() ? 'لقطة شاشة' : 'Screenshot') + '</button><button class="menu-tile" data-action="reader-tool"><span data-icon="text"></span>' + esc(isAr() ? 'وضع القراءة' : 'Reader Mode') + '</button><button class="menu-tile" data-action="share-page"><span data-icon="share"></span>' + esc(isAr() ? 'مشاركة' : 'Share') + '</button><button class="menu-tile" data-action="find-page"><span data-icon="search"></span>' + esc(isAr() ? 'بحث في الصفحة' : 'Find in Page') + '</button><button class="menu-tile" data-action="desktop-site"><span data-icon="desktop"></span>' + esc(isAr() ? 'موقع سطح المكتب' : 'Desktop Site') + '</button><button class="menu-tile" data-action="zoom-page"><span data-icon="text"></span>' + esc(isAr() ? 'تكبير وتصغير' : 'Zoom') + '</button><button class="menu-tile" data-action="copy-link"><span data-icon="copy"></span>' + esc(isAr() ? 'نسخ الرابط' : 'Copy Link') + '</button><button class="menu-tile" data-action="external-page"><span data-icon="external"></span>' + esc(isAr() ? 'فتح خارجيًا' : 'Open externally') + '</button><button class="menu-tile" data-action="developer-tools"><span data-icon="code"></span>' + esc(isAr() ? 'أدوات المطور' : 'Developer Tools') + '</button></div>' + (!hasPage ? '<div class="sheet-note">' + esc(isAr() ? 'افتح صفحة ويب لاستخدام أدوات الصفحة.' : 'Open a webpage to use page-specific tools.') + '</div>' : ''));
  }

  function wallpaperSheet() {
    const wallpapers = [
      ['cyber-neon', 'Cyber Neon', 'linear-gradient(135deg,#00e5ff,#8b5cf6)'],
      ['aurora-matrix', 'Aurora Matrix', 'linear-gradient(135deg,#10b981,#00e5ff)'],
      ['deep-cosmos', 'Deep Cosmos', 'linear-gradient(135deg,#ec4899,#8b5cf6)'],
      ['midnight-obsidian', 'Midnight Obsidian', 'linear-gradient(135deg,#334155,#0f172a)'],
      ['synthwave-violet', 'Synthwave Violet', 'linear-gradient(135deg,#ec4899,#7c3aed)']
    ];
    showSheet('<h2>' + esc(isAr() ? 'اختر خلفيتك' : 'Choose your wallpaper') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'تتغير خلفية الصفحة الرئيسية فقط.' : 'Changes the home background only.') + '</p><div class="wallpaper-grid">' + wallpapers.map(([id, name, bg]) => '<button class="wallpaper-option ' + (store.state.wallpaper === id ? 'selected' : '') + '" style="--wall:' + bg + '" data-action="select-wallpaper" data-id="' + id + '"><i></i><span>' + name + '</span>' + (store.state.wallpaper === id ? svg('check', 14) : '') + '</button>').join('') + '</div>');
  }

  function chooseEngineSheet() {
    const engines = [
      ['google', 'Google', 'G'], ['bing', 'Bing', 'b'], ['duckduckgo', 'DuckDuckGo', 'D'], ['brave', 'Brave Search', 'B']
    ];
    let list = engines.map(([id, name, short]) => '<button class="engine-choice ' + (store.state.searchEngine === id ? 'selected' : '') + '" data-action="set-engine" data-id="' + id + '"><span class="engine-logo">' + short + '</span><span><strong>' + name + '</strong><small>' + esc(id === 'duckduckgo' || id === 'brave' ? (isAr() ? 'بديل يركز على الخصوصية' : 'Privacy-focused alternative') : (isAr() ? 'محرك بحث ويب' : 'Web search')) + '</small></span>' + (store.state.searchEngine === id ? svg('check', 16) : '') + '</button>').join('');
    (store.state.customSearchEngines || []).forEach(engine => { list += '<button class="engine-choice" data-action="set-engine" data-id="' + esc(engine.id) + '"><span class="engine-logo">' + esc(firstLetter(engine.name)) + '</span><span><strong>' + esc(engine.name) + '</strong><small>' + esc(engine.urlTemplate) + '</small></span></button>'; });
    showSheet('<h2>' + esc(isAr() ? 'محرك البحث الافتراضي' : 'Default search engine') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'اختر وجهة عمليات البحث من شريط العنوان.' : 'Choose where address-bar searches are sent.') + '</p><div class="engine-choice-list">' + list + '</div><button class="secondary-btn" style="width:100%;margin-top:10px" data-action="add-search-engine">+ ' + esc(isAr() ? 'إضافة محرك مخصص' : 'Add custom search engine') + '</button>');
  }

  function openAddShortcut() {
    showSheet('<h2>' + esc(isAr() ? 'إضافة اختصار' : 'Add shortcut') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'أدخل اسمًا ورابط HTTP أو HTTPS.' : 'Enter a name and an HTTP or HTTPS URL.') + '</p><form id="shortcut-form" class="sheet-form"><label>' + esc(isAr() ? 'الاسم' : 'Name') + '<input name="title" required maxlength="40" placeholder="Example"></label><label>URL<input name="url" type="url" required placeholder="https://example.com"></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" type="submit">' + esc(isAr() ? 'إضافة' : 'Add') + '</button></div></form>');
  }

  function handleShortcutForm(form) {
    const data = new FormData(form);
    let url = String(data.get('url') || '').trim();
    if (!/^https?:\/\//i.test(url)) url = 'https://' + url;
    if (!/^https?:\/\//i.test(url)) { toast(isAr() ? 'أدخل رابطًا صالحًا' : 'Enter a valid URL'); return; }
    const colors = ['linear-gradient(135deg,#00E5FF,#3B82F6)', 'linear-gradient(135deg,#8B5CF6,#EC4899)', 'linear-gradient(135deg,#10B981,#0EA5E9)', 'linear-gradient(135deg,#F59E0B,#EF4444)'];
    store.state.shortcuts.push({ id: 'sc-' + Date.now(), title: String(data.get('title')).trim(), url, icon: firstLetter(data.get('title')), color: colors[store.state.shortcuts.length % colors.length] });
    persist(); closeSheet(); renderHome();
  }

  function openDownloadSheet() {
    showSheet('<h2>' + esc(isAr() ? 'تنزيل رابط مباشر' : 'Download a direct URL') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'سيُرسل الرابط إلى Android DownloadManager ويحفظه في Downloads.' : 'The URL is handed to Android DownloadManager and saved in Downloads.') + '</p><form id="manual-download-form" class="sheet-form"><label>URL<input name="url" type="url" placeholder="https://example.com/file.zip" required></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button type="submit" class="primary-action">' + esc(isAr() ? 'بدء التنزيل' : 'Start download') + '</button></div></form>');
  }

  function startDownload(url, suggestedName, mimeType, privateTab) {
    if (!window.NexaNative) { toast(isAr() ? 'التنزيل الأصلي يتطلب تطبيق Android' : 'Native downloads require the Android app'); return; }
    const isPrivateDownload = privateTab === undefined ? !!ensureTab().isPrivate : !!privateTab;
    const rawId = nativeCall('startNativeDownload', url, suggestedName || '', mimeType || '', !isPrivateDownload);
    if (!rawId || String(rawId) === '-1') { toast(isAr() ? 'تعذر بدء التنزيل. تحقق من الرابط والاتصال.' : 'Could not start download. Check the URL and connection.'); return; }
    const id = 'dm-' + String(rawId);
    const name = suggestedName || safeFileName(url);
    store.state.downloads.unshift({ id, nativeDownloadId: String(rawId), name, fileName: name, url, category: inferCategory(name), status: 'pending', sizeBytes: 0, downloadedBytes: 0, isPrivate: isPrivateDownload, createdAt: nowIso() });
    persist(); renderDownloads(); closeSheet();
    toast(isAr() ? 'بدأ Android DownloadManager التنزيل' : 'Android DownloadManager started');
  }

  function safeFileName(url) {
    try { return decodeURIComponent(new URL(url).pathname.split('/').pop()) || hostOf(url); } catch (_) { return 'download'; }
  }

  function inferCategory(name) {
    const lower = String(name || '').toLowerCase();
    if (/\.(apk|xapk|aab)$/.test(lower)) return 'apk';
    if (/\.(zip|rar|7z|tar|gz)$/.test(lower)) return 'zip';
    if (/\.(png|jpe?g|gif|webp|svg)$/.test(lower)) return 'images';
    if (/\.(mp4|mkv|webm|mov|avi)$/.test(lower)) return 'videos';
    if (/\.(pdf|docx?|xlsx?|pptx?|txt|md)$/.test(lower)) return 'documents';
    if (/\.(mp3|wav|ogg|flac|m4a)$/.test(lower)) return 'audio';
    return 'other';
  }

  function pollDownloads() {
    if (!window.NexaNative) return;
    let changed = false;
    (store.state.downloads || []).forEach(item => {
      if (!item.nativeDownloadId || !['downloading', 'pending', 'paused'].includes(item.status)) return;
      const result = nativeCall('queryNativeDownload', String(item.nativeDownloadId));
      if (!result) return;
      try {
        const status = JSON.parse(result);
        if (!status || !status.status) return;
        const previous = lastDownloadSamples[item.id];
        const now = Date.now();
        const downloaded = Number(status.downloadedBytes || 0);
        let nextSpeed = 0;
        if (previous && now > previous.time && downloaded > previous.bytes) nextSpeed = Math.round((downloaded - previous.bytes) * 1000 / (now - previous.time));
        lastDownloadSamples[item.id] = { time: now, bytes: downloaded };
        if (item.downloadedBytes !== downloaded) { item.downloadedBytes = downloaded; changed = true; }
        if (Number(status.totalBytes) > 0 && item.totalBytes !== Number(status.totalBytes)) { item.totalBytes = Number(status.totalBytes); changed = true; }
        if (status.title && item.name !== status.title) { item.name = status.title; changed = true; }
        if (status.category && item.category !== status.category) { item.category = status.category; changed = true; }
        if (item.status !== status.status) { item.status = status.status; changed = true; }
        if (status.localUri && item.localUri !== status.localUri) { item.localUri = status.localUri; changed = true; }
        if ((item.speedBps || 0) !== nextSpeed) { item.speedBps = nextSpeed; changed = true; }
      } catch (_) { }
    });
    if (changed) {
      persist();
      if (store.state.activeScreen === 'downloads') renderDownloads();
    }
  }

  function renderSyncNow() {
    store.state.sync.lastSync = isAr() ? 'المزامنة غير متاحة — لا يوجد خادم مهيأ' : 'Sync unavailable — no server configured';
  }

  function showCustomSearchEngineForm() {
    showSheet('<h2>' + esc(isAr() ? 'إضافة محرك بحث مخصص' : 'Add custom search engine') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'استخدم الرمز %s مكان عبارة البحث. لا ترسل بياناتك إلى خدمة لا تثق بها.' : 'Use %s as the search term placeholder. Only add a search URL you trust.') + '</p><form id="custom-engine-form" class="sheet-form"><label>' + esc(isAr() ? 'اسم المحرك' : 'Engine name') + '<input name="name" required></label><label>HTTPS URL<input name="url" type="url" placeholder="https://example.com/search?q=%s" required></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button type="submit" class="primary-action">' + esc(isAr() ? 'حفظ' : 'Save') + '</button></div></form>');
  }

  function saveCustomEngine(form) {
    const data = new FormData(form);
    const url = String(data.get('url') || '').trim();
    if (!/^https:\/\//i.test(url) || !url.includes('%s')) { toast(isAr() ? 'يجب أن يكون الرابط HTTPS ويحتوي %s' : 'URL must use HTTPS and include %s'); return; }
    const id = 'custom-' + Date.now();
    store.state.customSearchEngines.push({ id, name: String(data.get('name') || 'Custom Search'), urlTemplate: url });
    store.state.searchEngine = id;
    persist(); closeSheet(); renderSearch(); renderSettings();
  }

  function toggleLanguage() {
    store.state.lang = store.state.lang === 'ar' ? 'en' : 'ar';
    persist(); applyTranslations(); hydrateIcons(); renderHome(); renderSettings(); renderNavBadge();
    if (store.state.activeScreen !== 'home') navigate(store.state.activeScreen);
    toast(store.state.lang === 'ar' ? 'تم تغيير اللغة إلى العربية' : 'Language changed to English');
  }

  function openDeveloperTools() {
    const logs = (store.devLogs || []).slice(0, 25).map(row => '<div class="dev-log-row"><time>' + esc(row.time) + '</time><b class="log-' + esc(row.level) + '">' + esc(row.level) + '</b><span>' + esc(row.msg) + '</span></div>').join('');
    const inspector = !!store.state.settings.webInspectorEnabled;
    showSheet('<h2>' + esc(isAr() ? 'أدوات المطور' : 'Developer tools') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'سجل محلي للـ shell. يمكن اختيار تمكين WebView debugging للاتصال عبر USB وChrome DevTools.' : 'Local shell logs. You may opt in to WebView debugging for USB and Chrome DevTools inspection.') + '</p><div class="setting-row inspector-toggle-row"><div class="setting-copy"><div class="setting-title">WebView debugging</div><div class="setting-sub">' + esc(isAr() ? 'يتيح فحص الصفحات عبر USB عند اتصال الكمبيوتر' : 'Enables remote inspection over USB when a computer is connected') + '</div></div><button class="nexa-switch ' + (inspector ? 'on' : '') + '" data-action="toggle-inspector"></button></div><div class="developer-log-list">' + (logs || '<div class="empty-inline">No logs</div>') + '</div><div class="sheet-form-actions"><button class="ghost-action" data-action="clear-dev-logs">' + esc(isAr() ? 'مسح السجل' : 'Clear logs') + '</button><button class="primary-action" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button></div>');
  }

  function runFindInPage() {
    const active = ensureTab();
    if (!active.url || active.url.startsWith('nexa://')) { toast(isAr() ? 'افتح صفحة ويب أولًا' : 'Open a webpage first'); return; }
    showSheet('<h2>' + esc(isAr() ? 'بحث في الصفحة' : 'Find in page') + '</h2><form id="find-form" class="sheet-form"><label>' + esc(isAr() ? 'النص المطلوب' : 'Find text') + '<input name="query" autocomplete="off" required></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button><button type="submit" class="primary-action">' + esc(isAr() ? 'بحث' : 'Find') + '</button></div><div id="find-results" class="fine-print"></div></form>');
  }

  function zoomSheet() {
    const tab = ensureTab();
    showSheet('<h2>' + esc(isAr() ? 'تكبير الصفحة' : 'Page zoom') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'يضبط تكبير النص في تبويب الويب الحالي.' : 'Adjusts text zoom for the active webpage tab.') + '</p><div class="zoom-controls"><button class="ghost-action" data-action="zoom-change" data-delta="-10">−</button><strong id="zoom-current-value">' + (tab.zoom || 100) + '%</strong><button class="ghost-action" data-action="zoom-change" data-delta="10">+</button></div><input id="zoom-range" type="range" min="50" max="200" step="10" value="' + (tab.zoom || 100) + '"><button class="secondary-btn" data-action="zoom-reset">' + esc(isAr() ? 'إعادة ضبط' : 'Reset') + '</button>');
  }

  function readerTheme(theme) {
    store.state.reader.theme = theme;
    persist(); renderReader();
  }

  function showQrNative() {
    if (!window.NexaNative) { toast(isAr() ? 'ماسح QR يتطلب تطبيق Android' : 'QR scanner requires Android app'); return; }
    nativeCall('startQrScanner');
  }

  function handleClick(event) {
    const target = event.target.closest('[data-action]');
    if (!target) {
      if (event.target.id === 'sheet-backdrop') closeSheet();
      return;
    }
    const action = target.dataset.action;
    if (action === 'navigate') { closeSheet(); navigate(target.dataset.screen); return; }
    if (action === 'open-menu') { openMenu(); return; }
    if (action === 'open-wallpaper') { wallpaperSheet(); return; }
    if (action === 'toggle-incognito') { createTab(!ensureTab().isPrivate); return; }
    if (action === 'choose-engine') { chooseEngineSheet(); return; }
    if (action === 'submit-home-search') { submitSearch($('#home-search-input').value); return; }
    if (action === 'submit-search-page') { submitSearch($('#search-page-input').value, currentSearchPrefix); return; }
    if (action === 'search-prefix') { currentSearchPrefix = target.dataset.prefix || ''; navigate('search', { focus: true }); return; }
    if (action === 'voice-search') { nativeCall('triggerVoiceSearch', store.state.lang === 'ar' ? 'ar-SA' : 'en-US'); toast(isAr() ? 'استمع الآن…' : 'Listening…'); return; }
    if (action === 'qr-scan') { showQrNative(); return; }
    if (action === 'select-wallpaper') { store.state.wallpaper = target.dataset.id; document.body.dataset.wallpaper = target.dataset.id; persist(); wallpaperSheet(); return; }
    if (action === 'add-shortcut') { openAddShortcut(); return; }
    if (action === 'toggle-edit-shortcuts') { editingShortcuts = !editingShortcuts; const label = target.querySelector('[data-i18n]'); if (label) label.textContent = editingShortcuts ? t('doneEditing') : t('editShortcuts'); renderHome(); return; }
    if (action === 'delete-shortcut') { event.stopPropagation(); store.state.shortcuts = store.state.shortcuts.filter(item => item.id !== target.dataset.id); persist(); renderHome(); return; }
    if (action === 'move-shortcut') { event.stopPropagation(); moveShortcut(Number(target.dataset.index), Number(target.dataset.delta)); return; }
    if (action === 'open-shortcut' || action === 'open-url') { const url = target.dataset.url; if (url) loadInActiveTab(url); return; }
    if (action === 'clear-recents') { store.state.recentSites = []; persist(); renderHome(); return; }
    if (action === 'tab-filter') { tabsFilter = target.dataset.filter; renderTabs(); return; }
    if (action === 'toggle-tabs-view') { store.state.tabsViewMode = store.state.tabsViewMode === 'list' ? 'grid' : 'list'; persist(); renderTabs(); return; }
    if (action === 'new-tab') { closeSheet(); createTab(false); return; }
    if (action === 'new-private-tab') { closeSheet(); createTab(true); return; }
    if (action === 'switch-tab') { const tab = store.state.tabs.find(item => item.id === target.dataset.id); closeSheet(); openTab(tab); return; }
    if (action === 'close-tab') { event.stopPropagation(); closeTab(target.dataset.id); return; }
    if (action === 'pin-tab') { event.stopPropagation(); const tab = store.state.tabs.find(item => item.id === target.dataset.id); if (tab) { tab.pinned = !tab.pinned; persist(); renderTabs(); } return; }
    if (action === 'close-all-tabs') { closeAllTabs(); return; }
    if (action === 'confirm-close-all') { confirmCloseAll(); return; }
    if (action === 'restore-closed') { restoreClosed(target.dataset.id); return; }
    if (action === 'download-filter') { downloadsFilter = target.dataset.filter; renderDownloads(); return; }
    if (action === 'new-download') { openDownloadSheet(); return; }
    if (action === 'cancel-download') { if (target.dataset.nativeId) nativeCall('cancelNativeDownload', target.dataset.nativeId); const item = store.state.downloads.find(x => x.id === target.dataset.id); if (item) item.status = 'canceled'; persist(); renderDownloads(); return; }
    if (action === 'retry-download') { const item = store.state.downloads.find(x => x.id === target.dataset.id); if (item) startDownload(item.url, item.name, '', !!item.isPrivate); return; }
    if (action === 'open-download') { const item = store.state.downloads.find(x => x.id === target.dataset.id); if (item) nativeCall('openDownloadedFile', item.nativeDownloadId || '', item.url); return; }
    if (action === 'share-download') { const item = store.state.downloads.find(x => x.id === target.dataset.id); if (item) nativeCall('shareNativeDownloadFile', item.nativeDownloadId || '', item.name); return; }
    if (action === 'delete-download') { const item = store.state.downloads.find(x => x.id === target.dataset.id); if (item && item.nativeDownloadId) nativeCall('removeNativeDownload', String(item.nativeDownloadId)); store.state.downloads = store.state.downloads.filter(x => x.id !== target.dataset.id); persist(); renderDownloads(); return; }
    if (action === 'pause-download') { toast(isAr() ? 'Android DownloadManager لا يتيح الإيقاف المؤقت لهذا التنزيل؛ يمكنك إلغاءه وإعادة المحاولة.' : 'Android DownloadManager pause is unavailable here; cancel and retry instead.'); return; }
    if (action === 'extension-filter') { extensionFilter = target.dataset.filter; renderExtensions(); return; }
    if (action === 'extension-detail') { extensionDetail(target.dataset.id); return; }
    if (action === 'install-extension') { installExtension(target.dataset.id); return; }
    if (action === 'uninstall-extension') { uninstallExtension(target.dataset.id); return; }
    if (action === 'toggle-extension') { toggleExtension(target.dataset.id); return; }
    if (action === 'edit-userscript') { editUserscript(); return; }
    if (action === 'save-userscript') { saveUserscript(); return; }
    if (action === 'show-extension-info') { showSheet('<h2>' + esc(isAr() ? 'دعم الإضافات على Android' : 'Extensions on Android') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'تعمل الإضافات المدرجة كسكربتات محتوى محلية داخل WebView. حزم Chrome Web Store بصيغة CRX وواجهات Chromium Extensions الكاملة غير مدعومة بواسطة Android System WebView.' : 'Listed extensions run as built-in local content scripts in WebView. Chrome Web Store CRX packages and the full Chromium Extensions API are not supported by Android System WebView.') + '</p><div class="sheet-form-actions"><button class="primary-action" data-action="close-sheet">' + esc(isAr() ? 'فهمت' : 'Got it') + '</button></div>'); return; }
    if (action === 'toggle-privacy') { togglePrivacy(target.dataset.key); return; }
    if (action === 'toggle-setting') { const key = target.dataset.key; store.state.settings[key] = !store.state.settings[key]; if (key === 'blockThirdPartyCookies') { store.state.privacy.blockThirdPartyCookies = store.state.settings[key]; nativeCall('setBlockThirdPartyCookies', store.state.settings[key]); } if (key === 'autoHibernateTabs') nativeCall('setHibernationEnabled', store.state.settings[key]); persist(); renderSettings(); renderPrivacy(); toast(isAr() ? 'تم حفظ الإعداد' : 'Setting saved'); return; }
    if (action === 'add-whitelist') { const domain = prompt(isAr() ? 'أدخل نطاقًا مثل example.com' : 'Enter a domain, e.g. example.com'); if (domain) { const normalized = domain.trim().toLowerCase().replace(/^https?:\/\//, '').split('/')[0].replace(/^www\./, ''); if (!store.state.privacy.whitelist.includes(normalized)) store.state.privacy.whitelist.push(normalized); nativeCall('addWhitelistDomain', normalized); persist(); renderPrivacy(); } return; }
    if (action === 'remove-whitelist') { store.state.privacy.whitelist = store.state.privacy.whitelist.filter(x => x !== target.dataset.domain); nativeCall('removeWhitelistDomain', target.dataset.domain); persist(); renderPrivacy(); return; }
    if (action === 'clear-browsing-data') { clearBrowsingData(); return; }
    if (action === 'vpn-connect') { showVpnNotice(); return; }
    if (action === 'select-vpn-server') { store.state.vpn.selectedServer = target.dataset.id; persist(); renderVpn(); return; }
    if (action === 'configure-vpn') { showVpnConfig(); return; }
    if (action === 'library-tab') { libraryTab = target.dataset.tab; renderLibrary(); return; }
    if (action === 'bookmark-folder') { bookmarkFolder = target.dataset.folder; renderLibrary(); return; }
    if (action === 'bookmark-current') { saveCurrentBookmark(); return; }
    if (action === 'toggle-favorite') { const item = store.state.bookmarks.find(x => x.id === target.dataset.id); if (item) item.favorite = !item.favorite; persist(); renderLibrary(); renderHome(); return; }
    if (action === 'delete-bookmark') { store.state.bookmarks = store.state.bookmarks.filter(x => x.id !== target.dataset.id); persist(); renderLibrary(); renderHome(); return; }
    if (action === 'delete-history') { store.state.history = store.state.history.filter(x => x.id !== target.dataset.id); persist(); renderLibrary(); return; }
    if (action === 'clear-search-history') { store.state.history = store.state.history.filter(x => x.type !== 'search'); persist(); renderSearch(); return; }
    if (action === 'search-again') { submitSearch(target.dataset.query || ''); return; }
    if (action === 'export-bookmarks') { exportBookmarks(); return; }
    if (action === 'import-bookmarks') { $('#bookmark-import-input').click(); return; }
    if (action === 'unlock-vault') { unlockVault(); return; }
    if (action === 'lock-vault') { store.vaultUnlocked = false; store.vault = []; renderPasswords(); return; }
    if (action === 'add-credential') { addCredential(); return; }
    if (action === 'delete-credential') { deleteCredential(target.dataset.id); return; }
    if (action === 'fill-credential') { fillCredential(target.dataset.id); return; }
    if (action === 'confirm-fill-credential') { confirmFillCredential(target.dataset.id); return; }
    if (action === 'reader-save') { saveReaderArticle(); return; }
    if (action === 'extract-reader') { extractReader(); return; }
    if (action === 'reader-tool') { closeSheet(); if (ensureTab().url.startsWith('http')) extractReader(); navigate('reader'); return; }
    if (action === 'reader-font') { store.state.reader.fontSize = Math.max(13, Math.min(30, (store.state.reader.fontSize || 18) + Number(target.dataset.delta) * 2)); persist(); renderReader(); return; }
    if (action === 'reader-theme') { readerTheme(target.dataset.theme); return; }
    if (action === 'open-saved-article') { const item = store.state.reader.savedArticles[Number(target.dataset.index)]; if (item) { readerArticle = item; renderReader(item); } return; }
    if (action === 'delete-saved-article') { store.state.reader.savedArticles.splice(Number(target.dataset.index), 1); persist(); renderSavedArticles(); return; }
    if (action === 'configure-sync') { configureSync(); return; }
    if (action === 'toggle-sync') { const key = target.dataset.key; store.state.sync[key] = !store.state.sync[key]; if (key === 'syncPasswordsE2EE' && store.state.sync[key]) { store.state.sync[key] = false; toast(isAr() ? 'المزامنة المشفرة تحتاج إلى خادم موثوق غير مهيأ' : 'Encrypted sync requires a trusted server that is not configured'); } persist(); renderSync(); return; }
    if (action === 'set-engine') { store.state.searchEngine = target.dataset.id; persist(); closeSheet(); renderHome(); renderSearch(); renderSettings(); return; }
    if (action === 'add-search-engine') { showCustomSearchEngineForm(); return; }
    if (action === 'toggle-language') { toggleLanguage(); return; }
    if (action === 'set-homepage') { showHomepageSheet(); return; }
    if (action === 'font-scale') { store.state.settings.fontSizeScale = Math.max(80, Math.min(150, Number(store.state.settings.fontSizeScale) + Number(target.dataset.delta))); const tab = ensureTab(); nativeCall('setZoomPercent', store.state.settings.fontSizeScale); persist(); renderSettings(); return; }
    if (action === 'toggle-javascript') { store.state.settings.javascriptEnabled = !store.state.settings.javascriptEnabled; nativeCall('setJavaScriptEnabled', store.state.settings.javascriptEnabled); persist(); renderSettings(); return; }
    if (action === 'toggle-user-agent') { const tab = ensureTab(); tab.desktopMode = !tab.desktopMode; nativeCall('setDesktopMode', tab.desktopMode); persist(); toast(tab.desktopMode ? (isAr() ? 'تم طلب موقع سطح المكتب' : 'Desktop site requested') : (isAr() ? 'تم الرجوع إلى موقع الهاتف' : 'Mobile site requested')); return; }
    if (action === 'about') { showAbout(); return; }
    if (action === 'open-app-settings') { nativeCall('openAppSettings'); return; }
    if (action === 'close-sheet') { closeSheet(); return; }
    if (action === 'browser-tools') { openBrowserTools(); return; }
    if (action === 'screenshot') { closeSheet(); takeScreenshot(); return; }
    if (action === 'share-page') { closeSheet(); sharePage(); return; }
    if (action === 'find-page') { runFindInPage(); return; }
    if (action === 'desktop-site') { const tab = ensureTab(); tab.desktopMode = !tab.desktopMode; nativeCall('setDesktopMode', tab.desktopMode); persist(); closeSheet(); toast(isAr() ? 'تم تحديث وضع الموقع' : 'Site mode updated'); return; }
    if (action === 'zoom-page') { zoomSheet(); return; }
    if (action === 'copy-link') { const tab = ensureTab(); if (tab.url && !tab.url.startsWith('nexa://')) { nativeCall('copyToClipboard', 'NexaBrowser', tab.url); toast(isAr() ? 'تم نسخ الرابط' : 'Link copied'); } return; }
    if (action === 'external-page') { const tab = ensureTab(); if (tab.url && !tab.url.startsWith('nexa://')) nativeCall('openInExternalBrowser', tab.url); return; }
    if (action === 'translate-page') { showTranslationNotice(); return; }
    if (action === 'external-translator') { closeSheet(); nativeCall('openInExternalBrowser', 'https://translate.google.com/'); return; }
    if (action === 'copy-qr') { nativeCall('copyToClipboard', 'NexaBrowser QR', target.dataset.value || ''); closeSheet(); toast(isAr() ? 'تم نسخ محتوى QR' : 'QR content copied'); return; }
    if (action === 'developer-tools') { openDeveloperTools(); return; }
    if (action === 'toggle-inspector') { store.state.settings.webInspectorEnabled = !store.state.settings.webInspectorEnabled; nativeCall('setWebInspectorEnabled', store.state.settings.webInspectorEnabled); persist(); closeSheet(); openDeveloperTools(); toast(isAr() ? 'تم تحديث إعداد WebView debugging' : 'WebView debugging setting updated'); return; }
    if (action === 'clear-dev-logs') { store.devLogs = []; closeSheet(); openDeveloperTools(); return; }
    if (action === 'browser-back') { const tab = ensureTab(); if (tab.canGoBack) nativeCall('goBack'); else navigate('home'); return; }
    if (action === 'browser-forward') { nativeCall('goForward'); return; }
    if (action === 'browser-reload') { nativeCall('reload'); return; }
    if (action === 'zoom-change') { changeZoom(Number(target.dataset.delta)); return; }
    if (action === 'zoom-reset') { const tab = ensureTab(); tab.zoom = 100; nativeCall('setZoomPercent', 100); persist(); closeSheet(); zoomSheet(); return; }
  }

  function moveShortcut(index, delta) {
    const next = index + delta;
    if (next < 0 || next >= store.state.shortcuts.length) return;
    const list = store.state.shortcuts;
    [list[index], list[next]] = [list[next], list[index]];
    persist(); renderHome();
  }

  function clearBrowsingData() {
    showSheet('<h2>' + esc(isAr() ? 'مسح بيانات التصفح' : 'Clear browsing data') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'اختر البيانات المحلية المراد حذفها. لا يمكن التراجع عن المسح.' : 'Choose local data to delete. This cannot be undone.') + '</p><form id="clear-data-form" class="sheet-form"><label class="toggle-row"><input type="checkbox" name="history" checked> ' + esc(isAr() ? 'السجل وقائمة المواقع الأخيرة' : 'History and recent sites') + '</label><label class="toggle-row"><input type="checkbox" name="cookies" checked> Cookies</label><label class="toggle-row"><input type="checkbox" name="storage" checked> Web storage</label><label class="toggle-row"><input type="checkbox" name="cache" checked> Cache</label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button type="submit" class="primary-action">' + esc(isAr() ? 'مسح المحدد' : 'Clear selected') + '</button></div></form>');
  }

  function handleClearDataForm(form) {
    const data = new FormData(form);
    if (data.has('history')) {
      store.state.history = [];
      store.state.recentSites = [];
    }
    nativeCall('clearNativeBrowsingData', data.has('cookies'), data.has('storage'), data.has('cache'));
    persist(); closeSheet(); renderHome(); renderLibrary();
    toast(isAr() ? 'تم مسح البيانات المحددة من هذا الجهاز' : 'Selected data cleared from this device');
  }

  function showVpnConfig() {
    showSheet('<h2>' + esc(isAr() ? 'إعداد تكامل VPN' : 'Configure VPN integration') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'هذه الإعدادات تُحفظ محليًا فقط. لا يوجد عميل WireGuard أو خادم VPN مرفق، لذا لن يؤدي الحفظ إلى إنشاء نفق.' : 'These values are stored locally only. No WireGuard client or VPN server is bundled, so saving does not create a tunnel.') + '</p><form id="vpn-config-form" class="sheet-form"><label>' + esc(isAr() ? 'نقطة النهاية (للتكامل المستقبلي)' : 'Backend endpoint (future integration)') + '<input name="endpoint" type="url" placeholder="https://vpn-provider.example"></label><label>DNS-over-HTTPS resolver<input name="doh" type="url" value="' + esc(store.state.vpn.dohUrl || 'https://cloudflare-dns.com/dns-query') + '"></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" type="submit">' + esc(isAr() ? 'حفظ محليًا' : 'Save locally') + '</button></div></form>');
  }

  function saveVpnConfig(form) {
    const data = new FormData(form);
    store.state.vpn.customEndpoint = String(data.get('endpoint') || '');
    store.state.vpn.dohUrl = String(data.get('doh') || '');
    nativeCall('saveCustomVpnBackend', store.state.vpn.customEndpoint, store.state.vpn.customPubKey || '', store.state.vpn.dohUrl);
    persist(); closeSheet(); renderVpn();
    toast(isAr() ? 'حُفظ الإعداد محليًا — لا يوجد اتصال VPN فعال' : 'Saved locally — no VPN tunnel is active');
  }

  function configureSync() {
    showSheet('<h2>' + esc(isAr() ? 'إعداد خادم المزامنة' : 'Configure sync server') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'لا يوجد بروتوكول مزامنة أو خادم مدمج في هذا الإصدار. يمكن حفظ عنوان الخادم المقترح محليًا فقط.' : 'No sync protocol or server is bundled in this release. A server URL can be stored locally as a future integration setting.') + '</p><form id="sync-config-form" class="sheet-form"><label>HTTPS Endpoint<input name="url" type="url" value="' + esc(store.state.sync.customSyncServer || '') + '"></label><div class="sheet-note">' + esc(isAr() ? 'لن يتم تسجيل الدخول أو رفع البيانات حتى تتم إضافة عميل مزامنة موثوق.' : 'No sign-in or upload occurs until a trusted sync client is integrated.') + '</div><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" type="submit">' + esc(isAr() ? 'حفظ العنوان' : 'Save endpoint') + '</button></div></form>');
  }

  function saveSyncConfig(form) {
    const data = new FormData(form);
    const url = String(data.get('url') || '');
    if (url && !/^https:\/\//i.test(url)) { toast(isAr() ? 'استخدم رابط HTTPS' : 'Use an HTTPS URL'); return; }
    store.state.sync.customSyncServer = url;
    persist(); closeSheet(); renderSync();
    toast(isAr() ? 'حُفظ العنوان محليًا؛ المزامنة ما زالت غير نشطة' : 'Endpoint saved locally; sync remains inactive');
  }

  function showHomepageSheet() {
    showSheet('<h2>' + esc(isAr() ? 'صفحة بدء التشغيل' : 'Startup homepage') + '</h2><form id="homepage-form" class="sheet-form"><label>Homepage URL<input name="url" value="' + esc(store.state.settings.homepage) + '" required></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" type="submit">' + esc(isAr() ? 'حفظ' : 'Save') + '</button></div></form>');
  }

  function saveHomepage(form) {
    const data = new FormData(form);
    const url = String(data.get('url') || '').trim();
    store.state.settings.homepage = url || 'nexa://home';
    persist(); closeSheet(); renderSettings();
  }

  function editUserscript() {
    const script = store.state.customUserscript || '';
    showSheet('<h2>' + esc(isAr() ? 'محرر Userscript' : 'Userscript editor') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'الكود التالي يعمل بصلاحيات الصفحة الحالية على المواقع التي تزورها. لا تلصق كودًا غير موثوق.' : 'This script runs in the current page context on sites you visit. Do not paste untrusted code.') + '</p><form id="userscript-form" class="sheet-form"><label>JavaScript<textarea name="script" spellcheck="false">' + esc(script) + '</textarea></label><div class="sheet-form-actions"><button type="button" class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إلغاء' : 'Cancel') + '</button><button class="primary-action" type="submit" data-action="save-userscript">' + esc(isAr() ? 'حفظ وتفعيل' : 'Save & enable') + '</button></div></form>');
  }

  function saveUserscript() {
    const form = $('#userscript-form');
    if (!form) return;
    const data = new FormData(form);
    store.state.customUserscript = String(data.get('script') || '');
    nativeCall('setCustomUserscript', store.state.customUserscript);
    if (!store.state.installedExtensions['ext-userscript-runner']) store.state.installedExtensions['ext-userscript-runner'] = { installed: true, enabled: true };
    else store.state.installedExtensions['ext-userscript-runner'].enabled = true;
    nativeCall('setExtensionEnabled', 'ext-userscript-runner', true);
    persist(); closeSheet(); renderExtensions();
    toast(isAr() ? 'تم حفظ السكربت وتفعيله' : 'Userscript saved and enabled');
  }

  function showTranslationNotice() {
    const active = ensureTab();
    showSheet('<h2>' + esc(isAr() ? 'ترجمة الصفحة' : 'Translate page') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'لا يحتوي التطبيق على خدمة ترجمة أو مفتاح API، ولا يرسل النص إلى خادم خارجي. يمكنك تحديد نص الصفحة ونسخه إلى مترجم تثق به.' : 'No translation provider or API key is configured. The app does not send page text to a remote service. You can select and copy text into a translator you trust.') + '</p><div class="sheet-note">' + esc(hostOf(active.url)) + '</div><div class="sheet-form-actions"><button class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button><button class="primary-action" data-action="external-translator">' + esc(isAr() ? 'فتح مترجم خارجي' : 'Open external translator') + '</button></div>');
  }

  function sharePage() {
    const tab = ensureTab();
    if (tab.url && !tab.url.startsWith('nexa://')) nativeCall('shareContent', tab.title || tab.url, tab.url);
    else toast(isAr() ? 'لا توجد صفحة لمشاركتها' : 'No page to share');
  }

  function takeScreenshot() {
    if (!window.NexaNative) { toast(isAr() ? 'لقطة الشاشة تتطلب تطبيق Android' : 'Screenshot requires Android app'); return; }
    nativeCall('captureActivePageScreenshot');
    toast(isAr() ? 'جارٍ حفظ لقطة الصفحة…' : 'Saving page screenshot…');
  }

  function changeZoom(delta) {
    const tab = ensureTab();
    tab.zoom = Math.max(50, Math.min(200, Number(tab.zoom || 100) + delta));
    nativeCall('setZoomPercent', tab.zoom);
    const val = $('#zoom-current-value'); if (val) val.textContent = tab.zoom + '%';
    const range = $('#zoom-range'); if (range) range.value = tab.zoom;
    persist();
  }

  function showAbout() {
    showSheet('<div class="about-brand"><img src="logo.png" alt=""><div><h2>NexaBrowser</h2><p>Version 1.0.0 · Android WebView</p></div></div><p class="sheet-subtitle">' + esc(isAr() ? 'متصفح Android أصلي بواجهة محلية خفيفة ومحرك WebView النظام. البيانات محلية افتراضيًا. لا يتضمن هذا الإصدار خدمة VPN أو مزامنة سحابية.' : 'Native Android browser with a lightweight local UI and the system WebView engine. Data stays local by default. This release does not include a VPN or cloud-sync provider.') + '</p><div class="about-detail-row"><span>Engine</span><strong>Android System WebView (Chromium)</strong></div><div class="about-detail-row"><span>Privacy</span><strong>Local storage · Android KeyStore</strong></div><div class="about-detail-row"><span>Build</span><strong>Release 1.0.0</strong></div><button class="primary-action" style="width:100%;margin-top:14px" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button>');
  }

  function moveSearchHistory(query) {
    if (!query) return;
    const url = searchUrl(query);
    if (!ensureTab().isPrivate && !store.state.privacy.doNotSaveHistory) {
      const title = (isAr() ? 'بحث: ' : 'Search: ') + query;
      store.state.history = store.state.history.filter(item => !(item.type === 'search' && item.url === url));
      store.state.history.unshift({ id: 'h-' + Date.now(), title, url, type: 'search', time: new Date().toLocaleTimeString(store.state.lang === 'ar' ? 'ar' : 'en', { hour: '2-digit', minute: '2-digit' }), visitedAt: nowIso() });
      store.state.history = store.state.history.slice(0, 250);
      persist();
    }
  }

  // --- Native-to-JavaScript callbacks (called only by the trusted Android shell) ---
  window.__onNativeTabState = function (info) {
    if (!info || !info.tabId) return;
    const tab = store.state.tabs.find(item => item.id === info.tabId);
    if (!tab) return;
    let changed = false;
    if (info.url && /^https?:\/\//i.test(info.url) && tab.url !== info.url) { tab.url = info.url; changed = true; }
    if (info.title && info.title !== 'about:blank' && tab.title !== info.title) { tab.title = info.title; changed = true; }
    if (typeof info.canGoBack === 'boolean') tab.canGoBack = info.canGoBack;
    if (typeof info.canGoForward === 'boolean') tab.canGoForward = info.canGoForward;
    if (tab.hibernated) { tab.hibernated = false; changed = true; }
    if (info.tabId === store.state.activeTabId) {
      const input = $('#browser-url-input');
      if (input && document.activeElement !== input) input.value = info.url || tab.url;
      const bar = $('#browser-progress-line');
      if (bar) { bar.style.width = Math.max(0, Math.min(100, info.progress || 0)) + '%'; bar.style.opacity = info.progress >= 100 ? '0' : '1'; }
      const secure = $('#browser-security-icon');
      if (secure) { secure.innerHTML = svg(info.isSecure ? 'lock' : 'info', 15); secure.classList.toggle('not-secure', !info.isSecure); }
      if (info.progress >= 100) {
        const placeholder = $('#browser-native-placeholder'); if (placeholder) placeholder.style.display = 'none';
        store.state.privacy.adsBlocked = Math.max(store.state.privacy.adsBlocked || 0, Number(info.adsBlocked || 0));
        store.state.privacy.trackersBlocked = Math.max(store.state.privacy.trackersBlocked || 0, Number(info.trackersBlocked || 0));
        if (!tab.isPrivate && !store.state.privacy.doNotSaveHistory && tab.url && !tab.url.startsWith('nexa://')) {
          store.state.recentSites = [{ id: 'r-' + Date.now(), title: tab.title || hostOf(tab.url), url: tab.url, time: isAr() ? 'الآن' : 'just now' }].concat((store.state.recentSites || []).filter(item => item.url !== tab.url)).slice(0, 6);
          changed = true;
        }
        renderPrivacyStats();
      }
    }
    if (changed) persist();
  };

  window.__onNativeDownloadStarted = function (info) {
    if (!info) return;
    const nativeId = String(info.nativeDownloadId || '');
    if (!nativeId || nativeId === '-1') { toast(isAr() ? 'تعذر بدء التنزيل' : 'Download failed to start'); return; }
    const id = 'dm-' + nativeId;
    if (store.state.downloads.some(item => String(item.nativeDownloadId) === nativeId)) return;
    const name = info.fileName || safeFileName(info.url || 'download');
    store.state.downloads.unshift({ id, nativeDownloadId: nativeId, name, fileName: name, url: info.url || '', category: inferCategory(name), sizeBytes: Number(info.sizeBytes) > 0 ? Number(info.sizeBytes) : 0, downloadedBytes: 0, status: 'pending', isPrivate: !!info.isPrivate, createdAt: nowIso() });
    persist(); renderDownloads();
    toast(isAr() ? 'أضيف التنزيل إلى Android DownloadManager' : 'Added to Android DownloadManager');
  };

  window.__onNativeTabError = function (tabId, url, description, code) {
    store.logDev('network-error', url + ' · ' + description + ' · ' + code);
    if (tabId === store.state.activeTabId) {
      const progress = $('#browser-progress-line');
      if (progress) { progress.style.width = '0%'; progress.style.opacity = '0'; }
      const placeholder = $('#browser-native-placeholder');
      if (placeholder) placeholder.style.display = 'none';
      toast(isAr() ? 'تعذر تحميل الصفحة — يمكنك المحاولة مجددًا من صفحة الخطأ' : 'Page could not load — retry from the error page');
    }
  };

  window.__onNativeDangerousSite = function (tabId, url) {
    store.logDev('security', 'Local URL heuristic blocked: ' + url);
    showSheet('<h2>' + esc(isAr() ? 'تحقق من عنوان الموقع' : 'Check this URL') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'طابق العنوان قاعدة محلية محدودة. هذا ليس فحص سمعة مواقع شاملًا.' : 'The URL matched a small local heuristic list. This is not comprehensive website reputation protection.') + '</p><div class="sheet-note">' + esc(url) + '</div><div class="sheet-form-actions"><button class="ghost-action" data-action="close-sheet">' + esc(isAr() ? 'إغلاق' : 'Close') + '</button><button class="primary-action" data-action="open-url" data-url="' + esc(url) + '">' + esc(isAr() ? 'متابعة بحذر' : 'Continue carefully') + '</button></div>');
  };

  window.__onNativeFindResult = function (active, total) {
    const node = $('#find-results');
    if (node) node.textContent = isAr() ? ('المطابقة ' + (total ? active + 1 : 0) + ' من ' + total) : ('Match ' + (total ? active + 1 : 0) + ' of ' + total);
  };

  window.__onNativeReaderArticle = function (payload) {
    if (!payload) return;
    let article = payload;
    if (typeof payload === 'string') { try { article = JSON.parse(payload); } catch (_) { article = null; } }
    if (!article || !article.blocks || !article.blocks.length) { toast(isAr() ? 'لم يعثر على نص مقال واضح في هذه الصفحة' : 'No readable article text found on this page'); return; }
    readerArticle = article;
    store.state.reader.currentArticle = article;
    navigate('reader');
    renderReader(article);
  };

  window.__onNativeVoiceResult = function (text, status) {
    if (status !== 'OK' || !text) { toast(status === 'PERMISSION_DENIED' ? (isAr() ? 'يلزم السماح بالميكروفون للبحث الصوتي' : 'Microphone permission is required for voice search') : (isAr() ? 'تعذر بدء البحث الصوتي' : 'Voice search unavailable')); return; }
    const input = store.state.activeScreen === 'search' ? $('#search-page-input') : $('#home-search-input');
    if (input) input.value = text;
    moveSearchHistory(text);
    submitSearch(text);
  };

  window.__onCameraPermissionResult = function (granted) {
    if (granted) nativeCall('launchQrScannerAfterPermission');
    else toast(isAr() ? 'يلزم السماح بالكاميرا لمسح QR' : 'Camera permission is required to scan QR codes');
  };

  window.__onNativeQrResult = function (value, status) {
    if (status !== 'OK' || !value) { if (status !== 'CANCELLED') toast(isAr() ? 'لم يتم التعرف على رمز QR' : 'No QR code was detected'); return; }
    closeSheet();
    if (/^https?:\/\//i.test(value)) loadInActiveTab(value);
    else {
      showSheet('<h2>' + esc(isAr() ? 'تم مسح رمز QR' : 'QR code scanned') + '</h2><div class="sheet-note qr-result-text">' + esc(value) + '</div><div class="sheet-form-actions"><button class="ghost-action" data-action="copy-qr" data-value="' + esc(value) + '">' + esc(isAr() ? 'نسخ' : 'Copy') + '</button><button class="primary-action" data-action="open-url" data-url="' + esc(value) + '">' + esc(isAr() ? 'فتح' : 'Open') + '</button></div>');
    }
  };

  window.__onNativeScreenshot = function (uri, status) {
    if (status === 'OK') showSheet('<h2>' + esc(isAr() ? 'تم حفظ لقطة الشاشة' : 'Screenshot saved') + '</h2><p class="sheet-subtitle">' + esc(isAr() ? 'حُفظت في مجلد صور التطبيق على هذا الجهاز.' : 'Saved to NexaBrowser screenshots on this device.') + '</p><div class="sheet-note">' + esc(uri || '') + '</div><button class="primary-action" style="width:100%" data-action="close-sheet">' + esc(isAr() ? 'حسنًا' : 'Done') + '</button>');
    else toast(isAr() ? 'تعذر حفظ لقطة الشاشة' : 'Could not save screenshot');
  };

  window.__onNativeAppBackground = function () {
    if (store.state.activeScreen === 'passwords') {
      store.vaultUnlocked = false;
      store.vault = [];
      closeSheet();
      renderPasswords();
    }
  };

  window.__onNativeConsole = function (level, message, source, line) {
    store.logDev(level || 'console', String(message || '') + (source ? ' · ' + source + ':' + line : ''));
  };

  window.__onNativeBackState = function () { return false; };

  window.__onExternalUrlIntent = function (url) {
    if (url && /^https?:\/\//i.test(url)) loadInActiveTab(url);
  };

  window.__handleHardwareBack = function () {
    if ($('#sheet-backdrop').classList.contains('open')) { closeSheet(); return true; }
    if (store.state.activeScreen === 'browser') { navigate('home'); return true; }
    if (store.state.activeScreen !== 'home') { navigate('home'); return true; }
    return false;
  };

  // Event delegation keeps the UI small and remains valid across re-rendered cards/sheets.
  document.addEventListener('click', handleClick);
  document.addEventListener('submit', function (event) {
    const form = event.target;
    event.preventDefault();
    if (form.id === 'bookmark-form') saveBookmarkForm(form);
    else if (form.id === 'shortcut-form') handleShortcutForm(form);
    else if (form.id === 'manual-download-form') { const data = new FormData(form); startDownload(String(data.get('url') || ''), '', ''); }
    else if (form.id === 'vault-pin-form') handleVaultPinForm(form);
    else if (form.id === 'credential-form') saveCredentialForm(form);
    else if (form.id === 'custom-engine-form') saveCustomEngine(form);
    else if (form.id === 'clear-data-form') handleClearDataForm(form);
    else if (form.id === 'vpn-config-form') saveVpnConfig(form);
    else if (form.id === 'sync-config-form') saveSyncConfig(form);
    else if (form.id === 'homepage-form') saveHomepage(form);
    else if (form.id === 'userscript-form') saveUserscript();
    else if (form.id === 'find-form') { const data = new FormData(form); nativeCall('findInPage', String(data.get('query') || '')); }
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      if (event.target.id === 'home-search-input') { event.preventDefault(); moveSearchHistory(event.target.value.trim()); submitSearch(event.target.value); }
      else if (event.target.id === 'search-page-input') { event.preventDefault(); moveSearchHistory(event.target.value.trim()); submitSearch(event.target.value, currentSearchPrefix); }
      else if (event.target.id === 'browser-url-input') { event.preventDefault(); moveSearchHistory(event.target.value.trim()); submitSearch(event.target.value); }
      else if (event.target.id === 'extension-search') renderExtensions();
    }
    if (event.key === 'Escape' && $('#sheet-backdrop').classList.contains('open')) closeSheet();
  });

  document.addEventListener('input', function (event) {
    if (event.target.id === 'extension-search') { extensionSearch = event.target.value; renderExtensions(); const input = $('#extension-search'); input.focus(); input.setSelectionRange(input.value.length, input.value.length); }
    if (event.target.id === 'zoom-range') { const tab = ensureTab(); tab.zoom = Number(event.target.value); nativeCall('setZoomPercent', tab.zoom); const label = $('#zoom-current-value'); if (label) label.textContent = tab.zoom + '%'; persist(); }
  });

  document.addEventListener('change', function (event) {
    if (event.target.id === 'bookmark-import-input') importBookmarksFile(event.target.files && event.target.files[0]);
    if (event.target.id === 'reader-font-family') { store.state.reader.fontFamily = event.target.value; persist(); renderReader(); }
  });

  $('#sheet-backdrop').addEventListener('click', event => { if (event.target.id === 'sheet-backdrop') closeSheet(); });

  function initialize() {
    ensureTab();
    if (!store.state.privacy) store.state.privacy = {};
    if (!store.state.settings) store.state.settings = {};
    if (!store.state.reader) store.state.reader = { fontSize: 18, fontFamily: 'system-ui', theme: 'dark', savedArticles: [] };
    if (!store.state.reader.savedArticles) store.state.reader.savedArticles = [];
    if (!store.state.history) store.state.history = [];
    if (!store.state.downloads) store.state.downloads = [];
    if (!store.state.bookmarks) store.state.bookmarks = [];
    if (!store.state.bookmarksFolders) store.state.bookmarksFolders = ['الكل', 'العمل', 'التقنية', 'الأخبار', 'المفضلة'];
    if (!store.state.recentlyClosedTabs) store.state.recentlyClosedTabs = [];
    if (!store.state.recentSites) store.state.recentSites = [];
    if (!store.state.customSearchEngines) store.state.customSearchEngines = [];
    if (!store.state.installedExtensions) store.state.installedExtensions = {};
    if (!store.state.vpn.servers) store.state.vpn.servers = [];
    applyTranslations();
    hydrateIcons();
    renderHome(); renderSearch(); renderNavBadge();
    persist();
    store.logDev('info', store.isNative ? 'Native Android bridge connected' : 'Browser preview mode (Android features unavailable)');
    if (store.isNative) {
      nativeCall('setAdBlockEnabled', !!store.state.privacy.adBlockEnabled);
      nativeCall('setTrackerBlockEnabled', !!store.state.privacy.trackerBlockEnabled);
      nativeCall('setSafeBrowsingEnabled', !!store.state.privacy.safeBrowsingEnabled);
      nativeCall('setBlockThirdPartyCookies', store.state.settings.blockThirdPartyCookies !== false);
      nativeCall('setJavaScriptEnabled', store.state.settings.javascriptEnabled !== false);
      nativeCall('setWebInspectorEnabled', !!store.state.settings.webInspectorEnabled);
      nativeCall('setHibernationEnabled', store.state.settings.autoHibernateTabs !== false);
      (store.state.privacy.whitelist || []).forEach(domain => nativeCall('addWhitelistDomain', domain));
      Object.keys(store.state.installedExtensions).forEach(id => nativeCall('setExtensionEnabled', id, store.state.installedExtensions[id].enabled !== false));
      if (store.state.customUserscript) nativeCall('setCustomUserscript', store.state.customUserscript);
    }
    if (!window.NexaNative) {
      const dot = $('#engine-status-dot'); if (dot) { dot.style.background = '#fbbf24'; dot.style.boxShadow = '0 0 8px #fbbf24'; }
    }
    document.body.classList.toggle('incognito-active', !!ensureTab().isPrivate);
    downloadPollTimer = setInterval(pollDownloads, 1700);
    store.logDev('ready', 'NexaBrowser UI ready');
  }

  initialize();
})();
