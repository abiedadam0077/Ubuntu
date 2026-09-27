package ma.salam.alaikum;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;
import android.view.animation.AnimationUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * The night sky: twinkling stars, an occasional shooting star, and the
 * golden ripple + spark burst that answer the user's touch.
 */
public class StarsView extends View {

    private static final int[] PALETTE = {
            0xFFF8F3E6, 0xFFF8F3E6, 0xFFF8F3E6, 0xFFFFE9AF, 0xFFCBD9FF
    };

    private static final class Star {
        float x, y, r, base, phase, speed;
        int color;
        boolean bright;
    }

    private static final class Shot {
        float x, y, dx, dy, age, ttl;
        final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    }

    private static final class Ripple {
        final float x, y;
        float age;

        Ripple(float x, float y) {
            this.x = x;
            this.y = y;
        }
    }

    private static final class Spark {
        float x, y, vx, vy, age, ttl, size;
        int color;
    }

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bgPaint = new Paint();
    private final Random rnd = new Random();
    private final List<Star> stars = new ArrayList<Star>();
    private final List<Shot> shots = new ArrayList<Shot>();
    private final List<Ripple> ripples = new ArrayList<Ripple>();
    private final List<Spark> sparks = new ArrayList<Spark>();

    private float w, h, density = 1f;
    private double nextShot = 4.0;
    private long lastFrame;
    private boolean running;

    public StarsView(Context context) {
        this(context, null);
    }

    public StarsView(Context context, AttributeSet attrs) {
        super(context, attrs);
        density = getResources().getDisplayMetrics().density;
    }

    @Override
    protected void onSizeChanged(int nw, int nh, int ow, int oh) {
        super.onSizeChanged(nw, nh, ow, oh);
        w = nw;
        h = nh;
        makeStars();
        bgPaint.setShader(new LinearGradient(0, 0, 0, Math.max(1f, h),
                new int[]{0xFF121A3E, 0xFF070B18},
                new float[]{0f, 1f}, Shader.TileMode.CLAMP));
    }

    private void makeStars() {
        stars.clear();
        int count = Math.max(60, Math.min(120,
                (int) (w * h / (140f * 140f * density * density))));
        for (int i = 0; i < count; i++) {
            Star s = new Star();
            s.x = rnd.nextFloat() * w;
            s.y = rnd.nextFloat() * h;
            s.r = (0.7f + rnd.nextFloat() * 1.9f) * density;
            s.base = 0.30f + rnd.nextFloat() * 0.70f;
            s.phase = rnd.nextFloat() * (float) Math.PI * 2f;
            s.speed = 0.35f + rnd.nextFloat() * 1.5f;
            s.color = PALETTE[rnd.nextInt(PALETTE.length)];
            s.bright = rnd.nextFloat() < 0.12f;
            stars.add(s);
        }
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        running = true;
        lastFrame = AnimationUtils.currentAnimationTimeMillis();
        postInvalidateOnAnimation();
    }

    @Override
    protected void onDetachedFromWindow() {
        running = false;
        super.onDetachedFromWindow();
    }

    /** Golden ripple expanding from a tap point. */
    public void ripple(float x, float y) {
        ripples.add(new Ripple(x, y));
    }

    /** A little firework of golden sparks from a tap point. */
    public void burst(float x, float y) {
        for (int i = 0; i < 14; i++) {
            double ang = rnd.nextDouble() * Math.PI * 2;
            double sp = (110 + rnd.nextInt(240)) * density;
            Spark p = new Spark();
            p.x = x;
            p.y = y;
            p.vx = (float) (Math.cos(ang) * sp);
            p.vy = (float) (Math.sin(ang) * sp);
            p.ttl = 0.45f + rnd.nextFloat() * 0.4f;
            p.age = 0f;
            p.size = (1.1f + rnd.nextFloat() * 2.1f) * density;
            p.color = rnd.nextFloat() < 0.7f ? 0xFFE9B35C : 0xFFF8F0DC;
            sparks.add(p);
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        long now = AnimationUtils.currentAnimationTimeMillis();
        float dt = Math.min(0.05f, (now - lastFrame) / 1000f);
        lastFrame = now;
        double t = now / 1000.0;

        paint.setShader(null);
        paint.setStyle(Paint.Style.FILL);
        if (bgPaint.getShader() != null) {
            canvas.drawRect(0, 0, w, h, bgPaint);
        }

        // ---- stars -----------------------------------------------------
        for (int i = 0; i < stars.size(); i++) {
            Star s = stars.get(i);
            float tw = 0.5f + 0.5f * (float) Math.sin(t * s.speed + s.phase);
            int alpha = (int) (255 * s.base * (0.35f + 0.65f * tw));
            paint.setStyle(Paint.Style.FILL);
            paint.setColor((alpha << 24) | (s.color & 0x00FFFFFF));
            canvas.drawCircle(s.x, s.y, s.r * (0.85f + 0.15f * tw), paint);
            if (s.bright) {
                float len = s.r * 4.5f;
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(Math.max(1f, density * 0.8f));
                paint.setAlpha(alpha / 3);
                canvas.drawLine(s.x - len, s.y, s.x + len, s.y, paint);
                canvas.drawLine(s.x, s.y - len, s.x, s.y + len, paint);
            }
        }

        // ---- shooting stars ----------------------------------------------
        if (running && t > nextShot && shots.size() < 2 && w > 0) {
            spawnShot(t);
        }
        for (int i = shots.size() - 1; i >= 0; i--) {
            Shot s = shots.get(i);
            s.age += dt;
            float f = s.age / s.ttl;
            if (f >= 1f) {
                shots.remove(i);
                continue;
            }
            float dist = 1.15f * Math.min(w, h) * f;
            float hx = s.x + s.dx * dist;
            float hy = s.y + s.dy * dist;
            int a = (int) (230 * (float) Math.sin(Math.PI * f));
            s.paint.setAlpha(a);
            canvas.save();
            canvas.translate(hx, hy);
            canvas.rotate((float) Math.toDegrees(Math.atan2(s.dy, s.dx)));
            canvas.drawLine(-90f * density, 0f, 0f, 0f, s.paint);
            canvas.restore();
            paint.setStyle(Paint.Style.FILL);
            paint.setColor((a << 24) | 0x00FFFFFF);
            canvas.drawCircle(hx, hy, 1.6f * density, paint);
        }

        // ---- tap ripples -------------------------------------------------
        for (int i = ripples.size() - 1; i >= 0; i--) {
            Ripple r = ripples.get(i);
            r.age += dt;
            float f = r.age / 0.65f;
            if (f >= 1f) {
                ripples.remove(i);
                continue;
            }
            float e = 1f - (1f - f) * (1f - f);
            int alpha = (int) (170 * (1f - f));
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth((2.4f * (1f - f) + 0.6f) * density);
            paint.setColor((alpha << 24) | 0x00F7C65C);
            canvas.drawCircle(r.x, r.y, e * 120f * density, paint);
        }

        // ---- spark burst ---------------------------------------------------
        for (int i = sparks.size() - 1; i >= 0; i--) {
            Spark p = sparks.get(i);
            p.age += dt;
            float f = p.age / p.ttl;
            if (f >= 1f) {
                sparks.remove(i);
                continue;
            }
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            float drag = Math.max(0f, 1f - 2.4f * dt);
            p.vx *= drag;
            p.vy *= drag;
            int alpha = (int) (255 * (1f - f));
            paint.setStyle(Paint.Style.FILL);
            paint.setColor((alpha << 24) | (p.color & 0x00FFFFFF));
            canvas.drawCircle(p.x, p.y, p.size * (1f - 0.5f * f), paint);
            if (p.size > 2.1f * density) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(density);
                paint.setAlpha(alpha / 3);
                float len = p.size * 3.2f * (1f - f);
                canvas.drawLine(p.x - len, p.y, p.x + len, p.y, paint);
                canvas.drawLine(p.x, p.y - len, p.x, p.y + len, paint);
            }
        }

        if (running) {
            postInvalidateOnAnimation();
        }
    }

    private void spawnShot(double t) {
        nextShot = t + 7 + rnd.nextInt(9);
        Shot s = new Shot();
        boolean fromLeft = rnd.nextBoolean();
        s.x = fromLeft ? w * 0.05f : w * (0.40f + rnd.nextFloat() * 0.55f);
        s.y = h * (0.04f + rnd.nextFloat() * 0.25f);
        float ang = (float) Math.toRadians(
                fromLeft ? (18 + rnd.nextInt(22)) : (140 + rnd.nextInt(22)));
        s.dx = (float) Math.cos(ang);
        s.dy = (float) Math.sin(ang);
        s.ttl = 0.8f + rnd.nextFloat() * 0.5f;
        s.age = 0f;
        float len = 90f * density;
        s.paint.setShader(new LinearGradient(-len, 0, 0, 0,
                new int[]{0x00000000, 0xFFF8F0DC},
                new float[]{0f, 1f}, Shader.TileMode.CLAMP));
        s.paint.setStrokeWidth(1.7f * density);
        s.paint.setStrokeCap(Paint.Cap.ROUND);
        shots.add(s);
    }
}
