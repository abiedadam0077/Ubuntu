package com.nexabrowser.app.engine;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.webkit.WebResourceResponse;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Built-in Native AdBlocker, Anti-Tracker, and Safe Browsing Engine for NexaBrowser.
 * Intercepts WebView network requests in real time via shouldInterceptRequest.
 */
public class NexaAdBlockEngine {

    private static final String PREFS_NAME = "nexa_adblock_prefs";
    private static final String KEY_ADBLOCK_ENABLED = "adblock_enabled";
    private static final String KEY_TRACKER_BLOCK_ENABLED = "tracker_block_enabled";
    private static final String KEY_SAFE_BROWSING_ENABLED = "safe_browsing_enabled";
    private static final String KEY_BLOCK_THIRD_PARTY_COOKIES = "block_third_party_cookies";
    private static final String KEY_ADS_BLOCKED = "ads_blocked_total";
    private static final String KEY_TRACKERS_BLOCKED = "trackers_blocked_total";
    private static final String KEY_WHITELIST = "whitelisted_domains";

    private static final Set<String> AD_DOMAINS = new HashSet<>(Arrays.asList(
            "doubleclick.net", "googlesyndication.com", "googleadservices.com",
            "adservice.google.com", "pagead2.googlesyndication.com", "adnxs.com",
            "taboola.com", "outbrain.com", "criteo.com", "criteo.net",
            "popads.net", "popcash.net", "propellerads.com", "adcolony.com",
            "moatads.com", "rubiconproject.com", "pubmatic.com", "openx.net",
            "advertising.com", "amazon-adsystem.com", "adsrvr.org", "adform.net",
            "casalemedia.com", "contextweb.com", "exoclick.com", "juicyads.com",
            "media.net", "mgid.com", "revcontent.com", "smartadserver.com",
            "sovrn.com", "teads.tv", "unityads.unity3d.com", "vungle.com",
            "yieldmo.com", "zedo.com", "2mdn.net", "admeld.com", "adroll.com",
            "AppNexus.com", "bidswitch.net", "BrightRoll.com", "exponential.com",
            "flashtalking.com", "indexww.com", "lijit.com", "mathtag.com",
            "serving-sys.com", "sharethrough.com", "spotxchange.com", "Tapjoy.com"
    ));

    private static final Set<String> TRACKER_DOMAINS = new HashSet<>(Arrays.asList(
            "google-analytics.com", "ssl.google-analytics.com", "googletagmanager.com",
            "connect.facebook.net", "pixel.facebook.com", "analytics.twitter.com",
            "hotjar.com", "static.hotjar.com", "mixpanel.com", "api.mixpanel.com",
            "segment.io", "api.segment.io", "clarity.ms", "scorecardresearch.com",
            "sb.scorecardresearch.com", "quantserve.com", "pixel.quantserve.com",
            "mouseflow.com", "fullstory.com", "rs.fullstory.com", "newrelic.com",
            "bam.nr-data.net", "bugsnag.com", "sentry.io", "amplitude.com",
            "api.amplitude.com", "chartbeat.com", "static.chartbeat.com",
            "crazyegg.com", "heapanalytics.com", "kissmetrics.com", "loggly.com",
            "omtrdc.net", "pardot.com", "parsely.com", "pingdom.net",
            "quantcount.com", "statcounter.com", "walkme.com", "yandex.ru/metrika"
    ));

    private static final Set<String> TRACKING_PARAMS = new HashSet<>(Arrays.asList(
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "fbclid", "gclid", "msclkid", "mc_eid", "_ga", "yclid", "twclid", "igshid"
    ));

    private final SharedPreferences prefs;
    private volatile boolean adBlockEnabled;
    private volatile boolean trackerBlockEnabled;
    private volatile boolean safeBrowsingEnabled;
    private volatile boolean blockThirdPartyCookies;
    private final AtomicLong adsBlockedCount;
    private final AtomicLong trackersBlockedCount;
    private final Set<String> whitelistedDomains;

    public NexaAdBlockEngine(Context context) {
        this.prefs = context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        this.adBlockEnabled = prefs.getBoolean(KEY_ADBLOCK_ENABLED, true);
        this.trackerBlockEnabled = prefs.getBoolean(KEY_TRACKER_BLOCK_ENABLED, true);
        this.safeBrowsingEnabled = prefs.getBoolean(KEY_SAFE_BROWSING_ENABLED, false);
        this.blockThirdPartyCookies = prefs.getBoolean(KEY_BLOCK_THIRD_PARTY_COOKIES, true);
        this.adsBlockedCount = new AtomicLong(prefs.getLong(KEY_ADS_BLOCKED, 0L));
        this.trackersBlockedCount = new AtomicLong(prefs.getLong(KEY_TRACKERS_BLOCKED, 0L));
        Set<String> savedWhitelist = prefs.getStringSet(KEY_WHITELIST, Collections.<String>emptySet());
        this.whitelistedDomains = Collections.synchronizedSet(new HashSet<>(savedWhitelist));
    }

    /**
     * Checks if a sub-resource request should be blocked by the AdBlocker or Anti-Tracker.
     * Returns an empty WebResourceResponse if blocked, or null to allow normal loading.
     */
    public WebResourceResponse shouldIntercept(Uri requestUri, String pageHost) {
        if (requestUri == null) return null;
        String host = requestUri.getHost();
        if (host == null) return null;
        host = host.toLowerCase(Locale.US);

        if (pageHost != null && isWhitelisted(pageHost)) {
            return null;
        }
        if (isWhitelisted(host)) {
            return null;
        }

        String path = requestUri.getPath() != null ? requestUri.getPath().toLowerCase(Locale.US) : "";

        if (adBlockEnabled && (matchesDomainSet(host, AD_DOMAINS)
                || path.contains("/ads/")
                || path.contains("/adserver")
                || path.contains("/pagead/")
                || path.contains("banner_ad"))) {
            long total = adsBlockedCount.incrementAndGet();
            if (total % 5 == 0) {
                prefs.edit().putLong(KEY_ADS_BLOCKED, total).apply();
            }
            return createEmptyResponse();
        }

        if (trackerBlockEnabled && (matchesDomainSet(host, TRACKER_DOMAINS)
                || path.contains("/collect?")
                || path.contains("/analytics.js")
                || path.contains("/fbevents.js")
                || path.contains("/gtm.js"))) {
            long total = trackersBlockedCount.incrementAndGet();
            if (total % 5 == 0) {
                prefs.edit().putLong(KEY_TRACKERS_BLOCKED, total).apply();
            }
            return createEmptyResponse();
        }

        return null;
    }

    /**
     * Strips known tracking parameters (utm_*, fbclid, gclid, etc.) from a URL when Anti-Tracking is enabled.
     */
    public String cleanTrackingUrl(String rawUrl) {
        if (!trackerBlockEnabled || rawUrl == null || !rawUrl.contains("?")) {
            return rawUrl;
        }
        try {
            Uri uri = Uri.parse(rawUrl);
            if (uri.isOpaque() || isWhitelisted(uri.getHost())) return rawUrl;
            Set<String> names = uri.getQueryParameterNames();
            boolean modified = false;
            Uri.Builder builder = uri.buildUpon().clearQuery();
            for (String name : names) {
                if (TRACKING_PARAMS.contains(name.toLowerCase(Locale.US))) {
                    modified = true;
                    trackersBlockedCount.incrementAndGet();
                } else {
                    for (String val : uri.getQueryParameters(name)) {
                        builder.appendQueryParameter(name, val);
                    }
                }
            }
            return modified ? builder.build().toString() : rawUrl;
        } catch (Exception e) {
            return rawUrl;
        }
    }

    /**
     * Conservative local URL heuristics only. This is NOT a phishing/malware reputation
     * service and intentionally runs disabled until the user enables it.
     */
    public boolean isDangerousUrl(String url) {
        if (!safeBrowsingEnabled || url == null) return false;
        try {
            Uri uri = Uri.parse(url);
            String host = uri.getHost();
            if (host == null) return false;
            String lowerHost = host.toLowerCase(Locale.US);
            String lowerPath = (uri.getPath() != null ? uri.getPath() : "").toLowerCase(Locale.US);
            boolean authPath = lowerPath.contains("login") || lowerPath.contains("signin")
                    || lowerPath.contains("verify") || lowerPath.contains("account")
                    || lowerPath.contains("wallet");
            boolean punycodeHost = lowerHost.startsWith("xn--") || lowerHost.contains(".xn--");
            boolean ipv4Host = lowerHost.matches("[0-9]{1,3}([.][0-9]{1,3}){3}");
            boolean embeddedCredentials = uri.getUserInfo() != null && !uri.getUserInfo().isEmpty();
            return embeddedCredentials || authPath && (punycodeHost || ipv4Host);
        } catch (Exception ignored) {
            return false;
        }
    }

    private boolean matchesDomainSet(String host, Set<String> domainSet) {
        if (domainSet.contains(host)) return true;
        for (String domain : domainSet) {
            if (host.endsWith("." + domain)) {
                return true;
            }
        }
        return false;
    }

    private WebResourceResponse createEmptyResponse() {
        return new WebResourceResponse(
                "text/plain",
                "UTF-8",
                new ByteArrayInputStream("".getBytes(StandardCharsets.UTF_8))
        );
    }

    public boolean isWhitelisted(String domain) {
        if (domain == null) return false;
        String clean = domain.toLowerCase(Locale.US).replaceFirst("^www\\.", "");
        synchronized (whitelistedDomains) {
            if (whitelistedDomains.contains(clean)) return true;
            for (String allowed : whitelistedDomains) {
                if (clean.endsWith("." + allowed)) return true;
            }
        }
        return false;
    }

    public void addWhitelistDomain(String domain) {
        if (domain == null || domain.trim().isEmpty()) return;
        String clean = domain.trim().toLowerCase(Locale.US).replaceFirst("^www\\.", "");
        whitelistedDomains.add(clean);
        persistWhitelist();
    }

    public void removeWhitelistDomain(String domain) {
        if (domain == null) return;
        String clean = domain.trim().toLowerCase(Locale.US).replaceFirst("^www\\.", "");
        whitelistedDomains.remove(clean);
        persistWhitelist();
    }

    private void persistWhitelist() {
        synchronized (whitelistedDomains) {
            prefs.edit().putStringSet(KEY_WHITELIST, new HashSet<>(whitelistedDomains)).apply();
        }
    }

    public void setAdBlockEnabled(boolean enabled) {
        this.adBlockEnabled = enabled;
        prefs.edit().putBoolean(KEY_ADBLOCK_ENABLED, enabled).apply();
    }

    public boolean isAdBlockEnabled() {
        return adBlockEnabled;
    }

    public void setTrackerBlockEnabled(boolean enabled) {
        this.trackerBlockEnabled = enabled;
        prefs.edit().putBoolean(KEY_TRACKER_BLOCK_ENABLED, enabled).apply();
    }

    public boolean isTrackerBlockEnabled() {
        return trackerBlockEnabled;
    }

    public void setSafeBrowsingEnabled(boolean enabled) {
        this.safeBrowsingEnabled = enabled;
        prefs.edit().putBoolean(KEY_SAFE_BROWSING_ENABLED, enabled).apply();
    }

    public boolean isSafeBrowsingEnabled() {
        return safeBrowsingEnabled;
    }

    public void setBlockThirdPartyCookies(boolean enabled) {
        this.blockThirdPartyCookies = enabled;
        prefs.edit().putBoolean(KEY_BLOCK_THIRD_PARTY_COOKIES, enabled).apply();
    }

    public boolean isBlockThirdPartyCookiesEnabled() {
        return blockThirdPartyCookies;
    }

    public long getAdsBlockedCount() {
        return adsBlockedCount.get();
    }

    public long getTrackersBlockedCount() {
        return trackersBlockedCount.get();
    }

    public void syncCountsFromUi(long ads, long trackers) {
        if (ads > adsBlockedCount.get()) {
            adsBlockedCount.set(ads);
        }
        if (trackers > trackersBlockedCount.get()) {
            trackersBlockedCount.set(trackers);
        }
        prefs.edit()
                .putLong(KEY_ADS_BLOCKED, adsBlockedCount.get())
                .putLong(KEY_TRACKERS_BLOCKED, trackersBlockedCount.get())
                .apply();
    }
}
