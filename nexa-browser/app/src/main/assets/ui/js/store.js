/* ==========================================================================
   NexaBrowser — Local State Repository + Android Secure Vault adapter
   Browser preferences/bookmarks use the app-local repository. Passwords never
   fall back to plaintext or base64 storage; native Android KeyStore is required.
   ========================================================================== */
(function () {
  'use strict';

  const STORAGE_KEY = 'nexabrowser_state_v2';
  const DEFAULT_STATE = {
    lang: 'ar',
    wallpaper: 'cyber-neon',
    incognitoMode: false,
    activeScreen: 'home',
    searchEngine: 'google',
    customSearchEngines: [],
    shortcuts: [
      { id: 'sc-google', title: 'Google', url: 'https://www.google.com', icon: 'G', color: 'linear-gradient(135deg,#2563EB,#00E5FF)' },
      { id: 'sc-youtube', title: 'YouTube', url: 'https://m.youtube.com', icon: '▶', color: 'linear-gradient(135deg,#EF4444,#EC4899)' },
      { id: 'sc-github', title: 'GitHub', url: 'https://github.com', icon: '⌘', color: 'linear-gradient(135deg,#334155,#0F172A)' },
      { id: 'sc-wiki', title: 'Wikipedia', url: 'https://ar.wikipedia.org', icon: 'W', color: 'linear-gradient(135deg,#6366F1,#8B5CF6)' },
      { id: 'sc-ddg', title: 'DuckDuckGo', url: 'https://duckduckgo.com', icon: 'D', color: 'linear-gradient(135deg,#F97316,#EA580C)' },
      { id: 'sc-reddit', title: 'Reddit', url: 'https://www.reddit.com', icon: 'R', color: 'linear-gradient(135deg,#EA580C,#DC2626)' },
      { id: 'sc-mdn', title: 'MDN Docs', url: 'https://developer.mozilla.org', icon: '⚡', color: 'linear-gradient(135deg,#0EA5E9,#2563EB)' }
    ],
    recentSites: [],
    tabsViewMode: 'grid',
    activeTabId: 'tab-home',
    tabs: [{ id: 'tab-home', title: 'NexaBrowser', url: 'nexa://home', isPrivate: false, pinned: false, hibernated: false, desktopMode: false, zoom: 100, createdAt: Date.now(), lastActive: Date.now() }],
    recentlyClosedTabs: [],
    installedExtensions: {},
    customUserscript: '',
    downloads: [],
    privacy: {
      adBlockEnabled: true,
      trackerBlockEnabled: true,
      safeBrowsingEnabled: false,
      httpsOnly: false,
      doNotTrack: true,
      doNotSaveHistory: false,
      blockThirdPartyCookies: true,
      fingerprintProtection: false,
      adsBlocked: 0,
      trackersBlocked: 0,
      httpsUpgrades: 0,
      whitelist: []
    },
    vpn: {
      connected: false,
      selectedServer: 'ch-zurich',
      protocol: 'Not configured',
      customEndpoint: '',
      customPubKey: '',
      dohUrl: 'https://cloudflare-dns.com/dns-query',
      connectedSince: null,
      servers: [
        { id: 'ch-zurich', countryAr: 'سويسرا — زيورخ', countryEn: 'Switzerland — Zurich', flag: '🇨🇭', ping: '—' },
        { id: 'de-frankfurt', countryAr: 'ألمانيا — فرانكفورت', countryEn: 'Germany — Frankfurt', flag: '🇩🇪', ping: '—' },
        { id: 'nl-amsterdam', countryAr: 'هولندا — أمستردام', countryEn: 'Netherlands — Amsterdam', flag: '🇳🇱', ping: '—' },
        { id: 'ae-dubai', countryAr: 'الإمارات — دبي', countryEn: 'UAE — Dubai', flag: '🇦🇪', ping: '—' },
        { id: 'gb-london', countryAr: 'بريطانيا — لندن', countryEn: 'United Kingdom — London', flag: '🇬🇧', ping: '—' },
        { id: 'us-ny', countryAr: 'أمريكا — نيويورك', countryEn: 'United States — New York', flag: '🇺🇸', ping: '—' },
        { id: 'sg-singapore', countryAr: 'سنغافورة', countryEn: 'Singapore', flag: '🇸🇬', ping: '—' },
        { id: 'jp-tokyo', countryAr: 'اليابان — طوكيو', countryEn: 'Japan — Tokyo', flag: '🇯🇵', ping: '—' }
      ]
    },
    reader: { theme: 'dark', fontSize: 18, fontFamily: 'system-ui', currentArticle: null, savedArticles: [] },
    bookmarksFolders: ['الكل', 'العمل', 'التقنية', 'الأخبار', 'المفضلة'],
    bookmarks: [],
    history: [],
    sync: {
      loggedIn: false,
      email: '',
      lastSync: '',
      syncTabs: false,
      syncBookmarks: false,
      syncHistory: false,
      syncSettings: false,
      syncPasswordsE2EE: false,
      customSyncServer: ''
    },
    settings: {
      homepage: 'nexa://home',
      startupBehavior: 'continue',
      addressBarPosition: 'top',
      fontSizeScale: 100,
      downloadFolder: 'Android Downloads',
      downloadWifiOnly: false,
      askBeforeDownload: true,
      autoHibernateTabs: true,
      closeTabsOnExit: false,
      userAgentMode: 'mobile',
      customUserAgent: '',
      javascriptEnabled: true,
      cookiesPolicy: 'block_third_party',
      notificationsEnabled: true,
      cameraPermission: 'ask',
      micPermission: 'ask',
      blockThirdPartyCookies: true,
      webInspectorEnabled: false,
      locationPermission: 'ask',
      hardwareAcceleration: true,
      smartCacheLimitMb: 128,
      autofillPasswords: false,
      biometricVaultLock: false
    }
  };

  const isNative = !!(window.NexaNative && typeof window.NexaNative.isNativeAndroid === 'function');

  function deepMergeDefaults(parsed) {
    const result = Object.assign({}, DEFAULT_STATE, parsed || {});
    ['privacy', 'vpn', 'reader', 'sync', 'settings'].forEach(key => {
      result[key] = Object.assign({}, DEFAULT_STATE[key], (parsed && parsed[key]) || {});
    });
    if (!Array.isArray(result.tabs)) result.tabs = DEFAULT_STATE.tabs.slice();
    if (!Array.isArray(result.shortcuts)) result.shortcuts = DEFAULT_STATE.shortcuts.slice();
    if (!Array.isArray(result.bookmarks)) result.bookmarks = [];
    if (!Array.isArray(result.history)) result.history = [];
    if (!Array.isArray(result.downloads)) result.downloads = [];
    if (!Array.isArray(result.recentSites)) result.recentSites = [];
    if (!Array.isArray(result.recentlyClosedTabs)) result.recentlyClosedTabs = [];
    if (!Array.isArray(result.bookmarksFolders)) result.bookmarksFolders = DEFAULT_STATE.bookmarksFolders.slice();
    if (!Array.isArray(result.customSearchEngines)) result.customSearchEngines = [];
    if (!Array.isArray(result.reader.savedArticles)) result.reader.savedArticles = [];
    if (!result.installedExtensions || typeof result.installedExtensions !== 'object') result.installedExtensions = {};
    return result;
  }

  function loadState() {
    try {
      let raw = null;
      if (isNative && window.NexaNative.loadStateSnapshot) raw = window.NexaNative.loadStateSnapshot();
      if (!raw) raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return deepMergeDefaults(JSON.parse(raw));
    } catch (error) {
      console.warn('NexaBrowser state load:', error);
    }
    return JSON.parse(JSON.stringify(DEFAULT_STATE));
  }

  function saveState(state) {
    try {
      const raw = JSON.stringify(state);
      localStorage.setItem(STORAGE_KEY, raw);
      if (isNative && window.NexaNative.saveStateSnapshot) window.NexaNative.saveStateSnapshot(raw);
    } catch (error) {
      console.warn('NexaBrowser state save:', error);
    }
  }

  window.NexaStore = {
    isNative,
    state: loadState(),
    vault: [],
    vaultUnlocked: false,
    devLogs: [],
    save() { saveState(this.state); },
    saveVault() {
      // Intentionally no web/localStorage fallback for secrets.
      if (isNative && window.NexaNative.saveEncryptedVault) {
        return window.NexaNative.saveEncryptedVault(JSON.stringify(this.vault || []));
      }
      return false;
    },
    logDev(level, msg) {
      const d = new Date();
      const time = d.toTimeString().split(' ')[0];
      this.devLogs.unshift({ time, level, msg });
      if (this.devLogs.length > 60) this.devLogs.pop();
    }
  };
})();
