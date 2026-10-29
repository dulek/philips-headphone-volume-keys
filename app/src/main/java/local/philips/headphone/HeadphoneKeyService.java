/*
 * Copyright 2026 Michał Dulko
 * SPDX-License-Identifier: Apache-2.0
 */
package local.philips.headphone;

import android.accessibilityservice.AccessibilityService;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.util.ArrayList;
import java.util.List;

/** Device-specific volume bridge for Philips TPM171E. No network, polling, or native access. */
public final class HeadphoneKeyService extends AccessibilityService {
    private static final String TAG = "HeadphoneKeyService";
    private static final String SETTINGS = "org.droidtv.settings";
    private static final String SLIDER_ID = "org.droidtv.ui.tvwidget2k15:id/slider1";
    private static final int RC6_UP = 88;
    private static final int RC6_DOWN = 89;
    private static final int HOLD_DELAY_MS = 450;
    private static final int HOLD_STEP_MS = 150;
    private static final int HOLD_MAX_MS = 12000;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private int pending;
    private int heldCode = KeyEvent.KEYCODE_UNKNOWN;
    private boolean opening;
    private long lastPress;
    private long lastLaunch;
    private long holdStarted;
    private final Runnable process = this::processPending;
    private final Runnable close = this::closeIfIdle;
    private final Runnable holdTick = this::advanceHeldKey;

    @Override public void onAccessibilityEvent(AccessibilityEvent event) {
        if (pending != 0 && event.getPackageName() != null
                && SETTINGS.contentEquals(event.getPackageName())) {
            handler.removeCallbacks(process);
            handler.postDelayed(process, 35);
        }
    }

    @Override public void onInterrupt() { }

    @Override public void onDestroy() {
        handler.removeCallbacks(holdTick);
        handler.removeCallbacks(process);
        handler.removeCallbacks(close);
        super.onDestroy();
    }

    @Override protected boolean onKeyEvent(KeyEvent event) {
        int code = event.getKeyCode();
        if (code != KeyEvent.KEYCODE_VOLUME_UP && code != KeyEvent.KEYCODE_VOLUME_DOWN) return false;
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            if (heldCode != code) {
                handler.removeCallbacks(holdTick);
                heldCode = code;
                holdStarted = SystemClock.uptimeMillis();
                queueSteps(code, 1);
                handler.postDelayed(holdTick, HOLD_DELAY_MS);
                Log.i(TAG, "Volume key down: " + code);
            }
        } else if (event.getAction() == KeyEvent.ACTION_UP) {
            if (heldCode == code) {
                heldCode = KeyEvent.KEYCODE_UNKNOWN;
                handler.removeCallbacks(holdTick);
                Log.i(TAG, "Volume key up: " + code);
            }
            scheduleClose();
        }
        return true;
    }

    private void advanceHeldKey() {
        if (heldCode == KeyEvent.KEYCODE_UNKNOWN) return;
        if (SystemClock.uptimeMillis() - holdStarted >= HOLD_MAX_MS) {
            Log.w(TAG, "Stopped held key at safety limit");
            heldCode = KeyEvent.KEYCODE_UNKNOWN;
            scheduleClose();
            return;
        }
        queueSteps(heldCode, 1);
        handler.postDelayed(holdTick, HOLD_STEP_MS);
    }

    private void queueSteps(int code, int amount) {
        int step = code == KeyEvent.KEYCODE_VOLUME_UP ? 1 : -1;
        pending = Math.max(-60, Math.min(60, pending + step * amount));
        lastPress = SystemClock.uptimeMillis();
        handler.removeCallbacks(close);
        handler.removeCallbacks(process);
        handler.post(process);
    }

    private void processPending() {
        if (pending == 0) { scheduleClose(); return; }
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root != null && root.getPackageName() != null
                && SETTINGS.contentEquals(root.getPackageName())) {
            opening = false;
            List<AccessibilityNodeInfo> sliders = root.findAccessibilityNodeInfosByViewId(SLIDER_ID);
            if (!sliders.isEmpty()) {
                AccessibilityNodeInfo slider = sliders.get(0);
                if (!slider.isFocused()) {
                    slider.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
                    handler.postDelayed(process, 110);
                    return;
                }
                int step = pending > 0 ? 1 : -1;
                sendPhilipsKey(step > 0 ? RC6_UP : RC6_DOWN);
                pending -= step;
                handler.postDelayed(process, 120);
                return;
            }
            if (clickHeadphoneRow(root)) {
                handler.postDelayed(process, 120);
                return;
            }
        }
        long now = SystemClock.uptimeMillis();
        if (!opening || now - lastLaunch > 1500) {
            Intent settings = new Intent();
            settings.setComponent(new ComponentName(SETTINGS,
                    "org.droidtv.settings.quicksettings.QuickSettingsActivity"));
            settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            try {
                startActivity(settings);
                opening = true;
                lastLaunch = now;
            } catch (RuntimeException error) {
                Log.e(TAG, "Cannot open Philips quick settings", error);
                pending = 0;
                return;
            }
        }
        handler.postDelayed(process, 150);
    }

    private boolean clickHeadphoneRow(AccessibilityNodeInfo root) {
        String[] names = { "Głośność słuchawek", "Headphone volume", "Headphones volume" };
        for (String name : names) {
            for (AccessibilityNodeInfo node : root.findAccessibilityNodeInfosByText(name)) {
                AccessibilityNodeInfo target = node;
                while (target != null && !target.isClickable()) target = target.getParent();
                if (target != null && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true;
            }
        }
        return false;
    }

    private void sendPhilipsKey(int rc6Code) {
        ArrayList<Integer> codes = new ArrayList<>(1);
        codes.add(rc6Code);
        Intent key = new Intent("org.droidtv.GlobalKey.INJECTKEY");
        key.setComponent(new ComponentName("org.droidtv.GlobalKey",
                "org.droidtv.GlobalKey.InjectKeyReceiver"));
        key.putIntegerArrayListExtra("KEY_CODE", codes);
        sendBroadcast(key);
        Log.i(TAG, "Sent Philips headphone step " + (rc6Code == RC6_UP ? "up" : "down"));
    }

    private void scheduleClose() {
        handler.removeCallbacks(close);
        handler.postDelayed(close, 750);
    }

    private void closeIfIdle() {
        if (heldCode != KeyEvent.KEYCODE_UNKNOWN || pending != 0
                || SystemClock.uptimeMillis() - lastPress < 650) {
            scheduleClose();
            return;
        }
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root != null && root.getPackageName() != null
                && SETTINGS.contentEquals(root.getPackageName())) {
            performGlobalAction(GLOBAL_ACTION_BACK);
        }
        opening = false;
    }
}
