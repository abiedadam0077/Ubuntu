package com.nexabrowser.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.ValueCallback;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import com.nexabrowser.app.data.NexaRepository;
import com.nexabrowser.app.downloads.NexaDownloadController;
import com.nexabrowser.app.engine.NexaAdBlockEngine;
import com.nexabrowser.app.engine.TabSessionManager;
import com.nexabrowser.app.extensions.NexaExtensionRuntime;
import com.nexabrowser.app.security.NexaSecurityVault;
import com.nexabrowser.app.ui.NexaNativeBridge;
import com.nexabrowser.app.vpn.NexaVpnServiceBridge;

import org.json.JSONObject;
import org.json.JSONArray;

import java.util.ArrayList;
import java.util.Locale;

/**
 * Main Entry Activity for NexaBrowser.
 * Coordinates the Dark Premium Glassmorphic UI Shell and the Native Multi-WebView Viewport,
 * along with on-demand runtime permissions, Voice Search, and external Browser Intent routing.
 */
public class MainActivity extends Activity implements TabSessionManager.TabEventListener {

    private static final int REQ_VOICE_SEARCH = 1001;
    private static final int REQ_PERM_AUDIO = 2001;
    private static final int REQ_PERM_CAMERA = 2002;
    private static final int REQ_QR_SCANNER = 3001;
    private static final int REQ_FILE_PICKER = 4001;

    private FrameLayout rootLayout;
    private WebView shellWebView;
    private FrameLayout contentViewportContainer;

    private NexaRepository repository;
    private NexaSecurityVault securityVault;
    private NexaAdBlockEngine adBlockEngine;
    private NexaExtensionRuntime extensionRuntime;
    private NexaDownloadController downloadController;
    private NexaVpnServiceBridge vpnBridge;
    private TabSessionManager tabSessionManager;
    private String pendingVoiceLang = "ar-SA";
    private ValueCallback<Uri[]> pendingFileChooserCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureSystemBars();

        repository = new NexaRepository(this);
        securityVault = new NexaSecurityVault(this);
        adBlockEngine = new NexaAdBlockEngine(this);
        extensionRuntime = new NexaExtensionRuntime(this);
        downloadController = new NexaDownloadController(this);
        vpnBridge = new NexaVpnServiceBridge(this);

        rootLayout = new FrameLayout(this);
        rootLayout.setBackgroundColor(Color.parseColor("#060913"));

        shellWebView = new WebView(this);
        shellWebView.setBackgroundColor(Color.parseColor("#060913"));

        contentViewportContainer = new FrameLayout(this);
        contentViewportContainer.setBackgroundColor(Color.parseColor("#080C1A"));
        contentViewportContainer.setVisibility(View.GONE);

        rootLayout.addView(shellWebView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        rootLayout.addView(contentViewportContainer, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));

        setContentView(rootLayout);

        tabSessionManager = new TabSessionManager(
                this,
                contentViewportContainer,
                adBlockEngine,
                extensionRuntime,
                downloadController,
                this
        );

        setupShellWebView();
        handleIncomingBrowserIntent(getIntent());
    }

    private void configureSystemBars() {
        try {
            Window window = getWindow();
            if (window != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
                window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
                window.setStatusBarColor(Color.parseColor("#060913"));
                window.setNavigationBarColor(Color.parseColor("#080C1C"));
            }
        } catch (Exception ignored) {
        }
    }

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    private void setupShellWebView() {
        WebSettings settings = shellWebView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setSupportZoom(false);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            boolean optedIn = getSharedPreferences("nexa_devtools_prefs", MODE_PRIVATE).getBoolean("web_inspector_enabled", false);
            boolean debuggableBuild = (getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
            WebView.setWebContentsDebuggingEnabled(debuggableBuild || optedIn);
        }

        NexaNativeBridge bridge = new NexaNativeBridge(
                this,
                tabSessionManager,
                adBlockEngine,
                extensionRuntime,
                downloadController,
                securityVault,
                vpnBridge,
                repository
        );
        shellWebView.addJavascriptInterface(bridge, "NexaNative");

        shellWebView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                handleIncomingBrowserIntent(getIntent());
            }
        });

        shellWebView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
                return launchFilePicker(filePathCallback, fileChooserParams);
            }

            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                // The trusted browser shell uses native, on-demand system flows for QR/voice.
                // Never grant camera, microphone, location, or other WebView permissions implicitly.
                if (request != null) {
                    runOnUiThread(new Runnable() {
                        @Override public void run() { request.deny(); }
                    });
                }
            }
        });

        shellWebView.loadUrl("file:///android_asset/ui/index.html");
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIncomingBrowserIntent(intent);
    }

    private void handleIncomingBrowserIntent(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        if (Intent.ACTION_VIEW.equals(action)) {
            Uri data = intent.getData();
            if (data != null) {
                final String targetUrl = data.toString();
                intent.setData(null);
                dispatchToShellJs("window.__onExternalUrlIntent && window.__onExternalUrlIntent("
                        + JSONObject.quote(targetUrl) + ");");
            }
        }
    }

    public void setWebInspectorEnabled(boolean enabled) {
        getSharedPreferences("nexa_devtools_prefs", MODE_PRIVATE).edit()
                .putBoolean("web_inspector_enabled", enabled).apply();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            boolean debuggableBuild = (getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0;
            WebView.setWebContentsDebuggingEnabled(debuggableBuild || enabled);
        }
    }

    public void dispatchToShellJs(final String script) {
        if (shellWebView == null || script == null) return;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    shellWebView.evaluateJavascript(script, null);
                } else {
                    shellWebView.loadUrl("javascript:" + script);
                }
            }
        });
    }

    // --- On-Demand Permission & Hardware Triggers ---

    public void startVoiceRecognitionOnDemand(String langTag) {
        this.pendingVoiceLang = (langTag != null && !langTag.isEmpty()) ? langTag : Locale.getDefault().toString();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQ_PERM_AUDIO);
                return;
            }
        }
        launchRecognizerIntent(this.pendingVoiceLang);
    }

    private void launchRecognizerIntent(String langTag) {
        try {
            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, langTag);
            intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "NexaBrowser Voice Search");
            startActivityForResult(intent, REQ_VOICE_SEARCH);
        } catch (Exception e) {
            dispatchToShellJs("window.__onNativeVoiceResult && window.__onNativeVoiceResult('', 'UNAVAILABLE');");
        }
    }

    public void launchQrScannerOnDemand() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.CAMERA}, REQ_PERM_CAMERA);
            return;
        }
        startQrScannerActivity();
    }

    private void startQrScannerActivity() {
        try {
            startActivityForResult(new Intent(this, QrScannerActivity.class), REQ_QR_SCANNER);
        } catch (Exception e) {
            dispatchToShellJs("window.__onNativeQrResult && window.__onNativeQrResult('', 'UNAVAILABLE');");
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        boolean granted = grantResults != null && grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED;
        if (requestCode == REQ_PERM_AUDIO) {
            if (granted) {
                launchRecognizerIntent(pendingVoiceLang);
            } else {
                dispatchToShellJs("window.__onNativeVoiceResult && window.__onNativeVoiceResult('', 'PERMISSION_DENIED');");
            }
        } else if (requestCode == REQ_PERM_CAMERA) {
            if (granted) {
                startQrScannerActivity();
            } else {
                dispatchToShellJs("window.__onCameraPermissionResult && window.__onCameraPermissionResult(false);");
            }
        }
    }

    public boolean launchFilePicker(ValueCallback<Uri[]> callback, WebChromeClient.FileChooserParams params) {
        if (pendingFileChooserCallback != null) {
            pendingFileChooserCallback.onReceiveValue(null);
            pendingFileChooserCallback = null;
        }
        pendingFileChooserCallback = callback;
        try {
            Intent picker = params != null ? params.createIntent() : new Intent(Intent.ACTION_OPEN_DOCUMENT);
            picker.addCategory(Intent.CATEGORY_OPENABLE);
            if (picker.getType() == null) picker.setType("*/*");
            startActivityForResult(picker, REQ_FILE_PICKER);
            return true;
        } catch (Exception e) {
            if (pendingFileChooserCallback != null) pendingFileChooserCallback.onReceiveValue(null);
            pendingFileChooserCallback = null;
            return false;
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_VOICE_SEARCH) {
            if (resultCode == RESULT_OK && data != null) {
                ArrayList<String> matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
                if (matches != null && !matches.isEmpty()) {
                    String spoken = matches.get(0);
                    dispatchToShellJs("window.__onNativeVoiceResult && window.__onNativeVoiceResult("
                            + JSONObject.quote(spoken) + ", 'OK');");
                } else {
                    dispatchToShellJs("window.__onNativeVoiceResult && window.__onNativeVoiceResult('', 'NO_MATCH');");
                }
            } else {
                dispatchToShellJs("window.__onNativeVoiceResult && window.__onNativeVoiceResult('', 'CANCELLED');");
            }
        } else if (requestCode == REQ_QR_SCANNER) {
            if (resultCode == RESULT_OK && data != null) {
                String qrValue = data.getStringExtra(QrScannerActivity.EXTRA_RESULT);
                dispatchToShellJs("window.__onNativeQrResult && window.__onNativeQrResult("
                        + JSONObject.quote(qrValue != null ? qrValue : "") + ", 'OK');");
            } else {
                dispatchToShellJs("window.__onNativeQrResult && window.__onNativeQrResult('', 'CANCELLED');");
            }
        } else if (requestCode == REQ_FILE_PICKER) {
            if (pendingFileChooserCallback != null) {
                Uri[] result = WebChromeClient.FileChooserParams.parseResult(resultCode, data);
                pendingFileChooserCallback.onReceiveValue(result);
                pendingFileChooserCallback = null;
            }
        }
    }

    // --- TabSessionManager Callbacks ---

    @Override
    public void onTabStateChanged(String tabId, String url, String title, int progress, boolean canGoBack, boolean canGoForward, boolean isSecure) {
        try {
            JSONObject obj = new JSONObject();
            obj.put("tabId", tabId);
            obj.put("url", url);
            obj.put("title", title);
            obj.put("progress", progress);
            obj.put("canGoBack", canGoBack);
            obj.put("canGoForward", canGoForward);
            obj.put("isSecure", isSecure);
            obj.put("adsBlocked", adBlockEngine.getAdsBlockedCount());
            obj.put("trackersBlocked", adBlockEngine.getTrackersBlockedCount());
            dispatchToShellJs("window.__onNativeTabState && window.__onNativeTabState(" + obj.toString() + ");");
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onDownloadTriggered(String url, String fileName, String mimeType, long contentLength, long nativeDownloadId, boolean privateTab) {
        try {
            JSONObject obj = new JSONObject();
            obj.put("url", url);
            obj.put("fileName", fileName);
            obj.put("mimeType", mimeType);
            obj.put("sizeBytes", contentLength);
            obj.put("nativeDownloadId", String.valueOf(nativeDownloadId));
            obj.put("isPrivate", privateTab);
            dispatchToShellJs("window.__onNativeDownloadStarted && window.__onNativeDownloadStarted(" + obj.toString() + ");");
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onDangerousSiteBlocked(String tabId, String url) {
        dispatchToShellJs("window.__onNativeDangerousSite && window.__onNativeDangerousSite("
                + JSONObject.quote(tabId) + "," + JSONObject.quote(url) + ");");
    }

    @Override
    public void onFindResult(int activeMatchOrdinal, int numberOfMatches) {
        dispatchToShellJs("window.__onNativeFindResult && window.__onNativeFindResult("
                + activeMatchOrdinal + "," + numberOfMatches + ");");
    }

    @Override
    public void onTabLoadError(String tabId, String url, String description, int errorCode) {
        dispatchToShellJs("window.__onNativeTabError && window.__onNativeTabError("
                + JSONObject.quote(tabId) + "," + JSONObject.quote(url) + ","
                + JSONObject.quote(description != null ? description : "") + "," + errorCode + ");");
    }

    @Override
    public void onWebConsoleMessage(String level, String message, String source, int line) {
        dispatchToShellJs("window.__onNativeConsole && window.__onNativeConsole("
                + JSONObject.quote(level != null ? level : "console") + ","
                + JSONObject.quote(message != null ? message : "") + ","
                + JSONObject.quote(source != null ? source : "") + "," + line + ");");
    }

    @Override
    protected void onPause() {
        if (shellWebView != null) dispatchToShellJs("window.__onNativeAppBackground && window.__onNativeAppBackground();");
        if (tabSessionManager != null) tabSessionManager.pauseActiveSession();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (tabSessionManager != null) tabSessionManager.resumeActiveSession();
    }

    @Override
    protected void onDestroy() {
        if (isFinishing() && repository != null) {
            try {
                String snapshot = repository.loadStateSnapshotJson();
                if (snapshot != null) {
                    JSONObject root = new JSONObject(snapshot);
                    JSONObject settings = root.optJSONObject("settings");
                    if (settings != null && settings.optBoolean("closeTabsOnExit", false)) {
                        JSONArray homeTab = new JSONArray();
                        JSONObject tab = new JSONObject();
                        tab.put("id", "tab-home");
                        tab.put("title", "NexaBrowser");
                        tab.put("url", "nexa://home");
                        tab.put("isPrivate", false);
                        tab.put("pinned", false);
                        tab.put("hibernated", false);
                        tab.put("desktopMode", false);
                        tab.put("zoom", 100);
                        homeTab.put(tab);
                        root.put("tabs", homeTab);
                        root.put("activeTabId", "tab-home");
                        repository.saveStateSnapshotJson(root.toString());
                        if (tabSessionManager != null) tabSessionManager.closeAllTabs();
                    }
                }
            } catch (Exception ignored) {
            }
        }
        super.onDestroy();
    }

    @Override
    public void onBackPressed() {
        if (tabSessionManager != null && tabSessionManager.isViewportVisible() && tabSessionManager.goBackIfPossible()) {
            return;
        }
        if (shellWebView != null) {
            shellWebView.evaluateJavascript(
                    "(function(){return window.__handleHardwareBack ? window.__handleHardwareBack() : false;})()",
                    new android.webkit.ValueCallback<String>() {
                        @Override
                        public void onReceiveValue(String value) {
                            if (!"true".equals(value)) {
                                MainActivity.super.onBackPressed();
                            }
                        }
                    }
            );
        } else {
            super.onBackPressed();
        }
    }
}
