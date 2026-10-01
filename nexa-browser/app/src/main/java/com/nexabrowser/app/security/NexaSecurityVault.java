package com.nexabrowser.app.security;

import android.app.KeyguardManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.SecureRandom;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/**
 * On-device Security Vault for NexaBrowser.
 * Encrypts Password Manager credentials locally using an AndroidKeyStore AES-256-GCM key.
 * Never transmits credentials externally without explicit user action.
 */
public class NexaSecurityVault {

    private static final String ANDROID_KEYSTORE = "AndroidKeyStore";
    private static final String KEY_ALIAS = "NexaBrowserMasterVaultKey_v1";
    private static final String AES_MODE = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH = 128;
    private static final String PREFS_NAME = "nexa_security_vault_prefs";
    private static final String KEY_ENCRYPTED_VAULT = "encrypted_vault_payload";
    private static final String KEY_VAULT_IV = "encrypted_vault_iv";
    private static final String KEY_PIN_HASH = "vault_pin_sha256";
    private static final String KEY_PIN_SALT = "vault_pin_salt";
    private static final String KEY_PIN_KDF = "vault_pin_kdf";
    private static final String KEY_PIN_FAILURES = "vault_pin_failures";
    private static final String KEY_PIN_LOCK_UNTIL = "vault_pin_lock_until";
    private static final String KEY_BIOMETRIC_ENABLED = "vault_biometric_enabled";
    private static final int PIN_KDF_ITERATIONS = 150000;
    private static final int PIN_KDF_BITS = 256;

    private final Context context;
    private final SharedPreferences prefs;

    public NexaSecurityVault(Context context) {
        this.context = context.getApplicationContext();
        this.prefs = this.context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        ensureMasterKeyExists();
    }

    private void ensureMasterKeyExists() {
        try {
            KeyStore keyStore = KeyStore.getInstance(ANDROID_KEYSTORE);
            keyStore.load(null);
            if (!keyStore.containsAlias(KEY_ALIAS)) {
                KeyGenerator keyGenerator = KeyGenerator.getInstance(
                        KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE);
                KeyGenParameterSpec spec = new KeyGenParameterSpec.Builder(
                        KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build();
                keyGenerator.init(spec);
                keyGenerator.generateKey();
            }
        } catch (Exception ignored) {
            // Fallback handled gracefully if KeyStore is unavailable on an emulator
        }
    }

    private SecretKey getMasterKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance(ANDROID_KEYSTORE);
        keyStore.load(null);
        return ((KeyStore.SecretKeyEntry) keyStore.getEntry(KEY_ALIAS, null)).getSecretKey();
    }

    /**
     * Encrypts and stores the JSON vault payload using hardware-backed AES-256-GCM.
     */
    public synchronized boolean saveEncryptedVaultJson(String plainJson) {
        if (plainJson == null) plainJson = "[]";
        try {
            SecretKey secretKey = getMasterKey();
            Cipher cipher = Cipher.getInstance(AES_MODE);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey);
            byte[] iv = cipher.getIV();
            byte[] cipherBytes = cipher.doFinal(plainJson.getBytes(StandardCharsets.UTF_8));

            prefs.edit()
                    .putString(KEY_ENCRYPTED_VAULT, Base64.encodeToString(cipherBytes, Base64.NO_WRAP))
                    .putString(KEY_VAULT_IV, Base64.encodeToString(iv, Base64.NO_WRAP))
                    .apply();
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Reads and decrypts the JSON vault payload using hardware-backed AES-256-GCM.
     */
    public synchronized String loadDecryptedVaultJson() {
        String encB64 = prefs.getString(KEY_ENCRYPTED_VAULT, null);
        String ivB64 = prefs.getString(KEY_VAULT_IV, null);
        if (encB64 == null || ivB64 == null) {
            return null;
        }
        try {
            SecretKey secretKey = getMasterKey();
            byte[] cipherBytes = Base64.decode(encB64, Base64.NO_WRAP);
            byte[] iv = Base64.decode(ivB64, Base64.NO_WRAP);

            Cipher cipher = Cipher.getInstance(AES_MODE);
            GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec);
            byte[] plainBytes = cipher.doFinal(cipherBytes);
            return new String(plainBytes, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    public boolean hasPinConfigured() {
        return prefs.contains(KEY_PIN_HASH) && prefs.contains(KEY_PIN_SALT);
    }

    public boolean setVaultPin(String newPin) {
        if (newPin == null || newPin.trim().length() < 6) return false;
        char[] pinChars = newPin.trim().toCharArray();
        try {
            byte[] saltBytes = new byte[16];
            new SecureRandom().nextBytes(saltBytes);
            String salt = Base64.encodeToString(saltBytes, Base64.NO_WRAP);
            String kdf = choosePinKdf();
            byte[] derived = derivePinKey(pinChars, saltBytes, kdf);
            String hash = Base64.encodeToString(derived, Base64.NO_WRAP);
            prefs.edit()
                    .putString(KEY_PIN_SALT, salt)
                    .putString(KEY_PIN_KDF, kdf)
                    .putString(KEY_PIN_HASH, hash)
                    .putInt(KEY_PIN_FAILURES, 0)
                    .putLong(KEY_PIN_LOCK_UNTIL, 0L)
                    .apply();
            java.util.Arrays.fill(pinChars, (char) 0);
            java.util.Arrays.fill(derived, (byte) 0);
            return true;
        } catch (Exception e) {
            java.util.Arrays.fill(pinChars, (char) 0);
            return false;
        }
    }

    public synchronized boolean verifyVaultPin(String candidatePin) {
        if (candidatePin == null) return false;
        long now = System.currentTimeMillis();
        if (now < prefs.getLong(KEY_PIN_LOCK_UNTIL, 0L)) return false;
        String salt = prefs.getString(KEY_PIN_SALT, null);
        String expectedHash = prefs.getString(KEY_PIN_HASH, null);
        if (salt == null || expectedHash == null || candidatePin.trim().length() < 6) return false;
        char[] pinChars = candidatePin.trim().toCharArray();
        byte[] candidate = null;
        try {
            byte[] saltBytes = Base64.decode(salt, Base64.NO_WRAP);
            String kdf = prefs.getString(KEY_PIN_KDF, "PBKDF2WithHmacSHA1");
            candidate = derivePinKey(pinChars, saltBytes, kdf);
            byte[] expected = Base64.decode(expectedHash, Base64.NO_WRAP);
            boolean valid = MessageDigest.isEqual(candidate, expected);
            if (valid) {
                prefs.edit().putInt(KEY_PIN_FAILURES, 0).putLong(KEY_PIN_LOCK_UNTIL, 0L).apply();
                return true;
            }
            int failures = prefs.getInt(KEY_PIN_FAILURES, 0) + 1;
            SharedPreferences.Editor edit = prefs.edit().putInt(KEY_PIN_FAILURES, failures);
            if (failures >= 5) {
                int exponent = Math.min(6, failures - 5);
                long lockMillis = Math.min(30L * 60L * 1000L, 30L * 1000L * (1L << exponent));
                edit.putLong(KEY_PIN_LOCK_UNTIL, now + lockMillis);
            }
            edit.apply();
            return false;
        } catch (Exception e) {
            return false;
        } finally {
            java.util.Arrays.fill(pinChars, (char) 0);
            if (candidate != null) java.util.Arrays.fill(candidate, (byte) 0);
        }
    }

    private String choosePinKdf() {
        try {
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
            return "PBKDF2WithHmacSHA256";
        } catch (Exception ignored) {
            return "PBKDF2WithHmacSHA1";
        }
    }

    private byte[] derivePinKey(char[] pin, byte[] salt, String algorithm) throws Exception {
        PBEKeySpec spec = new PBEKeySpec(pin, salt, PIN_KDF_ITERATIONS, PIN_KDF_BITS);
        try {
            return SecretKeyFactory.getInstance(algorithm).generateSecret(spec).getEncoded();
        } finally {
            spec.clearPassword();
        }
    }

    public boolean isDeviceBiometricOrLockAvailable() {
        try {
            KeyguardManager km = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return km.isDeviceSecure();
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    public void setBiometricEnabled(boolean enabled) {
        prefs.edit().putBoolean(KEY_BIOMETRIC_ENABLED, enabled).apply();
    }

    public boolean isBiometricEnabled() {
        return prefs.getBoolean(KEY_BIOMETRIC_ENABLED, true);
    }

    private String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return Base64.encodeToString(hash, Base64.NO_WRAP);
        } catch (Exception e) {
            return "";
        }
    }
}
