package com.nexabrowser.app.engine;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.content.ContentValues;
import android.os.Environment;
import android.provider.MediaStore;
import android.net.Uri;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import android.os.Build;
import android.util.Base64;
import android.util.DisplayMetrics;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.ConsoleMessage;
import android.webkit.DownloadListener;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.URLUtil;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import com.nexabrowser.app.downloads.NexaDownloadController;
import com.nexabrowser.app.extensions.NexaExtensionRuntime;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.HashSet;
import java.util.Set;

/**
 * Multi-Tab Native WebView Session Manager with Lazy Loading & RAM Hibernation.
 * Docks native Chromium WebViews into the viewport area when browsing live websites,
 * and hibernates background tabs automatically to conserve RAM on mid/low-end devices.
 */
public class TabSessionManager {

    private static final int MAX_LIVE_WEBVIEWS = 5;

    private final String MOBILE_USER_AGENT;
    private final String DESKTOP_USER_AGENT;

    public interface TabEventListener {
        void onTabStateChanged(String tabId, String url, String title, int progress, boolean canGoBack, boolean canGoForward, boolean isSecure);
        void onDownloadTriggered(String url, String fileName, String mimeType, long contentLength, long nativeDownloadId, boolean privateTab);
        void onDangerousSiteBlocked(String tabId, String url);
        void onFindResult(int activeMatchOrdinal, int numberOfMatches);
        void onTabLoadError(String tabId, String url, String description, int errorCode);
        void onWebConsoleMessage(String level, String message, String source, int line);
    }

    private final Activity activity;
    private final FrameLayout viewportContainer;
    private final NexaAdBlockEngine adBlockEngine;
    private final NexaExtensionRuntime extensionRuntime;
    private final NexaDownloadController downloadController;
    private final TabEventListener listener;

    // Access-ordered LRU map for automatic RAM hibernation
    private final LinkedHashMap<String, WebView> liveWebViews = new LinkedHashMap<>(8, 0.75f, true);
    private final Map<String, String> hibernatedUrls = new LinkedHashMap<>();
    private final Map<String, String> tabPreviewsBase64 = new LinkedHashMap<>();
    private final Set<String> privateTabIds = new HashSet<>();
    private final Set<String> errorPageTabIds = new HashSet<>();

    private String activeTabId = null;
    private boolean viewportVisible = false;
    private boolean javascriptEnabled = true;
    private boolean hibernateBackgroundTabs = true;
    private volatile int liveWebViewCount = 0;
    private volatile int hibernatedTabCount = 0;

    public TabSessionManager(
            Activity activity,
            FrameLayout viewportContainer,
            NexaAdBlockEngine adBlockEngine,
            NexaExtensionRuntime extensionRuntime,
            NexaDownloadController downloadController,
            TabEventListener listener) {
        this.activity = activity;
        this.viewportContainer = viewportContainer;
        this.adBlockEngine = adBlockEngine;
        this.extensionRuntime = extensionRuntime;
        this.downloadController = downloadController;
        this.listener = listener;
        String systemAgent;
        try {
            systemAgent = WebSettings.getDefaultUserAgent(activity);
        } catch (Exception e) {
            systemAgent = "Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 Chrome Safari";
        }
        this.MOBILE_USER_AGENT = systemAgent + " NexaBrowser/1.0";
        this.DESKTOP_USER_AGENT = systemAgent.replaceFirst("\\(.*?\\)", "(X11; Linux x86_64)")
                .replace(" Mobile", "")
                .replace("; wv", "") + " NexaBrowser/1.0";
    }

    @SuppressLint("SetJavaScriptEnabled")
    private WebView getOrCreateWebView(final String tabId, final boolean isIncognito) {
        WebView existing = liveWebViews.get(tabId);
        if (existing != null) {
            return existing;
        }

        // Enforce RAM limit by hibernating oldest inactive WebView
        if (hibernateBackgroundTabs && liveWebViews.size() >= MAX_LIVE_WEBVIEWS) {
            Iterator<Map.Entry<String, WebView>> it = liveWebViews.entrySet().iterator();
            while (it.hasNext() && liveWebViews.size() >= MAX_LIVE_WEBVIEWS) {
                Map.Entry<String, WebView> oldest = it.next();
                if (!oldest.getKey().equals(activeTabId)) {
                    WebView victim = oldest.getValue();
                    captureSnapshotInternal(oldest.getKey(), victim);
                    if (victim.getUrl() != null) {
                        hibernatedUrls.put(oldest.getKey(), victim.getUrl());
                    }
                    hibernatedTabCount = hibernatedUrls.size();
                    viewportContainer.removeView(victim);
                    victim.destroy();
                    it.remove();
                    liveWebViewCount = liveWebViews.size();
                }
            }
        }

        final WebView wv = new WebView(activity);
        wv.setBackgroundColor(Color.parseColor("#080C1A"));
        WebSettings settings = wv.getSettings();
        settings.setJavaScriptEnabled(javascriptEnabled);
        settings.setDomStorageEnabled(!isIncognito);
        settings.setDatabaseEnabled(!isIncognito);
        settings.setSupportZoom(true);
        settings.setBuiltInZoomControls(true);
        settings.setDisplayZoomControls(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(false);
        settings.setUserAgentString(MOBILE_USER_AGENT);

        if (isIncognito) {
            settings.setCacheMode(WebSettings.LOAD_NO_CACHE);
            settings.setSaveFormData(false);
        } else {
            settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            settings.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
            CookieManager.getInstance().setAcceptThirdPartyCookies(wv, !isIncognito && !adBlockEngine.isBlockThirdPartyCookiesEnabled());
        }

        wv.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(final WebView view, WebResourceRequest request) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && request != null) {
                    Uri reqUri = request.getUrl();
                    String pageHost = null;
                    try {
                        String current = view.getUrl();
                        if (current != null) pageHost = Uri.parse(current).getHost();
                    } catch (Exception ignored) {
                    }
                    return adBlockEngine.shouldIntercept(reqUri, pageHost);
                }
                return super.shouldInterceptRequest(view, request);
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && request != null && request.getUrl() != null) {
                    String rawUrl = request.getUrl().toString();
                    if (adBlockEngine.isDangerousUrl(rawUrl)) {
                        if (listener != null) {
                            listener.onDangerousSiteBlocked(tabId, rawUrl);
                        }
                        return true;
                    }
                    String cleaned = adBlockEngine.cleanTrackingUrl(rawUrl);
                    if (!cleaned.equals(rawUrl)) {
                        view.loadUrl(cleaned);
                        return true;
                    }
                }
                return false;
            }

            @Override
            public void onPageStarted(WebView view, String url, Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                if (errorPageTabIds.contains(tabId)) {
                    if (url != null && url.startsWith("https://nexa.error.invalid/")) return;
                    errorPageTabIds.remove(tabId);
                }
                notifyTabState(tabId, view, 15);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                if (errorPageTabIds.contains(tabId) || "NexaNetworkError".equals(view.getTitle())) return;
                extensionRuntime.injectActiveExtensions(view);
                captureSnapshotInternal(tabId, view);
                notifyTabState(tabId, view, 100);
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, android.webkit.WebResourceError error) {
                super.onReceivedError(view, request, error);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && request != null && request.isForMainFrame()) {
                    String failedUrl = request.getUrl() != null ? request.getUrl().toString() : (view.getUrl() != null ? view.getUrl() : "");
                    String message = error != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? String.valueOf(error.getDescription()) : "Network error";
                    int code = error != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? error.getErrorCode() : 0;
                    showNetworkError(tabId, view, failedUrl, message, code);
                    if (listener != null) listener.onTabLoadError(tabId, failedUrl, message, code);
                }
            }
        });

        wv.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(final android.webkit.PermissionRequest request) {
                // Site camera/microphone permissions are not wired in this release.
                if (request != null) activity.runOnUiThread(new Runnable() {
                    @Override public void run() { request.deny(); }
                });
            }

            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
                if (activity instanceof com.nexabrowser.app.MainActivity) {
                    return ((com.nexabrowser.app.MainActivity) activity).launchFilePicker(filePathCallback, fileChooserParams);
                }
                filePathCallback.onReceiveValue(null);
                return false;
            }

            @Override
            public void onProgressChanged(WebView view, int newProgress) {
                super.onProgressChanged(view, newProgress);
                if (!errorPageTabIds.contains(tabId) && !"NexaNetworkError".equals(view.getTitle())) {
                    notifyTabState(tabId, view, newProgress);
                }
            }

            @Override
            public void onReceivedTitle(WebView view, String title) {
                super.onReceivedTitle(view, title);
                if (!errorPageTabIds.contains(tabId) && !"NexaNetworkError".equals(title)) {
                    notifyTabState(tabId, view, view.getProgress());
                }
            }

            @Override
            public boolean onConsoleMessage(ConsoleMessage consoleMessage) {
                if (consoleMessage != null && listener != null) {
                    String level = consoleMessage.messageLevel() != null
                            ? consoleMessage.messageLevel().name().toLowerCase(java.util.Locale.US)
                            : "console";
                    listener.onWebConsoleMessage(level, consoleMessage.message(),
                            consoleMessage.sourceId(), consoleMessage.lineNumber());
                }
                return true;
            }
        });

        wv.setDownloadListener(new DownloadListener() {
            @Override
            public void onDownloadStart(String url, String userAgent, String contentDisposition, String mimetype, long contentLength) {
                long dmId = downloadController.enqueueDownload(url, userAgent, contentDisposition, mimetype, !isIncognito);
                if (listener != null) {
                    String fileName = URLUtil.guessFileName(url, contentDisposition, mimetype);
                    listener.onDownloadTriggered(url, fileName, mimetype, contentLength, dmId, isIncognito);
                }
            }
        });

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
            wv.setFindListener(new WebView.FindListener() {
                @Override
                public void onFindResultReceived(int activeMatchOrdinal, int numberOfMatches, boolean isDoneCounting) {
                    if (isDoneCounting && listener != null) {
                        listener.onFindResult(activeMatchOrdinal, numberOfMatches);
                    }
                }
            });
        }

        liveWebViews.put(tabId, wv);
        if (isIncognito) privateTabIds.add(tabId); else privateTabIds.remove(tabId);
        liveWebViewCount = liveWebViews.size();
        hibernatedUrls.remove(tabId);
        hibernatedTabCount = hibernatedUrls.size();
        return wv;
    }

    private void showNetworkError(String tabId, WebView view, String failedUrl, String description, int errorCode) {
        if (view == null) return;
        errorPageTabIds.add(tabId);
        String safeMessage = android.text.Html.escapeHtml(description != null ? description : "Network error");
        String safeUrl = android.text.Html.escapeHtml(failedUrl != null ? failedUrl : "");
        String retryExpression = JSONObject.quote(failedUrl != null ? failedUrl : "").replace("\"", "&quot;");
        String html = "<!doctype html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta charset=\"utf-8\"><title>NexaNetworkError</title>"
                + "<style>body{margin:0;background:#070b19;color:#f8fafc;font:16px system-ui;display:grid;place-items:center;min-height:100vh;padding:24px;box-sizing:border-box}.card{max-width:420px;text-align:center;padding:24px;border:1px solid #23304e;border-radius:24px;background:linear-gradient(145deg,#101936,#0a1025);box-shadow:0 20px 55px #0008}.icon{font-size:34px;color:#38bdf8}h2{font-size:20px;margin:12px 0 6px}p{color:#94a3b8;line-height:1.6;font-size:14px}.url{color:#64748b;font-size:11px;word-break:break-all;margin:16px 0}button{border:0;border-radius:999px;background:linear-gradient(135deg,#00e5ff,#8b5cf6);color:#06101c;font-weight:800;font-size:14px;padding:12px 22px}</style></head>"
                + "<body><main class=\"card\"><div class=\"icon\">◌</div><h2>تعذر تحميل الصفحة</h2><p>تحقق من اتصال الإنترنت ثم حاول مجددًا. لم تُرسل بيانات الصفحة إلى أي جهة أخرى.</p><h2>Unable to load this page</h2><p>Check your internet connection and try again. This browser did not send page data elsewhere.</p><div class=\"url\">" + safeUrl + "</div><p>" + safeMessage + " · " + errorCode + "</p><button onclick=\"location.replace(" + retryExpression + ")\">Try again</button></main></body></html>";
        view.loadDataWithBaseURL("https://nexa.error.invalid/", html, "text/html", "UTF-8", null);
    }

    private void notifyTabState(String tabId, WebView view, int progress) {
        if (listener == null || view == null) return;
        String url = view.getUrl() != null ? view.getUrl() : "";
        String title = view.getTitle() != null ? view.getTitle() : url;
        boolean isSecure = url.startsWith("https://");
        listener.onTabStateChanged(
                tabId,
                url,
                title,
                progress,
                view.canGoBack(),
                view.canGoForward(),
                isSecure
        );
    }

    public void openOrSwitchTab(String tabId, String url, boolean isIncognito, boolean isDesktop) {
        if (tabId == null) return;
        this.activeTabId = tabId;

        for (Map.Entry<String, WebView> entry : liveWebViews.entrySet()) {
            WebView wv = entry.getValue();
            if (!entry.getKey().equals(tabId)) {
                wv.onPause();
                viewportContainer.removeView(wv);
            }
        }

        if (url == null || url.trim().isEmpty() || url.startsWith("nexa://")) {
            setViewportVisible(false, 0, 0);
            return;
        }

        String targetUrl = adBlockEngine.cleanTrackingUrl(url.trim());
        if (adBlockEngine.isDangerousUrl(targetUrl)) {
            if (listener != null) {
                listener.onDangerousSiteBlocked(tabId, targetUrl);
            }
            return;
        }

        WebView activeWv = getOrCreateWebView(tabId, isIncognito);
        activeWv.getSettings().setUserAgentString(isDesktop ? DESKTOP_USER_AGENT : MOBILE_USER_AGENT);
        activeWv.onResume();

        if (activeWv.getParent() != viewportContainer) {
            viewportContainer.removeAllViews();
            viewportContainer.addView(activeWv, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            ));
        }

        String currentUrl = activeWv.getUrl();
        if (currentUrl == null || !currentUrl.equals(targetUrl)) {
            activeWv.loadUrl(targetUrl);
        }
    }

    public void setViewportVisible(boolean visible, int topBarHeightDp, int bottomBarHeightDp) {
        this.viewportVisible = visible;
        if (!visible) {
            viewportContainer.setVisibility(View.GONE);
            WebView active = getActiveWebView();
            if (active != null && activeTabId != null) {
                active.onPause();
                captureSnapshotInternal(activeTabId, active);
            }
            return;
        }

        DisplayMetrics dm = activity.getResources().getDisplayMetrics();
        int topPx = Math.round(topBarHeightDp * dm.density);
        int bottomPx = Math.round(bottomBarHeightDp * dm.density);

        FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) viewportContainer.getLayoutParams();
        if (lp == null) {
            lp = new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
            );
        }
        lp.topMargin = topPx;
        lp.bottomMargin = bottomPx;
        viewportContainer.setLayoutParams(lp);
        viewportContainer.setVisibility(View.VISIBLE);
        viewportContainer.bringToFront();
    }

    public boolean isViewportVisible() {
        return viewportVisible && viewportContainer.getVisibility() == View.VISIBLE;
    }

    public void pauseActiveSession() {
        WebView active = getActiveWebView();
        if (active != null) active.onPause();
    }

    public void resumeActiveSession() {
        if (!isViewportVisible()) return;
        WebView active = getActiveWebView();
        if (active != null) active.onResume();
    }

    public WebView getActiveWebView() {
        if (activeTabId == null) return null;
        return liveWebViews.get(activeTabId);
    }

    public void closeTab(String tabId) {
        if (tabId == null) return;
        hibernatedUrls.remove(tabId);
        privateTabIds.remove(tabId);
        errorPageTabIds.remove(tabId);
        hibernatedTabCount = hibernatedUrls.size();
        synchronized (this) { tabPreviewsBase64.remove(tabId); }
        WebView wv = liveWebViews.remove(tabId);
        liveWebViewCount = liveWebViews.size();
        if (wv != null) {
            viewportContainer.removeView(wv);
            wv.stopLoading();
            wv.loadUrl("about:blank");
            wv.clearHistory();
            wv.destroy();
        }
        if (tabId.equals(activeTabId)) {
            activeTabId = null;
            setViewportVisible(false, 0, 0);
        }
    }

    public void closeAllTabs() {
        for (WebView wv : liveWebViews.values()) {
            viewportContainer.removeView(wv);
            wv.stopLoading();
            wv.destroy();
        }
        liveWebViews.clear();
        hibernatedUrls.clear();
        privateTabIds.clear();
        errorPageTabIds.clear();
        liveWebViewCount = 0;
        hibernatedTabCount = 0;
        synchronized (this) { tabPreviewsBase64.clear(); }
        activeTabId = null;
        setViewportVisible(false, 0, 0);
    }

    public boolean goBackIfPossible() {
        WebView wv = getActiveWebView();
        if (wv != null && wv.canGoBack()) {
            wv.goBack();
            return true;
        }
        return false;
    }

    public boolean goForwardIfPossible() {
        WebView wv = getActiveWebView();
        if (wv != null && wv.canGoForward()) {
            wv.goForward();
            return true;
        }
        return false;
    }

    public void reloadActiveTab() {
        WebView wv = getActiveWebView();
        if (wv != null) {
            wv.reload();
        }
    }

    public void setHibernationEnabled(boolean enabled) {
        this.hibernateBackgroundTabs = enabled;
    }

    public void setDesktopMode(boolean desktop) {
        WebView wv = getActiveWebView();
        if (wv != null) {
            wv.getSettings().setUserAgentString(desktop ? DESKTOP_USER_AGENT : MOBILE_USER_AGENT);
            wv.reload();
        }
    }

    public void setZoomPercent(int zoomPercent) {
        WebView wv = getActiveWebView();
        if (wv != null) {
            int clamped = Math.max(50, Math.min(200, zoomPercent));
            wv.getSettings().setTextZoom(clamped);
        }
    }

    public void setJavaScriptEnabledGlobal(boolean enabled) {
        this.javascriptEnabled = enabled;
        for (WebView wv : liveWebViews.values()) {
            wv.getSettings().setJavaScriptEnabled(enabled);
        }
    }

    public void findInActivePage(String query) {
        WebView wv = getActiveWebView();
        if (wv == null) return;
        if (query == null || query.trim().isEmpty()) {
            wv.clearMatches();
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
            wv.findAllAsync(query.trim());
        }
    }

    public void findNextInActivePage(boolean forward) {
        WebView wv = getActiveWebView();
        if (wv != null) {
            wv.findNext(forward);
        }
    }

    public void clearFindInActivePage() {
        WebView wv = getActiveWebView();
        if (wv != null) {
            wv.clearMatches();
        }
    }

    public void extractReaderModeArticle(final ValueCallback<String> callback) {
        WebView wv = getActiveWebView();
        if (wv == null) {
            callback.onReceiveValue("{}");
            return;
        }
        String js = "(function(){"
                + "try{"
                + "var title=document.title||'';"
                + "var root=document.querySelector('article,main,[role=\"main\"]')||document.body;"
                + "var paras=[];"
                + "root.querySelectorAll('p,h2,h3,blockquote,li').forEach(function(el){"
                + "var t=(el.innerText||'').trim();"
                + "if(t.length>35){paras.push({tag:el.tagName.toLowerCase(),text:t});}"
                + "});"
                + "return JSON.stringify({title:title,url:location.href,site:location.hostname,blocks:paras.slice(0,80)});"
                + "}catch(e){return '{}';}"
                + "})()";
        wv.evaluateJavascript(js, callback);
    }

    public synchronized String getTabPreviewBase64(String tabId) {
        if (tabId == null) return "";
        String cached = tabPreviewsBase64.get(tabId);
        return cached != null ? cached : "";
    }

    private synchronized void captureSnapshotInternal(String tabId, WebView wv) {
        if (wv == null || wv.getWidth() <= 0 || wv.getHeight() <= 0) return;
        try {
            int targetW = 320;
            int targetH = 200;
            Bitmap bmp = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.RGB_565);
            Canvas canvas = new Canvas(bmp);
            float scale = (float) targetW / (float) wv.getWidth();
            canvas.scale(scale, scale);
            wv.draw(canvas);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            bmp.compress(Bitmap.CompressFormat.JPEG, 70, baos);
            bmp.recycle();
            String b64 = "data:image/jpeg;base64," + Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP);
            tabPreviewsBase64.put(tabId, b64);
        } catch (Throwable ignored) {
        }
    }

    /** Applies the latest WebView third-party cookie setting to live sessions. */
    public void applyThirdPartyCookiePolicy() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return;
        CookieManager manager = CookieManager.getInstance();
        for (Map.Entry<String, WebView> entry : liveWebViews.entrySet()) {
            boolean allowThirdParty = !privateTabIds.contains(entry.getKey())
                    && !adBlockEngine.isBlockThirdPartyCookiesEnabled();
            manager.setAcceptThirdPartyCookies(entry.getValue(), allowThirdParty);
        }
    }

    /**
     * Fills the first visible login form only after explicit user confirmation from the UI.
     * Values are safely JSON-escaped and are never logged or persisted by this method.
     */
    public void fillCredentialsIntoActivePage(String username, String password) {
        WebView webView = getActiveWebView();
        if (webView == null) return;
        String user = JSONObject.quote(username != null ? username : "");
        String pass = JSONObject.quote(password != null ? password : "");
        String script = "(function(){try{"
                + "var u=" + user + ",p=" + pass + ";"
                + "var pw=document.querySelector('input[type=password]');"
                + "if(!pw)return false;"
                + "var inputs=[].slice.call(document.querySelectorAll('input:not([type=password])'));"
                + "var userInput=inputs.find(function(x){var s=((x.name||'')+' '+(x.id||'')+' '+(x.autocomplete||'')+' '+(x.type||'')).toLowerCase();return /user|email|login|account/.test(s)&&x.type!=='hidden';});"
                + "function set(el,val){if(!el)return;var proto=el.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;var d=Object.getOwnPropertyDescriptor(proto,'value');if(d&&d.set)d.set.call(el,val);else el.value=val;el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));}"
                + "set(userInput,u);set(pw,p);return true;"
                + "}catch(e){return false;}})()";
        webView.evaluateJavascript(script, null);
    }

    /** Saves a bitmap of the active native WebView into Pictures/NexaBrowser. */
    public void captureActivePageScreenshot(final ValueCallback<String> callback) {
        final WebView webView = getActiveWebView();
        if (webView == null || webView.getWidth() <= 0 || webView.getHeight() <= 0) {
            if (callback != null) callback.onReceiveValue(null);
            return;
        }
        Bitmap bitmap = null;
        OutputStream output = null;
        try {
            int sourceWidth = webView.getWidth();
            int sourceHeight = webView.getHeight();
            float scale = Math.min(1.0f, 1440.0f / Math.max(sourceWidth, sourceHeight));
            int outWidth = Math.max(1, Math.round(sourceWidth * scale));
            int outHeight = Math.max(1, Math.round(sourceHeight * scale));
            bitmap = Bitmap.createBitmap(outWidth, outHeight, Bitmap.Config.RGB_565);
            Canvas canvas = new Canvas(bitmap);
            canvas.scale(scale, scale);
            webView.draw(canvas);

            String fileName = "NexaBrowser_" + System.currentTimeMillis() + ".jpg";
            Uri savedUri;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Images.Media.DISPLAY_NAME, fileName);
                values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
                values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/NexaBrowser");
                savedUri = activity.getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
                if (savedUri == null) throw new IllegalStateException("Could not create MediaStore image");
                output = activity.getContentResolver().openOutputStream(savedUri);
            } else {
                File base = activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES);
                if (base == null) base = activity.getFilesDir();
                File dir = new File(base, "NexaBrowser");
                if (!dir.exists() && !dir.mkdirs()) throw new IllegalStateException("Could not create screenshot directory");
                File file = new File(dir, fileName);
                output = new FileOutputStream(file);
                savedUri = Uri.fromFile(file);
            }
            if (output == null) throw new IllegalStateException("Could not open screenshot output");
            bitmap.compress(Bitmap.CompressFormat.JPEG, 88, output);
            output.flush();
            output.close();
            output = null;
            if (callback != null) callback.onReceiveValue(savedUri.toString());
        } catch (Exception e) {
            if (callback != null) callback.onReceiveValue(null);
        } finally {
            try { if (output != null) output.close(); } catch (Exception ignored) { }
            if (bitmap != null && !bitmap.isRecycled()) bitmap.recycle();
        }
    }

    public String getMemoryStatsJson() {
        try {
            Runtime rt = Runtime.getRuntime();
            long usedMb = (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
            long maxMb = rt.maxMemory() / (1024 * 1024);
            JSONObject obj = new JSONObject();
            obj.put("usedRamMb", usedMb);
            obj.put("maxRamMb", maxMb);
            obj.put("liveWebViews", liveWebViewCount);
            obj.put("hibernatedTabs", hibernatedTabCount);
            return obj.toString();
        } catch (Exception e) {
            return "{}";
        }
    }
}
