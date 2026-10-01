package com.nexabrowser.app;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;
import android.view.Gravity;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;


import com.google.zxing.BinaryBitmap;
import com.google.zxing.DecodeHintType;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.Result;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.PlanarYUVLuminanceSource;

import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Lightweight native QR scanner. Camera permission is requested only after the user
 * taps the QR button. Frames are decoded on a background handler using the ZXing core
 * decoder; no image or scan result is uploaded anywhere.
 */
public class QrScannerActivity extends Activity implements ImageReader.OnImageAvailableListener {

    public static final String EXTRA_RESULT = "com.nexabrowser.app.QR_RESULT";
    private static final int REQUEST_CAMERA = 811;

    private TextureView preview;
    private FrameLayout root;
    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private ImageReader imageReader;
    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private final MultiFormatReader reader = new MultiFormatReader();
    private final AtomicBoolean decoding = new AtomicBoolean(false);
    private volatile boolean finished = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        window.setStatusBarColor(Color.rgb(4, 7, 17));
        window.setNavigationBarColor(Color.rgb(4, 7, 17));
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(4, 7, 17));
        preview = new TextureView(this);
        root.addView(preview, new FrameLayout.LayoutParams(-1, -1));
        buildOverlay();
        setContentView(root);

        Map<DecodeHintType, Object> hints = new EnumMap<>(DecodeHintType.class);
        hints.put(DecodeHintType.POSSIBLE_FORMATS, Arrays.asList(com.google.zxing.BarcodeFormat.QR_CODE));
        hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
        reader.setHints(hints);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.CAMERA}, REQUEST_CAMERA);
        } else {
            startCameraThread();
            preview.post(new Runnable() {
                @Override
                public void run() {
                    if (preview.isAvailable()) openCamera();
                    else preview.setSurfaceTextureListener(surfaceListener);
                }
            });
        }
    }

    private void buildOverlay() {
        TextView close = makeText("×", 34, Color.WHITE, Gravity.CENTER);
        close.setBackgroundColor(Color.TRANSPARENT);
        close.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { finishWith(null); }
        });
        FrameLayout.LayoutParams closeLp = new FrameLayout.LayoutParams(dp(56), dp(56), Gravity.TOP | Gravity.START);
        root.addView(close, closeLp);

        TextView title = makeText("Scan QR code", 17, Color.WHITE, Gravity.CENTER);
        title.setTypeface(null, android.graphics.Typeface.BOLD);
        FrameLayout.LayoutParams titleLp = new FrameLayout.LayoutParams(-1, dp(56), Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        root.addView(title, titleLp);

        View guide = new View(this) {
            private final android.graphics.Paint paint = new android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(android.graphics.Canvas canvas) {
                super.onDraw(canvas);
                float stroke = dp(3);
                float inset = stroke / 2f;
                float w = getWidth(), h = getHeight();
                paint.setStyle(android.graphics.Paint.Style.STROKE);
                paint.setStrokeWidth(stroke);
                paint.setColor(Color.rgb(0, 229, 255));
                canvas.drawRoundRect(inset, inset, w - inset, h - inset, dp(23), dp(23), paint);
                paint.setStyle(android.graphics.Paint.Style.STROKE);
                paint.setStrokeWidth(dp(4));
                paint.setColor(Color.WHITE);
                float corner = dp(28);
                float len = dp(42);
                // Four clean L-shaped framing corners.
                canvas.drawLine(0, corner, 0, 0, paint); canvas.drawLine(0, 0, len, 0, paint);
                canvas.drawLine(w - len, 0, w, 0, paint); canvas.drawLine(w, 0, w, corner, paint);
                canvas.drawLine(0, h - corner, 0, h, paint); canvas.drawLine(0, h, len, h, paint);
                canvas.drawLine(w - len, h, w, h, paint); canvas.drawLine(w, h, w, h - corner, paint);
            }
        };
        FrameLayout.LayoutParams guideLp = new FrameLayout.LayoutParams(dp(272), dp(272), Gravity.CENTER);
        root.addView(guide, guideLp);

        TextView hint = makeText("Align the QR code inside the frame", 14, Color.LTGRAY, Gravity.CENTER);
        FrameLayout.LayoutParams hintLp = new FrameLayout.LayoutParams(-1, dp(62), Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        hintLp.bottomMargin = dp(18);
        root.addView(hint, hintLp);
    }

    private TextView makeText(String text, int sp, int color, int gravity) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(sp);
        view.setTextColor(color);
        view.setGravity(gravity);
        view.setShadowLayer(8, 0, 1, Color.BLACK);
        return view;
    }

    private final TextureView.SurfaceTextureListener surfaceListener = new TextureView.SurfaceTextureListener() {
        @Override public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) { openCamera(); }
        @Override public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) { }
        @Override public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) { return true; }
        @Override public void onSurfaceTextureUpdated(SurfaceTexture surface) { }
    };

    private void startCameraThread() {
        cameraThread = new HandlerThread("NexaQrCamera");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());
    }

    private void openCamera() {
        if (finished || cameraDevice != null) return;
        try {
            CameraManager manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            if (manager == null) { finishWith(null); return; }
            String chosenId = null;
            for (String id : manager.getCameraIdList()) {
                CameraCharacteristics c = manager.getCameraCharacteristics(id);
                Integer facing = c.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) { chosenId = id; break; }
                if (chosenId == null) chosenId = id;
            }
            if (chosenId == null) { finishWith(null); return; }

            CameraCharacteristics characteristics = manager.getCameraCharacteristics(chosenId);
            android.util.Size[] sizes = null;
            android.hardware.camera2.params.StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            if (map != null) sizes = map.getOutputSizes(android.graphics.ImageFormat.YUV_420_888);
            Size selected = chooseSize(sizes);
            int frameWidth = selected != null ? selected.getWidth() : 640;
            int frameHeight = selected != null ? selected.getHeight() : 480;
            imageReader = ImageReader.newInstance(frameWidth, frameHeight, android.graphics.ImageFormat.YUV_420_888, 2);
            imageReader.setOnImageAvailableListener(this, cameraHandler);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) return;
            manager.openCamera(chosenId, new CameraDevice.StateCallback() {
                @Override public void onOpened(CameraDevice camera) {
                    cameraDevice = camera;
                    createPreviewSession();
                }
                @Override public void onDisconnected(CameraDevice camera) { camera.close(); cameraDevice = null; finishWith(null); }
                @Override public void onError(CameraDevice camera, int error) { camera.close(); cameraDevice = null; finishWith(null); }
            }, cameraHandler);
        } catch (Exception e) {
            finishWith(null);
        }
    }

    private Size chooseSize(Size[] sizes) {
        if (sizes == null || sizes.length == 0) return null;
        Size best = null;
        for (Size size : sizes) {
            if (size.getWidth() <= 800 && size.getHeight() <= 600) {
                if (best == null || size.getWidth() * size.getHeight() > best.getWidth() * best.getHeight()) best = size;
            }
        }
        return best != null ? best : sizes[0];
    }

    private void createPreviewSession() {
        try {
            SurfaceTexture texture = preview.getSurfaceTexture();
            if (texture == null || cameraDevice == null || imageReader == null) return;
            texture.setDefaultBufferSize(imageReader.getWidth(), imageReader.getHeight());
            Surface previewSurface = new Surface(texture);
            final CaptureRequest.Builder builder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            builder.addTarget(previewSurface);
            builder.addTarget(imageReader.getSurface());
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
            cameraDevice.createCaptureSession(Arrays.asList(previewSurface, imageReader.getSurface()), new CameraCaptureSession.StateCallback() {
                @Override public void onConfigured(CameraCaptureSession session) {
                    if (cameraDevice == null || finished) return;
                    captureSession = session;
                    try {
                        builder.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
                        session.setRepeatingRequest(builder.build(), null, cameraHandler);
                    } catch (CameraAccessException ignored) { }
                }
                @Override public void onConfigureFailed(CameraCaptureSession session) { finishWith(null); }
            }, cameraHandler);
        } catch (Exception e) {
            finishWith(null);
        }
    }

    @Override
    public void onImageAvailable(ImageReader source) {
        Image image = null;
        try {
            if (finished || !decoding.compareAndSet(false, true)) {
                if (source != null) { Image unused = source.acquireLatestImage(); if (unused != null) unused.close(); }
                return;
            }
            image = source.acquireLatestImage();
            if (image == null) return;
            int width = image.getWidth();
            int height = image.getHeight();
            Image.Plane plane = image.getPlanes()[0];
            ByteBuffer buffer = plane.getBuffer();
            int rowStride = plane.getRowStride();
            int pixelStride = plane.getPixelStride();
            byte[] luminance = new byte[width * height];
            byte[] row = new byte[rowStride];
            for (int y = 0; y < height; y++) {
                int rowStart = y * rowStride;
                buffer.position(rowStart);
                int available = Math.min(rowStride, buffer.remaining());
                buffer.get(row, 0, available);
                int outputOffset = y * width;
                if (pixelStride == 1) {
                    System.arraycopy(row, 0, luminance, outputOffset, Math.min(width, available));
                } else {
                    for (int x = 0; x < width; x++) {
                        int inputIndex = x * pixelStride;
                        if (inputIndex < available) luminance[outputOffset + x] = row[inputIndex];
                    }
                }
            }
            PlanarYUVLuminanceSource sourceData = new PlanarYUVLuminanceSource(luminance, width, height, 0, 0, width, height, false);
            Result result = reader.decodeWithState(new BinaryBitmap(new HybridBinarizer(sourceData)));
            if (result != null && result.getText() != null && !result.getText().trim().isEmpty()) {
                finishWith(result.getText().trim());
            }
        } catch (Exception ignored) {
            reader.reset();
        } finally {
            if (image != null) image.close();
            decoding.set(false);
        }
    }

    private void finishWith(final String value) {
        if (finished) return;
        finished = true;
        runOnUiThread(new Runnable() {
            @Override public void run() {
                if (value != null) {
                    setResult(RESULT_OK, new Intent().putExtra(EXTRA_RESULT, value));
                } else {
                    setResult(RESULT_CANCELED);
                }
                finish();
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_CAMERA && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startCameraThread();
            preview.setSurfaceTextureListener(surfaceListener);
            if (preview.isAvailable()) openCamera();
        } else {
            finishWith(null);
        }
    }

    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

    @Override
    protected void onPause() {
        closeCamera();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (cameraThread == null && preview != null && preview.isAvailable() && !finished
                && (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)) {
            startCameraThread();
            openCamera();
        }
    }

    private void closeCamera() {
        try { if (captureSession != null) { captureSession.close(); captureSession = null; } } catch (Exception ignored) { }
        try { if (cameraDevice != null) { cameraDevice.close(); cameraDevice = null; } } catch (Exception ignored) { }
        try { if (imageReader != null) { imageReader.close(); imageReader = null; } } catch (Exception ignored) { }
        if (cameraThread != null) {
            cameraThread.quitSafely();
            try { cameraThread.join(500); } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
            cameraThread = null;
            cameraHandler = null;
        }
    }

    @Override
    protected void onDestroy() {
        closeCamera();
        super.onDestroy();
    }
}
