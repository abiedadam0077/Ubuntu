/* ==========================================================================
   NexaBrowser — Built-in WebExtensions & Content-Script Catalog
   Each extension injects real JS/CSS into Android WebView & Browser Viewport
   ========================================================================== */

window.NEXA_EXTENSIONS_CATALOG = [
  {
    id: "ext-adguard-ultra",
    name: "Nexa AdGuard Ultra",
    nameAr: "درع الإعلانات المتقدم AdGuard Ultra",
    category: "privacy",
    categoryLabelAr: "الخصوصية وحجب الإعلانات",
    categoryLabelEn: "Privacy & AdBlock",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: true,
    popular: true,
    icon: "🛡️",
    gradient: "linear-gradient(135deg, #00E5FF, #2563EB)",
    descAr: "يخفي بعض عناصر الإعلانات المعروفة عبر CSS ويكمل حجب نطاقات الإعلانات على مستوى طلبات الشبكة.",
    descEn: "Hides selected known ad elements with CSS; the native engine separately blocks listed ad-network requests.",
    permissions: [
      "webRequest & webRequestBlocking (حجب طلبات الشبكة الإعلانية)",
      "activeTab (تنظيف عناصر الصفحة من الإعلانات)",
      "storage (حفظ قوائم الفلاتر المخصصة)"
    ],
    codePreview: "document.querySelectorAll('[id*=\"google_ads\"],.ad-banner,.sponsored').forEach(el => el.remove());"
  },
  {
    id: "ext-dark-reader",
    name: "Dark Reader Neon",
    nameAr: "الوضع الليلي الذكي Dark Reader Neon",
    category: "appearance",
    categoryLabelAr: "المظهر والسمات",
    categoryLabelEn: "Appearance & Themes",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: true,
    popular: true,
    icon: "🌙",
    gradient: "linear-gradient(135deg, #8B5CF6, #4F46E5)",
    descAr: "يحول جميع مواقع الويب الساطعة إلى وضع داكن مريح للعين مع الحفاظ على ألوان الصور والفيديوهات بدقة عالية.",
    descEn: "Transforms bright websites into an eye-friendly OLED dark theme while preserving image and video colors.",
    permissions: [
      "activeTab (تطبيق أنماط CSS الداكنة على الصفحات)",
      "storage (تذكر المواقع المستثناة)"
    ],
    codePreview: "html { filter: invert(0.92) hue-rotate(180deg) !important; } img, video { filter: invert(1) hue-rotate(180deg) !important; }"
  },
  {
    id: "ext-video-speed",
    name: "Video Speed 1.25x",
    nameAr: "تسريع الفيديو 1.25x",
    category: "video",
    categoryLabelAr: "الفيديو والوسائط",
    categoryLabelEn: "Video & Media",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: true,
    popular: true,
    icon: "🎬",
    gradient: "linear-gradient(135deg, #EC4899, #8B5CF6)",
    descAr: "يضبط سرعة فيديوهات HTML5 الحالية إلى 1.25x. لا يضيف عناصر تحكم Picture-in-Picture.",
    descEn: "Sets currently available HTML5 videos to 1.25x. It does not add Picture-in-Picture controls.",
    permissions: [
      "activeTab (التحكم بعناصر <video> في الصفحة)",
      "storage (حفظ السرعة المفضلة افتراضيًا)"
    ],
    codePreview: "document.querySelectorAll('video').forEach(v => { v.playbackRate = 1.25; });"
  },
  {
    id: "ext-cookie-zapper",
    name: "Cookie Banner Zapper",
    nameAr: "مانع نوافذ الكوكيز المزعجة",
    category: "privacy",
    categoryLabelAr: "الخصوصية وحجب الإعلانات",
    categoryLabelEn: "Privacy & AdBlock",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: false,
    popular: true,
    icon: "🍪",
    gradient: "linear-gradient(135deg, #F59E0B, #EA580C)",
    descAr: "يخفي ويرفض تلقائيًا نوافذ الموافقة على ملفات تعريف الارتباط (GDPR / Cookie Popups) لتجربة تصفح نظيفة.",
    descEn: "Automatically dismisses and hides annoying cookie consent banners and GDPR overlays.",
    permissions: [
      "activeTab (إخفاء نوافذ الكوكيز المنبثقة)"
    ],
    codePreview: "[id*='cookie-banner'], [class*='cookie-consent'], #onetrust-banner-sdk { display: none !important; }"
  },
  {
    id: "ext-privacy-badger",
    name: "Battery API Guard",
    nameAr: "حماية واجهة Battery API",
    category: "privacy",
    categoryLabelAr: "الخصوصية وحجب الإعلانات",
    categoryLabelEn: "Privacy & AdBlock",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: false,
    popular: true,
    icon: "🦡",
    gradient: "linear-gradient(135deg, #10B981, #059669)",
    descAr: "يعطّل navigator.getBattery في الصفحة الحالية لتقليل كشف حالة البطارية؛ لا يحمي Canvas أو WebGL.",
    descEn: "Disables navigator.getBattery in the current page. It does not protect against canvas or WebGL fingerprinting.",
    permissions: [
      "webRequest (فحص المتعقبات الخارجية)",
      "activeTab (حماية واجهات البرمجة الحساسة)"
    ],
    codePreview: "navigator.getBattery = undefined; window.__nexaFingerprintProtected = true;"
  },
  {
    id: "ext-ai-translator",
    name: "Page Translation Connector",
    nameAr: "وصلة ترجمة الصفحات",
    category: "productivity",
    categoryLabelAr: "الإنتاجية والقراءة",
    categoryLabelEn: "Productivity",
    requiresProvider: true,
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: true,
    popular: true,
    icon: "🌐",
    gradient: "linear-gradient(135deg, #38BDF8, #818CF8)",
    descAr: "لا ينفذ ترجمة داخلية؛ يوضح نقطة التكامل المطلوبة عند إضافة مزود ترجمة موثوق لاحقًا.",
    descEn: "Does not translate content. It documents the integration point for a future trusted translation provider.",
    permissions: [
      "activeTab (قراءة وترجمة نصوص الصفحة الحالية)",
      "storage (حفظ اللغة المفضلة للترجمة)"
    ],
    codePreview: "window.NexaTranslator.translateDOM({ targetLang: 'ar', preserveLayout: true });"
  },
  {
    id: "ext-json-formatter",
    name: "JSON & API Inspector Pro",
    nameAr: "منسق ومستعرض JSON للمطورين",
    category: "developer",
    categoryLabelAr: "أدوات المطورين",
    categoryLabelEn: "Developer Tools",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: false,
    popular: false,
    icon: "{ }",
    gradient: "linear-gradient(135deg, #06B6D4, #3B82F6)",
    descAr: "ينسق ملفات واستجابات JSON الخام تلقائيًا بألوان Neon واضحة مع إمكانية طي وفتح الكائنات ونسخ المسارات.",
    descEn: "Automatically formats raw JSON responses with syntax highlighting, collapsible trees, and Dark Neon styling.",
    permissions: [
      "activeTab (تحليل وتنسيق مستندات JSON)"
    ],
    codePreview: "if (document.contentType === 'application/json') { formatJsonSyntaxTree(document.body); }"
  },
  {
    id: "ext-super-copy",
    name: "Super Copy & Enable Select",
    nameAr: "فك حظر النسخ وتحديد النصوص",
    category: "productivity",
    categoryLabelAr: "الإنتاجية والقراءة",
    categoryLabelEn: "Productivity",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: false,
    popular: true,
    icon: "📋",
    gradient: "linear-gradient(135deg, #A855F7, #6366F1)",
    descAr: "يفعّل إمكانية تحديد ونسخ النصوص في المواقع التي تمنع النسخ أو تعطّل القائمة المطولة.",
    descEn: "Restores text selection, copy, and long-press context menus on websites that block copying.",
    permissions: [
      "activeTab (إزالة قيود user-select:none وأحداث منع النسخ)"
    ],
    codePreview: "* { user-select: text !important; -webkit-user-select: text !important; } document.oncopy = null;"
  },
  {
    id: "ext-clean-typo",
    name: "ClearType & Reading Enhancer",
    nameAr: "مُحسّن الخطوط العربية والقراءة",
    category: "appearance",
    categoryLabelAr: "المظهر والسمات",
    categoryLabelEn: "Appearance & Themes",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: false,
    popular: false,
    icon: "✨",
    gradient: "linear-gradient(135deg, #14B8A6, #3B82F6)",
    descAr: "يحسّن وضوح الخطوط العربية والإنجليزية على شاشات الهواتف ويزيل التشويش البصري حول المقالات.",
    descEn: "Enhances Arabic & Latin font rendering, line spacing, and contrast across mobile web pages.",
    permissions: [
      "activeTab (تحسين خصائص الخطوط وتنعيم الحواف)"
    ],
    codePreview: "body { -webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility; }"
  },
  {
    id: "ext-userscript-runner",
    name: "Nexa Userscript & WebExt Bridge",
    nameAr: "محرك إضافات Userscripts و WebExtensions",
    category: "userscripts",
    categoryLabelAr: "إضافات وسكربتات مخصصة",
    categoryLabelEn: "Userscripts & Custom",
    version: "1.0.0",
    size: "Built-in",
    rating: null,
    users: null,
    featured: true,
    popular: false,
    icon: "⚡",
    gradient: "linear-gradient(135deg, #F43F5E, #8B5CF6)",
    descAr: "يتيح كتابة وتثبيت سكربتات JavaScript/WebExtensions مخصصة لتعمل تلقائيًا داخل WebView على جميع المواقع.",
    descEn: "Write and execute custom Tampermonkey/WebExtension content scripts directly inside Android WebView.",
    permissions: [
      "activeTab & <all_urls> (تشغيل السكربتات المخصصة على الصفحات)",
      "storage (واجهة chrome.storage.local للإضافات)"
    ],
    codePreview: "// Custom Userscript injected via NexaExtensionRuntime into Android WebView\nconsole.log('Nexa Custom Extension Active on', location.hostname);"
  }
];
