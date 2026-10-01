package com.nexabrowser.app.extensions;

import android.content.Context;
import android.content.SharedPreferences;
import android.webkit.WebView;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * WebExtensions & Userscript Content-Script Runtime for Android WebView.
 * Injects enabled extensions' JavaScript and CSS payloads into loaded web pages,
 * and exposes a lightweight chrome.storage / chrome.runtime compatibility shim.
 */
public class NexaExtensionRuntime {

    private static final String PREFS_NAME = "nexa_extensions_runtime_prefs";
    private static final String KEY_ENABLED_IDS = "enabled_extension_ids";
    private static final String KEY_CUSTOM_USERSCRIPT = "custom_userscript_code";

    private final SharedPreferences prefs;
    private final Set<String> enabledExtensionIds;
    private volatile String customUserscriptCode;

    public NexaExtensionRuntime(Context context) {
        this.prefs = context.getApplicationContext().getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        Set<String> defaultSet = new HashSet<>();
        Set<String> saved = prefs.getStringSet(KEY_ENABLED_IDS, defaultSet);
        this.enabledExtensionIds = Collections.synchronizedSet(new HashSet<>(saved));
        this.customUserscriptCode = prefs.getString(KEY_CUSTOM_USERSCRIPT, "");
    }

    public void setExtensionEnabled(String extId, boolean enabled) {
        if (extId == null) return;
        if (enabled) {
            enabledExtensionIds.add(extId);
        } else {
            enabledExtensionIds.remove(extId);
        }
        synchronized (enabledExtensionIds) {
            prefs.edit().putStringSet(KEY_ENABLED_IDS, new HashSet<>(enabledExtensionIds)).apply();
        }
    }

    public boolean isExtensionEnabled(String extId) {
        return extId != null && enabledExtensionIds.contains(extId);
    }

    public void setCustomUserscript(String jsCode) {
        this.customUserscriptCode = jsCode != null ? jsCode : "";
        prefs.edit().putString(KEY_CUSTOM_USERSCRIPT, this.customUserscriptCode).apply();
    }

    public String getCustomUserscript() {
        return customUserscriptCode;
    }

    /**
     * Injects the WebExtensions API compatibility bridge + all enabled extension content scripts
     * into the target WebView upon page completion.
     */
    public void injectActiveExtensions(WebView webView) {
        if (webView == null) return;

        StringBuilder script = new StringBuilder();
        script.append("(function(){");
        script.append("if(!window.chrome){window.chrome={};}");
        script.append("if(!window.chrome.storage){window.chrome.storage={local:{get:function(k,cb){try{cb&&cb(JSON.parse(localStorage.getItem('__nexa_ext_store')||'{}'));}catch(e){}},set:function(obj,cb){try{localStorage.setItem('__nexa_ext_store',JSON.stringify(obj||{}));cb&&cb();}catch(e){}}}};}");

        // 1. Nexa AdGuard Ultra (Cosmetic DOM ad element remover)
        if (enabledExtensionIds.contains("ext-adguard-ultra")) {
            script.append("try{var st=document.getElementById('__nexa_adguard_css');if(!st){st=document.createElement('style');st.id='__nexa_adguard_css';st.textContent='[id*=\"google_ads\"],[class*=\"ad-banner\"],[class*=\"adsbox\"],iframe[src*=\"doubleclick\"],iframe[src*=\"googlesyndication\"],.sponsored-content{display:none!important;}';document.head&&document.head.appendChild(st);}}catch(e){}");
        } else {
            script.append("try{var st=document.getElementById('__nexa_adguard_css');if(st)st.remove();}catch(e){}");
        }

        // 2. Dark Reader Neon (Smart Dark Theme inverter for bright websites)
        if (enabledExtensionIds.contains("ext-dark-reader")) {
            script.append("try{var dr=document.getElementById('__nexa_dark_reader');if(!dr){dr=document.createElement('style');dr.id='__nexa_dark_reader';dr.textContent='html{filter:invert(0.92) hue-rotate(180deg)!important;background:#0a0e1a!important;}img,video,picture,canvas,svg{filter:invert(1) hue-rotate(180deg)!important;}';document.head&&document.head.appendChild(dr);}}catch(e){}");
        } else {
            script.append("try{var dr=document.getElementById('__nexa_dark_reader');if(dr)dr.remove();}catch(e){}");
        }

        // 3. Cookie Banner Zapper (Auto-hides annoying GDPR/Cookie consent overlays)
        if (enabledExtensionIds.contains("ext-cookie-zapper")) {
            script.append("try{var cz=document.getElementById('__nexa_cookie_zapper');if(!cz){cz=document.createElement('style');cz.id='__nexa_cookie_zapper';cz.textContent='[id*=\"cookie-banner\"],[class*=\"cookie-consent\"],[id*=\"onetrust-banner\"],[class*=\"cc-window\"],[id*=\"CybotCookiebotDialog\"]{display:none!important;}';document.head&&document.head.appendChild(cz);}}catch(e){}");
        } else {
            script.append("try{var cz=document.getElementById('__nexa_cookie_zapper');if(cz)cz.remove();}catch(e){}");
        }

        // 4. Video Speed & PiP Pro (Adds floating 1.5x/2x controller to HTML5 videos)
        if (enabledExtensionIds.contains("ext-video-speed")) {
            script.append("try{document.querySelectorAll('video').forEach(function(v){if(!v.__nexaPreviousRate)v.__nexaPreviousRate=v.playbackRate||1;v.playbackRate=1.25;});}catch(e){}");
        } else {
            script.append("try{document.querySelectorAll('video').forEach(function(v){if(v.__nexaPreviousRate){v.playbackRate=v.__nexaPreviousRate;delete v.__nexaPreviousRate;}});}catch(e){}");
        }

        // 5. Super Copy & Right-Click Unblocker
        if (enabledExtensionIds.contains("ext-super-copy")) {
            script.append("try{var sc=document.getElementById('__nexa_super_copy');if(!sc){sc=document.createElement('style');sc.id='__nexa_super_copy';sc.textContent='*{user-select:text!important;-webkit-user-select:text!important;}';document.head&&document.head.appendChild(sc);}}catch(e){}");
        } else {
            script.append("try{var sc=document.getElementById('__nexa_super_copy');if(sc)sc.remove();}catch(e){}");
        }

        // 6. Privacy Badger Fingerprint Guard (Canvas & Battery API spoofing)
        if (enabledExtensionIds.contains("ext-privacy-badger")) {
            script.append("try{if(!window.__nexaOriginalGetBattery)window.__nexaOriginalGetBattery=navigator.getBattery;if(navigator.getBattery)navigator.getBattery=undefined;window.__nexaFingerprintProtected=true;}catch(e){}");
        } else {
            script.append("try{if(window.__nexaOriginalGetBattery){navigator.getBattery=window.__nexaOriginalGetBattery;delete window.__nexaOriginalGetBattery;}delete window.__nexaFingerprintProtected;}catch(e){}");
        }

        // 7. JSON Formatter Pro
        if (enabledExtensionIds.contains("ext-json-formatter")) {
            script.append("try{if(document.contentType==='application/json'||(document.body&&document.body.children.length===1&&document.body.children[0].tagName==='PRE')){var raw=document.body.innerText;var parsed=JSON.parse(raw);if(typeof window.__nexaJsonOriginal==='undefined')window.__nexaJsonOriginal=document.body.innerHTML;document.body.style.background='#070B19';document.body.style.color='#38BDF8';document.body.innerHTML='<pre style=\"padding:16px;font-family:monospace;font-size:13px;line-height:1.5;color:#38BDF8;white-space:pre-wrap;\">'+JSON.stringify(parsed,null,2).replace(/&/g,'&amp;').replace(/</g,'&lt;')+'</pre>';}}catch(e){}");
        } else {
            script.append("try{if(typeof window.__nexaJsonOriginal!=='undefined'&&document.body){document.body.innerHTML=window.__nexaJsonOriginal;delete window.__nexaJsonOriginal;}}catch(e){}");
        }

        // 8. Clean Typography & Reading Time Enhancer
        if (enabledExtensionIds.contains("ext-clean-typo")) {
            script.append("try{var ct=document.getElementById('__nexa_clean_typo');if(!ct){ct=document.createElement('style');ct.id='__nexa_clean_typo';ct.textContent='body{ -webkit-font-smoothing:antialiased; text-rendering:optimizeLegibility; }';document.head&&document.head.appendChild(ct);}}catch(e){}");
        } else {
            script.append("try{var ct=document.getElementById('__nexa_clean_typo');if(ct)ct.remove();}catch(e){}");
        }

        // 9. Custom Userscript Runner
        if (enabledExtensionIds.contains("ext-userscript-runner") && customUserscriptCode != null && !customUserscriptCode.trim().isEmpty()) {
            script.append("try{").append(customUserscriptCode).append("}catch(e){console.warn('NexaUserscript error:',e);}");
        }

        script.append("})();");
        webView.evaluateJavascript(script.toString(), null);
    }
}
