package ma.salam.alaikum;

import android.animation.ObjectAnimator;
import android.app.Activity;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.TextView;

public class MainActivity extends Activity {

    private ObjectAnimator hintPulse;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        final View root = findViewById(R.id.root);
        final StarsView sky = (StarsView) findViewById(R.id.sky);
        final TextView salam = (TextView) findViewById(R.id.salam);
        final TextView sub = (TextView) findViewById(R.id.salam_sub);
        final TextView reply = (TextView) findViewById(R.id.reply);
        final TextView hint = (TextView) findViewById(R.id.hint);
        final View div1 = findViewById(R.id.div1);
        final View div2 = findViewById(R.id.div2);
        final float d = getResources().getDisplayMetrics().density;

        Typeface amiri = FontUtils.get(this, "fonts/Amiri-Bold.ttf");
        Typeface cairo = FontUtils.get(this, "fonts/Cairo-Regular.ttf");
        salam.setTypeface(amiri);
        sub.setTypeface(cairo);
        reply.setTypeface(amiri);
        hint.setTypeface(cairo);
        TextFx.gold(salam);

        hideSystemBars();

        // ---- entrance choreography -------------------------------------
        div1.setScaleX(0f);
        div2.setScaleX(0f);
        enter(salam, 250, 44 * d);
        enter(div1, 600, 0);
        enter(sub, 800, 20 * d);
        enter(div2, 1000, 0);
        enter(hint, 1500, 0);

        hintPulse = ObjectAnimator.ofFloat(hint, View.ALPHA, 0.85f, 0.35f);
        hintPulse.setDuration(1600);
        hintPulse.setStartDelay(2600);
        hintPulse.setRepeatCount(ObjectAnimator.INFINITE);
        hintPulse.setRepeatMode(ObjectAnimator.REVERSE);
        hintPulse.start();

        // ---- tap anywhere: the sky answers you back ---------------------
        root.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                    sky.burst(event.getX(), event.getY());
                    sky.ripple(event.getX(), event.getY());
                    showReply(reply);
                    if (hintPulse != null) hintPulse.cancel();
                    hint.animate().alpha(0f).setDuration(300).start();
                    root.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY);
                }
                return false;
            }
        });
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) hideSystemBars();
    }

    private void enter(View v, long delay, float fromY) {
        v.setAlpha(0f);
        v.setTranslationY(fromY);
        v.animate().alpha(1f).translationY(0f).scaleX(1f)
                .setStartDelay(delay)
                .setDuration(700)
                .setInterpolator(new DecelerateInterpolator(1.6f))
                .start();
    }

    private static void showReply(final TextView reply) {
        if (reply.getVisibility() != View.VISIBLE) {
            reply.setVisibility(View.VISIBLE);
            reply.setAlpha(0f);
            reply.setScaleX(0.82f);
            reply.setScaleY(0.82f);
        } else {
            reply.animate().cancel();
            reply.setAlpha(0.55f);
            reply.setScaleX(0.94f);
            reply.setScaleY(0.94f);
        }
        reply.animate().alpha(1f).scaleX(1f).scaleY(1f)
                .setDuration(430)
                .setInterpolator(new OvershootInterpolator(1.5f))
                .start();
    }

    private void hideSystemBars() {
        if (Build.VERSION.SDK_INT >= 30) {
            getWindow().setDecorFitsSystemWindows(false);
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                c.hide(WindowInsets.Type.systemBars());
                c.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        }
    }
}
