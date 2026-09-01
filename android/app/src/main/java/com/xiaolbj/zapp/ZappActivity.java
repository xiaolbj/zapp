package com.xiaolbj.zapp;

import android.app.NativeActivity;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

public final class ZappActivity extends NativeActivity {
    private ImeBridgeView imeBridgeView;

    private static native void nativeCompositionChanged(String text);
    private static native void nativeCompositionCommitted(String text);
    private static native void nativeCompositionCancelled();
    private static native void nativeBackspace(int count);
    private static native void nativeSubmit();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        imeBridgeView = new ImeBridgeView();
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(1, 1);
        params.gravity = Gravity.TOP | Gravity.START;
        addContentView(imeBridgeView, params);
    }

    @SuppressWarnings("unused") // Called through JNI from android_bridge.c.
    public void setImeVisibleFromNative(boolean visible) {
        runOnUiThread(() -> {
            if (imeBridgeView == null) return;
            InputMethodManager manager = (InputMethodManager)getSystemService(INPUT_METHOD_SERVICE);
            if (visible) {
                imeBridgeView.requestFocus();
                imeBridgeView.post(() -> {
                    manager.restartInput(imeBridgeView);
                    manager.showSoftInput(imeBridgeView, InputMethodManager.SHOW_IMPLICIT);
                });
            } else {
                manager.hideSoftInputFromWindow(imeBridgeView.getWindowToken(), 0);
                imeBridgeView.clearFocus();
            }
        });
    }

    private final class ImeBridgeView extends View {
        ImeBridgeView() {
            super(ZappActivity.this);
            setFocusable(true);
            setFocusableInTouchMode(true);
            setBackgroundColor(0x00000000);
            setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
        }

        @Override
        public boolean onCheckIsTextEditor() {
            return true;
        }

        @Override
        public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
            outAttrs.inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES;
            outAttrs.imeOptions = EditorInfo.IME_ACTION_DONE | EditorInfo.IME_FLAG_NO_EXTRACT_UI;
            return new BridgeInputConnection(this);
        }
    }

    private static final class BridgeInputConnection extends BaseInputConnection {
        private String composingText;
        private boolean committing;

        BridgeInputConnection(View targetView) {
            super(targetView, true);
        }

        @Override
        public boolean setComposingText(CharSequence text, int newCursorPosition) {
            composingText = text == null ? "" : text.toString();
            nativeCompositionChanged(composingText);
            return super.setComposingText(text, newCursorPosition);
        }

        @Override
        public boolean commitText(CharSequence text, int newCursorPosition) {
            String committed = text == null ? "" : text.toString();
            committing = true;
            boolean result = super.commitText(text, newCursorPosition);
            committing = false;
            composingText = null;
            nativeCompositionCommitted(committed);
            return result;
        }

        @Override
        public boolean finishComposingText() {
            boolean result = super.finishComposingText();
            if (!committing && composingText != null && !composingText.isEmpty()) {
                nativeCompositionCommitted(composingText);
            } else if (!committing && composingText != null) {
                nativeCompositionCancelled();
            }
            composingText = null;
            return result;
        }

        @Override
        public boolean deleteSurroundingText(int beforeLength, int afterLength) {
            if (beforeLength > 0) nativeBackspace(beforeLength);
            return super.deleteSurroundingText(beforeLength, afterLength);
        }

        @Override
        public boolean sendKeyEvent(KeyEvent event) {
            if (event.getAction() != KeyEvent.ACTION_DOWN) return true;
            if (event.getKeyCode() == KeyEvent.KEYCODE_DEL) {
                nativeBackspace(1);
                return true;
            }
            if (event.getKeyCode() == KeyEvent.KEYCODE_ENTER) {
                nativeSubmit();
                return true;
            }
            int codePoint = event.getUnicodeChar();
            if (codePoint >= 32 && Character.isValidCodePoint(codePoint)) {
                nativeCompositionCommitted(new String(Character.toChars(codePoint)));
                return true;
            }
            return super.sendKeyEvent(event);
        }

        @Override
        public boolean performEditorAction(int actionCode) {
            nativeSubmit();
            return true;
        }
    }
}
