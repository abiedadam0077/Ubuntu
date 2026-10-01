package com.nexabrowser.app.vpn;

import android.content.Intent;
import android.net.VpnService;
import android.os.ParcelFileDescriptor;

/**
 * Android VpnService extension point for NexaBrowser.
 * This placeholder deliberately does not create a TUN interface or route traffic. A real
 * WireGuard/OpenVPN client and remote endpoint must be integrated before any tunnel is started.
 */
public class NexaVpnTunnelService extends VpnService {

    public static final String ACTION_CONNECT = "com.nexabrowser.app.vpn.ACTION_CONNECT";
    public static final String ACTION_DISCONNECT = "com.nexabrowser.app.vpn.ACTION_DISCONNECT";
    public static final String EXTRA_SERVER_ENDPOINT = "extra_server_endpoint";
    public static final String EXTRA_DNS_PRIMARY = "extra_dns_primary";

    private ParcelFileDescriptor tunInterface;
    private static volatile boolean serviceRunning = false;

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_DISCONNECT.equals(intent.getAction())) {
            teardownTunnel();
            stopSelf();
            return START_NOT_STICKY;
        }
        // Without a real packet-forwarding backend, never create a TUN device or claim a connection.
        serviceRunning = false;
        stopSelf();
        return START_NOT_STICKY;
    }

    private void teardownTunnel() {
        serviceRunning = false;
        if (tunInterface != null) {
            try {
                tunInterface.close();
            } catch (Exception ignored) {
            }
            tunInterface = null;
        }
    }

    @Override
    public void onRevoke() {
        teardownTunnel();
        super.onRevoke();
    }

    @Override
    public void onDestroy() {
        teardownTunnel();
        super.onDestroy();
    }

    public static boolean isServiceRunning() {
        return serviceRunning;
    }
}
