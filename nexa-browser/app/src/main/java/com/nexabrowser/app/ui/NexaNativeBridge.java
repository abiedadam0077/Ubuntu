package com.nexabrowser.app.ui;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;

import com.nexabrowser.app.MainActivity;
import com.nexabrowser.app.data.NexaRepository;
import com.nexabrowser.app.downloads.NexaDownloadController;
import com.nexabrowser.app.engine.NexaAdBlockEngine;
import com.nexabrowser.app.engine.TabSessionManager;
import com.nexabrowser.app.extensions.NexaExtensionRuntime;
import com.nexabrowser.app.security.NexaSecurityVault;
import com.nexabrowser.app.vpn.NexaVpnServiceBridge;

import org.json.JSONObject;

/**
 * JavaScriptInterface Bridge connecting the NexaBrowser UI Shell with
 * Native Android Engines (Multi-WebView TabSessionManager, AdBlockEngine,
 * AES-256 KeyStore Vault, DownloadManager, ExtensionRuntime, VpnServiceBridge).
 */
public class NexaNativeBridge {

    private final MainActivity activity;
    private final TabSessionManager tabSessionManager;
    private final NexaAdBlockEngine adBlockEngine;
    private final NexaExtensionRuntime extensionRuntime;
    private final NexaDownloadController downloadController;
    private final NexaSecurityVault securityVault;
    private final NexaVpnServiceBridge vpnBridge;
    private final NexaRepository repository;

    public NexaNativeBridge(
            MainActivity activity,
            TabSessionManager tabSessionManager,
            NexaAdBlockEngine adBlockEngine,
            NexaExtensionRuntime extensionRuntime,
            NexaDownloadController downloadController,
            NexaSecurityVault securityVault,
            NexaVpnServiceBridge vpnBridge,
            NexaRepository repository) {
        this.activity = activity;
        this.tabSessionManager = tabSessionManager;
        this.adBlockEngine = adBlockEngine;
        this.extensionRuntime = extensionRuntime;
        this.downloadController = downloadController;
        this.securityVault = securityVault;
        this.vpnBridge = vpnBridge;
        this.repository = repository;
    }

    @JavascriptInterface
    public boolean isNativeAndroid() {
        return true;
    }

    @JavascriptInterface
    public void setWebInspectorEnabled(final boolean enabled) {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() { activity.setWebInspectorEnabled(enabled); }
        });
    }

    @JavascriptInterface
    public void startQrScanner() {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() { activity.launchQrScannerOnDemand(); }
        });
    }

    // --- Tab & Native WebView Viewport Controls ---

    @JavascriptInterface
    public void openOrSwitchTab(final String tabId, final String url, final boolean isIncognito, final boolean isDesktop) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.openOrSwitchTab(tabId, url, isIncognito, isDesktop);
            }
        });
    }

    @JavascriptInterface
    public void setViewportVisible(final boolean visible, final int topDp, final int bottomDp) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.setViewportVisible(visible, topDp, bottomDp);
            }
        });
    }

    @JavascriptInterface
    public void closeTab(final String tabId) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.closeTab(tabId);
            }
        });
    }

    @JavascriptInterface
    public void closeAllTabs() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.closeAllTabs();
            }
        });
    }

    @JavascriptInterface
    public void goBack() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.goBackIfPossible();
            }
        });
    }

    @JavascriptInterface
    public void goForward() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.goForwardIfPossible();
            }
        });
    }

    @JavascriptInterface
    public void reload() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.reloadActiveTab();
            }
        });
    }

    @JavascriptInterface
    public void setHibernationEnabled(final boolean enabled) {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() { tabSessionManager.setHibernationEnabled(enabled); }
        });
    }

    @JavascriptInterface
    public void setDesktopMode(final boolean desktop) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.setDesktopMode(desktop);
            }
        });
    }

    @JavascriptInterface
    public void setZoomPercent(final int zoomPercent) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.setZoomPercent(zoomPercent);
            }
        });
    }

    @JavascriptInterface
    public void setJavaScriptEnabled(final boolean enabled) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.setJavaScriptEnabledGlobal(enabled);
            }
        });
    }

    @JavascriptInterface
    public void findInPage(final String query) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.findInActivePage(query);
            }
        });
    }

    @JavascriptInterface
    public void findNext(final boolean forward) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.findNextInActivePage(forward);
            }
        });
    }

    @JavascriptInterface
    public void clearFind() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.clearFindInActivePage();
            }
        });
    }

    @JavascriptInterface
    public void requestReaderArticle() {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tabSessionManager.extractReaderModeArticle(new ValueCallback<String>() {
                    @Override
                    public void onReceiveValue(String value) {
                        activity.dispatchToShellJs("window.__onNativeReaderArticle && window.__onNativeReaderArticle(" + (value != null ? value : "{}") + ");");
                    }
                });
            }
        });
    }

    @JavascriptInterface
    public String getTabPreview(String tabId) {
        return tabSessionManager.getTabPreviewBase64(tabId);
    }

    @JavascriptInterface
    public void fillCredentialOnActiveWebView(final String username, final String password) {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() {
                tabSessionManager.fillCredentialsIntoActivePage(username, password);
            }
        });
    }

    @JavascriptInterface
    public void captureActivePageScreenshot() {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() {
                tabSessionManager.captureActivePageScreenshot(new ValueCallback<String>() {
                    @Override public void onReceiveValue(String value) {
                        if (value != null) {
                            activity.dispatchToShellJs("window.__onNativeScreenshot && window.__onNativeScreenshot(" + JSONObject.quote(value) + ", 'OK');");
                        } else {
                            activity.dispatchToShellJs("window.__onNativeScreenshot && window.__onNativeScreenshot('', 'ERROR');");
                        }
                    }
                });
            }
        });
    }

    @JavascriptInterface
    public String getMemoryStats() {
        return tabSessionManager.getMemoryStatsJson();
    }

    // --- AdBlocker & Privacy Controls ---

    @JavascriptInterface
    public void setAdBlockEnabled(boolean enabled) {
        adBlockEngine.setAdBlockEnabled(enabled);
    }

    @JavascriptInterface
    public void setTrackerBlockEnabled(boolean enabled) {
        adBlockEngine.setTrackerBlockEnabled(enabled);
    }

    @JavascriptInterface
    public void setSafeBrowsingEnabled(boolean enabled) {
        adBlockEngine.setSafeBrowsingEnabled(enabled);
    }

    @JavascriptInterface
    public void setBlockThirdPartyCookies(final boolean enabled) {
        adBlockEngine.setBlockThirdPartyCookies(enabled);
        activity.runOnUiThread(new Runnable() {
            @Override public void run() { tabSessionManager.applyThirdPartyCookiePolicy(); }
        });
    }

    @JavascriptInterface
    public void addWhitelistDomain(String domain) {
        adBlockEngine.addWhitelistDomain(domain);
    }

    @JavascriptInterface
    public void removeWhitelistDomain(String domain) {
        adBlockEngine.removeWhitelistDomain(domain);
    }

    @JavascriptInterface
    public String getNativePrivacyStats() {
        try {
            JSONObject obj = new JSONObject();
            obj.put("adsBlocked", adBlockEngine.getAdsBlockedCount());
            obj.put("trackersBlocked", adBlockEngine.getTrackersBlockedCount());
            obj.put("adBlockEnabled", adBlockEngine.isAdBlockEnabled());
            obj.put("trackerBlockEnabled", adBlockEngine.isTrackerBlockEnabled());
            obj.put("safeBrowsingEnabled", adBlockEngine.isSafeBrowsingEnabled());
            return obj.toString();
        } catch (Exception e) {
            return "{}";
        }
    }

    @JavascriptInterface
    public void clearNativeBrowsingData(final boolean cookies, final boolean storage, final boolean cache) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                repository.clearNativeBrowsingData(cookies, storage, cache);
            }
        });
    }

    // --- Extensions Runtime ---

    @JavascriptInterface
    public void setExtensionEnabled(final String extId, final boolean enabled) {
        extensionRuntime.setExtensionEnabled(extId, enabled);
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (tabSessionManager.getActiveWebView() != null) {
                    extensionRuntime.injectActiveExtensions(tabSessionManager.getActiveWebView());
                }
            }
        });
    }

    @JavascriptInterface
    public void setCustomUserscript(String jsCode) {
        extensionRuntime.setCustomUserscript(jsCode);
    }

    // --- Downloads Controller ---

    @JavascriptInterface
    public String startNativeDownload(String url, String fileName, String mimeType, boolean allowCookies) {
        long id = downloadController.enqueueDownload(url, null, fileName, mimeType, allowCookies);
        return String.valueOf(id);
    }

    @JavascriptInterface
    public String queryNativeDownload(String downloadIdStr) {
        try {
            long id = Long.parseLong(downloadIdStr);
            return downloadController.queryNativeDownloadStatusJson(id);
        } catch (Exception e) {
            return "{}";
        }
    }

    @JavascriptInterface
    public boolean cancelNativeDownload(String downloadIdStr) {
        try {
            long id = Long.parseLong(downloadIdStr);
            return downloadController.cancelNativeDownload(id);
        } catch (Exception e) {
            return false;
        }
    }

    @JavascriptInterface
    public boolean removeNativeDownload(String downloadIdStr) {
        try {
            long id = Long.parseLong(downloadIdStr);
            return downloadController.cancelNativeDownload(id);
        } catch (Exception e) {
            return false;
        }
    }

    @JavascriptInterface
    public boolean openDownloadedFile(String downloadIdStr, String fallbackUrl) {
        long id = -1L;
        try {
            id = Long.parseLong(downloadIdStr);
        } catch (Exception ignored) {
        }
        return downloadController.openDownloadedFile(id, fallbackUrl);
    }

    @JavascriptInterface
    public void shareContent(String title, String textOrUrl) {
        downloadController.shareDownloadedFile(title, textOrUrl);
    }

    @JavascriptInterface
    public boolean shareNativeDownloadFile(String downloadIdStr, String title) {
        try {
            return downloadController.shareNativeDownloadFile(Long.parseLong(downloadIdStr), title);
        } catch (Exception e) {
            return false;
        }
    }

    // --- Security Vault (AES-256-GCM Password Manager) ---

    @JavascriptInterface
    public boolean saveEncryptedVault(String plainJson) {
        return securityVault.saveEncryptedVaultJson(plainJson);
    }

    @JavascriptInterface
    public String loadDecryptedVault() {
        String res = securityVault.loadDecryptedVaultJson();
        return res != null ? res : "";
    }

    @JavascriptInterface
    public boolean hasVaultPinConfigured() {
        return securityVault.hasPinConfigured();
    }

    @JavascriptInterface
    public boolean setVaultPin(String newPin) {
        return securityVault.setVaultPin(newPin);
    }

    @JavascriptInterface
    public boolean verifyVaultPin(String candidatePin) {
        return securityVault.verifyVaultPin(candidatePin);
    }

    @JavascriptInterface
    public boolean isDeviceSecure() {
        return securityVault.isDeviceBiometricOrLockAvailable();
    }

    // --- VPN Architecture Bridge ---

    @JavascriptInterface
    public String getVpnArchitectureStatus() {
        return vpnBridge.getVpnArchitectureStatusJson();
    }

    @JavascriptInterface
    public void saveCustomVpnBackend(String endpoint, String pubKey, String dohUrl) {
        vpnBridge.saveCustomBackendConfig(endpoint, pubKey, dohUrl);
    }

    // --- Data Persistence ---

    @JavascriptInterface
    public boolean saveStateSnapshot(String json) {
        return repository.saveStateSnapshotJson(json);
    }

    @JavascriptInterface
    public String loadStateSnapshot() {
        String s = repository.loadStateSnapshotJson();
        return s != null ? s : "";
    }

    @JavascriptInterface
    public String exportTextFile(String fileName, String mimeType, String content) {
        String uri = repository.exportTextFile(fileName, mimeType, content);
        return uri != null ? uri : "";
    }

    // --- Hardware & System Utilities ---

    @JavascriptInterface
    public void triggerVoiceSearch(final String langTag) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                activity.startVoiceRecognitionOnDemand(langTag);
            }
        });
    }

    @JavascriptInterface
    public void requestCameraPermissionForQr() {
        activity.runOnUiThread(new Runnable() {
            @Override public void run() { activity.launchQrScannerOnDemand(); }
        });
    }

    @JavascriptInterface
    public boolean copyToClipboard(String label, String text) {
        try {
            ClipboardManager cm = (ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
            if (cm != null) {
                cm.setPrimaryClip(ClipData.newPlainText(label != null ? label : "NexaBrowser", text != null ? text : ""));
                return true;
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    @JavascriptInterface
    public void openAppSettings() {
        try {
            Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:" + activity.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception ignored) {
        }
    }

    @JavascriptInterface
    public boolean openInExternalBrowser(String url) {
        try {
            if (url == null || url.trim().isEmpty()) return false;
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url.trim()));
            Intent chooser = Intent.createChooser(intent, "Open with browser");
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(chooser);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    @JavascriptInterface
    public void triggerHaptic(String type) {
        try {
            Vibrator v = (Vibrator) activity.getSystemService(Context.VIBRATOR_SERVICE);
            if (v != null && v.hasVibrator()) {
                long ms = "heavy".equals(type) ? 28L : 12L;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE));
                } else {
                    //noinspection deprecation
                    v.vibrate(ms);
                }
            }
        } catch (Exception ignored) {
        }
    }
}
