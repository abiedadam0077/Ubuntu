package com.nexabrowser.app.downloads;

import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.webkit.CookieManager;
import android.webkit.URLUtil;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Locale;

/**
 * Native Android DownloadManager Controller for NexaBrowser.
 * Supports enqueueing real HTTP/HTTPS file downloads, querying live byte progress,
 * canceling downloads, opening downloaded files, and sharing files.
 */
public class NexaDownloadController {

    private final Context context;
    private final DownloadManager downloadManager;

    public NexaDownloadController(Context context) {
        this.context = context.getApplicationContext();
        this.downloadManager = (DownloadManager) this.context.getSystemService(Context.DOWNLOAD_SERVICE);
    }

    public long enqueueDownload(String url, String userAgent, String contentDisposition, String mimeType) {
        return enqueueDownload(url, userAgent, contentDisposition, mimeType, true);
    }

    public long enqueueDownload(String url, String userAgent, String contentDisposition, String mimeType, boolean allowCookies) {
        if (url == null || url.trim().isEmpty() || downloadManager == null) {
            return -1L;
        }
        try {
            Uri uri = Uri.parse(url.trim());
            String fileName = URLUtil.guessFileName(url, contentDisposition, mimeType);
            if (fileName == null || fileName.trim().isEmpty()) {
                fileName = "nexa_download_" + System.currentTimeMillis();
            }

            DownloadManager.Request request = new DownloadManager.Request(uri);
            if (mimeType != null && !mimeType.isEmpty()) {
                request.setMimeType(mimeType);
            }
            String cookies = allowCookies ? CookieManager.getInstance().getCookie(url) : null;
            if (cookies != null) {
                request.addRequestHeader("Cookie", cookies);
            }
            if (userAgent != null) {
                request.addRequestHeader("User-Agent", userAgent);
            }
            request.setDescription("NexaBrowser Download");
            request.setTitle(fileName);
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);

            return downloadManager.enqueue(request);
        } catch (Exception e) {
            return -1L;
        }
    }

    public boolean cancelNativeDownload(long downloadId) {
        if (downloadManager == null || downloadId <= 0) return false;
        try {
            return downloadManager.remove(downloadId) > 0;
        } catch (Exception e) {
            return false;
        }
    }

    public String queryNativeDownloadStatusJson(long downloadId) {
        if (downloadManager == null || downloadId <= 0) return "{}";
        Cursor cursor = null;
        try {
            DownloadManager.Query query = new DownloadManager.Query();
            query.setFilterById(downloadId);
            cursor = downloadManager.query(query);
            if (cursor != null && cursor.moveToFirst()) {
                int statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS);
                int bytesIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR);
                int totalIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES);
                int titleIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TITLE);
                int uriIdx = cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI);

                int status = statusIdx >= 0 ? cursor.getInt(statusIdx) : 0;
                long downloaded = bytesIdx >= 0 ? cursor.getLong(bytesIdx) : 0L;
                long total = totalIdx >= 0 ? cursor.getLong(totalIdx) : -1L;
                String title = titleIdx >= 0 ? cursor.getString(titleIdx) : "";
                String localUri = uriIdx >= 0 ? cursor.getString(uriIdx) : "";

                JSONObject obj = new JSONObject();
                obj.put("id", downloadId);
                obj.put("status", mapStatus(status));
                obj.put("downloadedBytes", downloaded);
                obj.put("totalBytes", total);
                obj.put("title", title);
                obj.put("localUri", localUri != null ? localUri : "");
                obj.put("category", resolveCategory(title));
                return obj.toString();
            }
        } catch (Exception ignored) {
        } finally {
            if (cursor != null) cursor.close();
        }
        return "{}";
    }

    public boolean openDownloadedFile(long downloadId, String fallbackUrl) {
        try {
            Uri uri = null;
            String mime = "*/*";
            if (downloadManager != null && downloadId > 0) {
                uri = downloadManager.getUriForDownloadedFile(downloadId);
                String detectedMime = downloadManager.getMimeTypeForDownloadedFile(downloadId);
                if (detectedMime != null && !detectedMime.isEmpty()) {
                    mime = detectedMime;
                }
            }
            if (uri == null && fallbackUrl != null && !fallbackUrl.isEmpty()) {
                uri = Uri.parse(fallbackUrl);
            }
            if (uri == null) return false;
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(uri, mime);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            context.startActivity(intent);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public boolean shareNativeDownloadFile(long downloadId, String title) {
        if (downloadManager == null || downloadId <= 0) return false;
        try {
            Uri uri = downloadManager.getUriForDownloadedFile(downloadId);
            if (uri == null) return false;
            String mime = downloadManager.getMimeTypeForDownloadedFile(downloadId);
            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType(mime != null ? mime : "application/octet-stream");
            shareIntent.putExtra(Intent.EXTRA_STREAM, uri);
            if (title != null) shareIntent.putExtra(Intent.EXTRA_SUBJECT, title);
            shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(shareIntent, "Share download");
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(chooser);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public boolean shareDownloadedFile(String title, String urlOrUri) {
        try {
            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, title != null ? title : "NexaBrowser File");
            shareIntent.putExtra(Intent.EXTRA_TEXT, (title != null ? title + "\n" : "") + (urlOrUri != null ? urlOrUri : ""));
            Intent chooser = Intent.createChooser(shareIntent, "Share File");
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(chooser);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static String resolveCategory(String fileName) {
        if (fileName == null) return "other";
        String lower = fileName.toLowerCase(Locale.US);
        if (lower.endsWith(".apk") || lower.endsWith(".xapk") || lower.endsWith(".aab")) return "apk";
        if (lower.endsWith(".zip") || lower.endsWith(".rar") || lower.endsWith(".7z") || lower.endsWith(".tar") || lower.endsWith(".gz")) return "zip";
        if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".webp") || lower.endsWith(".gif") || lower.endsWith(".svg")) return "images";
        if (lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".webm") || lower.endsWith(".mov") || lower.endsWith(".avi")) return "videos";
        if (lower.endsWith(".pdf") || lower.endsWith(".doc") || lower.endsWith(".docx") || lower.endsWith(".xls") || lower.endsWith(".xlsx") || lower.endsWith(".ppt") || lower.endsWith(".txt") || lower.endsWith(".md")) return "documents";
        if (lower.endsWith(".mp3") || lower.endsWith(".wav") || lower.endsWith(".ogg") || lower.endsWith(".flac") || lower.endsWith(".m4a")) return "audio";
        return "other";
    }

    private String mapStatus(int dmStatus) {
        switch (dmStatus) {
            case DownloadManager.STATUS_RUNNING:
                return "downloading";
            case DownloadManager.STATUS_PAUSED:
                return "paused";
            case DownloadManager.STATUS_PENDING:
                return "pending";
            case DownloadManager.STATUS_SUCCESSFUL:
                return "completed";
            case DownloadManager.STATUS_FAILED:
                return "failed";
            default:
                return "unknown";
        }
    }
}
