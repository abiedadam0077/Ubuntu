package ma.salam.alaikum;

import android.content.Context;
import android.graphics.Typeface;

import java.util.HashMap;
import java.util.Map;

/** Loads and caches the bundled Arabic calligraphy fonts from assets. */
final class FontUtils {

    private static final Map<String, Typeface> CACHE = new HashMap<String, Typeface>();

    private FontUtils() {
    }

    static Typeface get(Context ctx, String assetPath) {
        Typeface tf = CACHE.get(assetPath);
        if (tf == null) {
            tf = Typeface.createFromAsset(ctx.getAssets(), assetPath);
            CACHE.put(assetPath, tf);
        }
        return tf;
    }
}
