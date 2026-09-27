package ma.salam.alaikum;

import android.graphics.LinearGradient;
import android.graphics.Shader;
import android.widget.TextView;

/** Small paint effects for the headline text. */
final class TextFx {

    private TextFx() {
    }

    /** Fills the given TextView with a warm vertical gold gradient. */
    static void gold(final TextView t) {
        t.post(new Runnable() {
            @Override
            public void run() {
                int h = t.getHeight() - t.getPaddingTop() - t.getPaddingBottom();
                if (h <= 0) {
                    t.post(this);
                    return;
                }
                t.getPaint().setShader(new LinearGradient(
                        0, 0, 0, h,
                        new int[]{0xFFFFE9AF, 0xFFF7C65C, 0xFFE0930C},
                        new float[]{0f, 0.55f, 1f},
                        Shader.TileMode.CLAMP));
                t.invalidate();
            }
        });
    }
}
