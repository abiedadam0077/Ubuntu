package com.nexabrowser.app.data;

import android.content.Context;
import android.content.SharedPreferences;
import android.webkit.CookieManager;
import android.webkit.WebStorage;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.content.ContentValues;
import java.io.OutputStream;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;

/**
 * Data Repository layer for NexaBrowser.
 * Separates persistent storage (SharedPreferences, Offline Article Files, CookieManager, WebStorage)
 * from UI and WebView presentation logic.
 */
public class NexaRepository {

    private static final String PREFS_NAME = "nexa_browser_core_store";
    private static final String STATE_FILE_NAME = "nexa_state_snapshot.json";

    private final Context context;
    private final SharedPreferences prefs;

    public NexaRepository(Context context) {
        this.context = context.getApplicationContext();
        this.prefs = this.context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    public synchronized boolean saveStateSnapshotJson(String json) {
        if (json == null) return false;
        try {
            File file = new File(context.getFilesDir(), STATE_FILE_NAME);
            FileOutputStream fos = new FileOutputStream(file, false);
            fos.write(json.getBytes(StandardCharsets.UTF_8));
            fos.flush();
            fos.close();
            return true;
        } catch (Exception e) {
            prefs.edit().putString("fallback_state_json", json).apply();
            return false;
        }
    }

    public synchronized String loadStateSnapshotJson() {
        try {
            File file = new File(context.getFilesDir(), STATE_FILE_NAME);
            if (file.exists() && file.length() > 0) {
                FileInputStream fis = new FileInputStream(file);
                byte[] data = new byte[(int) file.length()];
                int read = fis.read(data);
                fis.close();
                if (read > 0) {
                    return new String(data, 0, read, StandardCharsets.UTF_8);
                }
            }
        } catch (Exception ignored) {
        }
        return prefs.getString("fallback_state_json", null);
    }

    public void setPreference(String key, String value) {
        if (key == null) return;
        prefs.edit().putString(key, value != null ? value : "").apply();
    }

    public String getPreference(String key, String defaultValue) {
        if (key == null) return defaultValue;
        return prefs.getString(key, defaultValue);
    }

    /**
     * Writes an export file into Android Downloads/NexaBrowser (API 29+) or the app-specific
     * Download directory on older Android releases without requesting broad storage access.
     */
    public synchronized String exportTextFile(String fileName, String mimeType, String content) {
        if (fileName == null || content == null) return null;
        OutputStream output = null;
        try {
            String cleanName = fileName.replaceAll("[^A-Za-z0-9._-]", "_");
            if (cleanName.isEmpty()) cleanName = "nexabrowser-export.txt";
            Uri uri;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContentValues values = new ContentValues();
                values.put(MediaStore.Downloads.DISPLAY_NAME, cleanName);
                values.put(MediaStore.Downloads.MIME_TYPE, mimeType != null ? mimeType : "text/plain");
                values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/NexaBrowser");
                uri = context.getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                if (uri == null) return null;
                output = context.getContentResolver().openOutputStream(uri);
            } else {
                File base = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS);
                if (base == null) base = context.getFilesDir();
                File dir = new File(base, "NexaBrowser");
                if (!dir.exists() && !dir.mkdirs()) return null;
                File file = new File(dir, cleanName);
                output = new FileOutputStream(file, false);
                uri = Uri.fromFile(file);
            }
            if (output == null) return null;
            output.write(content.getBytes(StandardCharsets.UTF_8));
            output.flush();
            output.close();
            output = null;
            return uri.toString();
        } catch (Exception e) {
            return null;
        } finally {
            try { if (output != null) output.close(); } catch (Exception ignored) { }
        }
    }

    /**
     * Clears native Android browsing data (Cookies, WebStorage DOM storage, Cache files).
     */
    public void clearNativeBrowsingData(boolean clearCookies, boolean clearStorage, boolean clearCache) {
        try {
            if (clearCookies) {
                CookieManager cm = CookieManager.getInstance();
                cm.removeAllCookies(null);
                cm.flush();
            }
            if (clearStorage) {
                WebStorage.getInstance().deleteAllData();
            }
            if (clearCache) {
                deleteDirContents(context.getCacheDir());
            }
        } catch (Exception ignored) {
        }
    }

    private void deleteDirContents(File dir) {
        if (dir == null || !dir.isDirectory()) return;
        File[] children = dir.listFiles();
        if (children == null) return;
        for (File child : children) {
            if (child.isDirectory()) {
                deleteDirContents(child);
            }
            //noinspection ResultOfMethodCallIgnored
            child.delete();
        }
    }
}
