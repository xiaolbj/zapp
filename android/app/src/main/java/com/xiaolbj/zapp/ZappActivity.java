package com.xiaolbj.zapp;

import android.Manifest;
import android.app.NativeActivity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.util.SparseArray;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

public final class ZappActivity extends NativeActivity {
    private static final int PERMISSION_CAMERA = 0;
    private static final int PERMISSION_MICROPHONE = 1;
    private static final int PERMISSION_NOTIFICATIONS = 2;
    private static final int PERMISSION_MEDIA = 3;
    private static final int FIRST_PERMISSION_REQUEST_CODE = 4100;
    private static final int FILE_PICKER_REQUEST_CODE = 7301;

    private final SparseArray<PermissionRequest> pendingPermissionRequests = new SparseArray<>();
    private ImeBridgeView imeBridgeView;
    private int nextPermissionRequestCode = FIRST_PERMISSION_REQUEST_CODE;
    private long pendingFileRequestId;

    static {
        // Associate the NativeActivity library with this application's class loader
        // so exported JNI methods can be resolved from ZappActivity.
        System.loadLibrary("zapp");
    }

    private static native void nativeCompositionChanged(String text);
    private static native void nativeCompositionCommitted(String text);
    private static native void nativeCompositionCancelled();
    private static native void nativeBackspace(int count);
    private static native void nativeSubmit();
    private static native void nativePermissionResult(long requestId, int permission, boolean granted);
    private static native void nativeFileSelected(long requestId, String uri);
    private static native void nativeFileSelectionCancelled(long requestId);

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
            if (manager == null) return;
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

    @SuppressWarnings("unused") // Called through JNI from android_bridge.c.
    public void requestPermissionFromNative(long requestId, int permission) {
        runOnUiThread(() -> requestPermissionOnUiThread(requestId, permission));
    }

    private void requestPermissionOnUiThread(long requestId, int permission) {
        if (permission == PERMISSION_NOTIFICATIONS && Build.VERSION.SDK_INT < 33) {
            nativePermissionResult(requestId, permission, true);
            return;
        }

        String[] androidPermissions;
        switch (permission) {
            case PERMISSION_CAMERA:
                androidPermissions = new String[]{Manifest.permission.CAMERA};
                break;
            case PERMISSION_MICROPHONE:
                androidPermissions = new String[]{Manifest.permission.RECORD_AUDIO};
                break;
            case PERMISSION_NOTIFICATIONS:
                androidPermissions = new String[]{Manifest.permission.POST_NOTIFICATIONS};
                break;
            case PERMISSION_MEDIA:
                if (Build.VERSION.SDK_INT >= 34) {
                    androidPermissions = new String[]{
                        Manifest.permission.READ_MEDIA_IMAGES,
                        Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
                    };
                } else if (Build.VERSION.SDK_INT >= 33) {
                    androidPermissions = new String[]{Manifest.permission.READ_MEDIA_IMAGES};
                } else {
                    androidPermissions = new String[]{Manifest.permission.READ_EXTERNAL_STORAGE};
                }
                break;
            default:
                nativePermissionResult(requestId, permission, false);
                return;
        }

        for (String androidPermission : androidPermissions) {
            if (checkSelfPermission(androidPermission) == PackageManager.PERMISSION_GRANTED) {
                nativePermissionResult(requestId, permission, true);
                return;
            }
        }

        int requestCode = allocatePermissionRequestCode();
        pendingPermissionRequests.put(requestCode, new PermissionRequest(requestId, permission));
        try {
            requestPermissions(androidPermissions, requestCode);
        } catch (RuntimeException exception) {
            pendingPermissionRequests.remove(requestCode);
            nativePermissionResult(requestId, permission, false);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        PermissionRequest request = pendingPermissionRequests.get(requestCode);
        if (request == null) return;
        pendingPermissionRequests.remove(requestCode);
        boolean granted = false;
        for (int grantResult : grantResults) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) {
                granted = true;
                break;
            }
        }
        nativePermissionResult(request.requestId, request.permission, granted);
    }

    @SuppressWarnings({"unused", "deprecation"}) // Called through JNI; NativeActivity uses activity results.
    public void openFileFromNative(long requestId) {
        runOnUiThread(() -> {
            if (pendingFileRequestId != 0) {
                nativeFileSelectionCancelled(pendingFileRequestId);
            }
            pendingFileRequestId = requestId;
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
            try {
                startActivityForResult(intent, FILE_PICKER_REQUEST_CODE);
            } catch (RuntimeException exception) {
                pendingFileRequestId = 0;
                nativeFileSelectionCancelled(requestId);
            }
        });
    }

    @Override
    @SuppressWarnings("deprecation")
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != FILE_PICKER_REQUEST_CODE || pendingFileRequestId == 0) return;

        long requestId = pendingFileRequestId;
        pendingFileRequestId = 0;
        Uri uri = resultCode == RESULT_OK && data != null ? data.getData() : null;
        if (uri == null) {
            nativeFileSelectionCancelled(requestId);
            return;
        }

        if ((data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0) {
            try {
                getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } catch (SecurityException ignored) {
                // Some providers grant access only for the current process lifetime.
            }
        }
        nativeFileSelected(requestId, uri.toString());
    }

    private int allocatePermissionRequestCode() {
        while (pendingPermissionRequests.get(nextPermissionRequestCode) != null) {
            nextPermissionRequestCode += 1;
            if (nextPermissionRequestCode == FILE_PICKER_REQUEST_CODE) nextPermissionRequestCode += 1;
        }
        int requestCode = nextPermissionRequestCode;
        nextPermissionRequestCode += 1;
        if (nextPermissionRequestCode >= 0xffff) nextPermissionRequestCode = FIRST_PERMISSION_REQUEST_CODE;
        return requestCode;
    }

    private static final class PermissionRequest {
        final long requestId;
        final int permission;

        PermissionRequest(long requestId, int permission) {
            this.requestId = requestId;
            this.permission = permission;
        }
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
