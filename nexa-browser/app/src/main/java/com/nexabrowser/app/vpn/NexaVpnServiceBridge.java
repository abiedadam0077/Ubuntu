package com.nexabrowser.app.vpn;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONObject;

/**
 * VPN Architecture Bridge for NexaBrowser.
 * Stores future endpoint / resolver preferences only and reports the integration status.
 * It never starts a tunnel or claims active IP masking; a real VPN client and backend are absent.
 */
public class NexaVpnServiceBridge {

    private static final String PREFS_NAME = "nexa_vpn_bridge_prefs";
    private static final String KEY_CUSTOM_ENDPOINT = "custom_vpn_endpoint";
    private static final String KEY_CUSTOM_PUBLIC_KEY = "custom_vpn_pubkey";
    private static final String KEY_DOH_RESOLVER = "doh_resolver_url";
    private static final String KEY_SELECTED_REGION = "selected_region_id";

    private final Context context;
    private final SharedPreferences prefs;

    public NexaVpnServiceBridge(Context context) {
        this.context = context.getApplicationContext();
        this.prefs = this.context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    public void saveCustomBackendConfig(String endpoint, String publicKey, String dohResolver) {
        prefs.edit()
                .putString(KEY_CUSTOM_ENDPOINT, endpoint != null ? endpoint.trim() : "")
                .putString(KEY_CUSTOM_PUBLIC_KEY, publicKey != null ? publicKey.trim() : "")
                .putString(KEY_DOH_RESOLVER, dohResolver != null ? dohResolver.trim() : "https://cloudflare-dns.com/dns-query")
                .apply();
    }

    public void setSelectedRegion(String regionId) {
        prefs.edit().putString(KEY_SELECTED_REGION, regionId != null ? regionId : "ch-zurich").apply();
    }

    public boolean hasRealBackendConfigured() {
        String endpoint = prefs.getString(KEY_CUSTOM_ENDPOINT, "");
        return endpoint != null && !endpoint.trim().isEmpty();
    }

    public String getVpnArchitectureStatusJson() {
        try {
            JSONObject obj = new JSONObject();
            String endpoint = prefs.getString(KEY_CUSTOM_ENDPOINT, "");
            boolean hasBackend = endpoint != null && !endpoint.trim().isEmpty();
            obj.put("androidVpnServiceDeclared", true);
            obj.put("hasRemoteBackendEndpointSetting", hasBackend);
            obj.put("activeTunnel", false);
            obj.put("customEndpoint", endpoint);
            obj.put("dohResolverSetting", prefs.getString(KEY_DOH_RESOLVER, "https://cloudflare-dns.com/dns-query"));
            obj.put("selectedRegionPreference", prefs.getString(KEY_SELECTED_REGION, "ch-zurich"));
            obj.put("modeDescription", hasBackend
                    ? "Endpoint saved locally only (no VPN client or active tunnel)"
                    : "VpnService architecture ready — no remote backend or WireGuard server configured");
            return obj.toString();
        } catch (Exception e) {
            return "{}";
        }
    }
}
