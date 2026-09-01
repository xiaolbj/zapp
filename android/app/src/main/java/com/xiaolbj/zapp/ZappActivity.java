package com.xiaolbj.zapp;

import android.Manifest;
import android.app.NativeActivity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.text.InputType;
import android.graphics.Rect;
import android.util.SparseArray;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityManager;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityNodeProvider;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class ZappActivity extends NativeActivity {
    private static final int PERMISSION_CAMERA = 0;
    private static final int PERMISSION_MICROPHONE = 1;
    private static final int PERMISSION_NOTIFICATIONS = 2;
    private static final int PERMISSION_MEDIA = 3;
    private static final int FIRST_PERMISSION_REQUEST_CODE = 4100;
    private static final int FILE_PICKER_REQUEST_CODE = 7301;
    private static final int ACCESSIBILITY_ACTION_FOCUS = 1;
    private static final int ACCESSIBILITY_ACTION_CLICK = 2;
    private static final int ACCESSIBILITY_ACTION_INCREMENT = 3;
    private static final int ACCESSIBILITY_ACTION_DECREMENT = 4;
    private static final int ACCESSIBILITY_ACTION_SET_TEXT = 5;
    private static final int ACCESSIBILITY_ACTION_EXPAND = 6;
    private static final int ACCESSIBILITY_ACTION_COLLAPSE = 7;
    private static final int ACCESSIBILITY_ACTION_SCROLL_FORWARD = 8;
    private static final int ACCESSIBILITY_ACTION_SCROLL_BACKWARD = 9;
    private static final int FILE_READ_ERROR_INVALID_URI = 1;
    private static final int FILE_READ_ERROR_NOT_FOUND = 2;
    private static final int FILE_READ_ERROR_PERMISSION_DENIED = 3;
    private static final int FILE_READ_ERROR_IO = 4;
    private static final int MAX_FILE_PREVIEW_BYTES = 4096;

    private final SparseArray<PermissionRequest> pendingPermissionRequests = new SparseArray<>();
    private ImeBridgeView imeBridgeView;
    private AccessibilityBridgeView accessibilityBridgeView;
    private int nextPermissionRequestCode = FIRST_PERMISSION_REQUEST_CODE;
    private long pendingFileRequestId;
    private final ExecutorService fileReadExecutor = Executors.newSingleThreadExecutor();
    private volatile boolean destroyed;

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
    private static native void nativeFileReadCompleted(long requestId, byte[] data, boolean truncated);
    private static native void nativeFileReadFailed(long requestId, int errorKind);
    private static native int nativeAccessibilityNodeCount();
    private static native boolean nativeAccessibilityNodeAt(
        int index,
        int[] metadata,
        float[] geometry,
        String[] strings
    );
    private static native void nativeAccessibilityAction(int elementId, int action, String text);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        accessibilityBridgeView = new AccessibilityBridgeView();
        addContentView(accessibilityBridgeView, new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ));
        imeBridgeView = new ImeBridgeView();
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(1, 1);
        params.gravity = Gravity.TOP | Gravity.START;
        addContentView(imeBridgeView, params);
    }

    @SuppressWarnings("unused") // Called through JNI from android_bridge.c.
    public void refreshAccessibilitySnapshotFromNative() {
        runOnUiThread(() -> {
            if (accessibilityBridgeView != null) accessibilityBridgeView.refreshSnapshot();
        });
    }

    @Override
    protected void onDestroy() {
        destroyed = true;
        fileReadExecutor.shutdownNow();
        super.onDestroy();
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

    @SuppressWarnings("unused") // Called through JNI from android_bridge.c.
    public void readFileFromNative(long requestId, String uriText, int requestedMaxBytes) {
        final int maxBytes = Math.min(Math.max(requestedMaxBytes, 1), MAX_FILE_PREVIEW_BYTES);
        fileReadExecutor.execute(() -> readFileInBackground(requestId, uriText, maxBytes));
    }

    private void readFileInBackground(long requestId, String uriText, int maxBytes) {
        Uri uri = uriText == null ? null : Uri.parse(uriText);
        String scheme = uri == null ? null : uri.getScheme();
        if (scheme == null || !(scheme.equals("content") || scheme.equals("file") || scheme.equals("android.resource"))) {
            if (!destroyed) nativeFileReadFailed(requestId, FILE_READ_ERROR_INVALID_URI);
            return;
        }

        byte[] buffer = new byte[maxBytes + 1];
        int length = 0;
        try (InputStream input = getContentResolver().openInputStream(uri)) {
            if (input == null) {
                if (!destroyed) nativeFileReadFailed(requestId, FILE_READ_ERROR_IO);
                return;
            }
            while (length < buffer.length) {
                int read = input.read(buffer, length, buffer.length - length);
                if (read < 0) break;
                if (read == 0) {
                    int oneByte = input.read();
                    if (oneByte < 0) break;
                    buffer[length++] = (byte)oneByte;
                } else {
                    length += read;
                }
            }
            boolean truncated = length > maxBytes;
            byte[] result = Arrays.copyOf(buffer, Math.min(length, maxBytes));
            if (!destroyed) nativeFileReadCompleted(requestId, result, truncated);
        } catch (FileNotFoundException exception) {
            if (!destroyed) nativeFileReadFailed(requestId, FILE_READ_ERROR_NOT_FOUND);
        } catch (SecurityException exception) {
            if (!destroyed) nativeFileReadFailed(requestId, FILE_READ_ERROR_PERMISSION_DENIED);
        } catch (IOException | RuntimeException exception) {
            if (!destroyed) nativeFileReadFailed(requestId, FILE_READ_ERROR_IO);
        }
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

    private static final class SemanticNode {
        final int id;
        final int role;
        final int flags;
        final int level;
        final float x;
        final float y;
        final float width;
        final float height;
        final float value;
        final String label;
        final String valueText;

        SemanticNode(int[] metadata, float[] geometry, String[] strings) {
            id = metadata[0];
            role = metadata[1];
            flags = metadata[2];
            level = metadata[3];
            x = geometry[0];
            y = geometry[1];
            width = geometry[2];
            height = geometry[3];
            value = geometry[4];
            label = strings[0] == null ? "" : strings[0];
            valueText = strings[1] == null ? "" : strings[1];
        }

        boolean hasFlag(int flag) {
            return (flags & flag) != 0;
        }
    }

    private final class AccessibilityBridgeView extends View {
        private static final int FLAG_CHECKED_PRESENT = 1 << 0;
        private static final int FLAG_CHECKED = 1 << 1;
        private static final int FLAG_DISABLED = 1 << 2;
        private static final int FLAG_FOCUSED = 1 << 3;
        private static final int FLAG_SELECTED = 1 << 4;
        private static final int FLAG_MODAL = 1 << 5;
        private static final int FLAG_EXPANDED_PRESENT = 1 << 6;
        private static final int FLAG_EXPANDED = 1 << 7;
        private static final int FLAG_SCROLLABLE = 1 << 8;
        private static final int FLAG_CAN_SCROLL_FORWARD = 1 << 9;
        private static final int FLAG_CAN_SCROLL_BACKWARD = 1 << 10;

        private static final int ROLE_TEXT = 0;
        private static final int ROLE_BUTTON = 1;
        private static final int ROLE_CHECKBOX = 2;
        private static final int ROLE_SWITCH = 3;
        private static final int ROLE_SLIDER = 4;
        private static final int ROLE_TEXT_FIELD = 5;
        private static final int ROLE_NAVIGATION = 6;
        private static final int ROLE_NAVIGATION_ITEM = 7;
        private static final int ROLE_DIALOG = 8;
        private static final int ROLE_PROGRESS_BAR = 9;
        private static final int ROLE_STATUS = 10;
        private static final int ROLE_GROUP = 11;
        private static final int ROLE_LIST = 12;
        private static final int ROLE_TREE = 13;
        private static final int ROLE_TREE_ITEM = 14;

        private final AccessibilityManager accessibilityManager;
        private final SemanticNodeProvider provider = new SemanticNodeProvider();
        private volatile SemanticNode[] nodes = new SemanticNode[0];
        private int accessibilityFocusedId = View.NO_ID;
        private int hoveredId = View.NO_ID;

        AccessibilityBridgeView() {
            super(ZappActivity.this);
            accessibilityManager = (AccessibilityManager)getSystemService(ACCESSIBILITY_SERVICE);
            setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);
            setFocusable(false);
            setClickable(false);
            setWillNotDraw(true);
            if (Build.VERSION.SDK_INT >= 28) setScreenReaderFocusable(true);
        }

        void refreshSnapshot() {
            int count = Math.min(Math.max(nativeAccessibilityNodeCount(), 0), 64);
            ArrayList<SemanticNode> updated = new ArrayList<>(count);
            for (int index = 0; index < count; index += 1) {
                int[] metadata = new int[4];
                float[] geometry = new float[5];
                String[] strings = new String[2];
                if (!nativeAccessibilityNodeAt(index, metadata, geometry, strings)) continue;
                SemanticNode node = new SemanticNode(metadata, geometry, strings);
                if (node.width > 0 && node.height > 0) updated.add(node);
            }
            nodes = updated.toArray(new SemanticNode[0]);
            if (findNode(accessibilityFocusedId) == null) accessibilityFocusedId = View.NO_ID;
            if (accessibilityManager != null && accessibilityManager.isEnabled()) {
                sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
            }
        }

        @Override
        public AccessibilityNodeProvider getAccessibilityNodeProvider() {
            return provider;
        }

        @Override
        public boolean dispatchHoverEvent(MotionEvent event) {
            if (accessibilityManager == null || !accessibilityManager.isTouchExplorationEnabled()) {
                return super.dispatchHoverEvent(event);
            }
            int target = event.getAction() == MotionEvent.ACTION_HOVER_EXIT
                ? View.NO_ID
                : hitTest(event.getX(), event.getY());
            if (target != hoveredId) {
                if (hoveredId != View.NO_ID) sendVirtualEvent(hoveredId, AccessibilityEvent.TYPE_VIEW_HOVER_EXIT);
                hoveredId = target;
                if (hoveredId != View.NO_ID) sendVirtualEvent(hoveredId, AccessibilityEvent.TYPE_VIEW_HOVER_ENTER);
            }
            return target != View.NO_ID || event.getAction() == MotionEvent.ACTION_HOVER_EXIT;
        }

        private int hitTest(float x, float y) {
            SemanticNode[] current = nodes;
            for (int index = current.length - 1; index >= 0; index -= 1) {
                SemanticNode node = current[index];
                if (x >= node.x && x < node.x + node.width && y >= node.y && y < node.y + node.height) {
                    return node.id;
                }
            }
            return View.NO_ID;
        }

        private SemanticNode findNode(int id) {
            for (SemanticNode node : nodes) if (node.id == id) return node;
            return null;
        }

        private void sendVirtualEvent(int id, int eventType) {
            if (accessibilityManager == null || !accessibilityManager.isEnabled()) return;
            AccessibilityEvent event = AccessibilityEvent.obtain(eventType);
            event.setPackageName(getPackageName());
            SemanticNode node = findNode(id);
            if (node != null) event.getText().add(node.label);
            event.setSource(this, id);
            if (getParent() != null) getParent().requestSendAccessibilityEvent(this, event);
        }

        private final class SemanticNodeProvider extends AccessibilityNodeProvider {
            @Override
            public AccessibilityNodeInfo createAccessibilityNodeInfo(int virtualViewId) {
                if (virtualViewId == HOST_VIEW_ID) return createHostNode();
                SemanticNode node = findNode(virtualViewId);
                return node == null ? null : createChildNode(node);
            }

            private AccessibilityNodeInfo createHostNode() {
                AccessibilityNodeInfo info = AccessibilityNodeInfo.obtain();
                info.setPackageName(getPackageName());
                info.setClassName("android.view.ViewGroup");
                info.setSource(AccessibilityBridgeView.this);
                info.setParent((View)getParent());
                info.setContentDescription("ZAPP 跨平台应用");
                info.setEnabled(isEnabled());
                info.setVisibleToUser(isShown());
                info.setFocusable(false);
                Rect local = new Rect(0, 0, getWidth(), getHeight());
                info.setBoundsInParent(local);
                int[] location = new int[2];
                getLocationOnScreen(location);
                Rect screen = new Rect(local);
                screen.offset(location[0], location[1]);
                info.setBoundsInScreen(screen);
                if (Build.VERSION.SDK_INT >= 24) info.setImportantForAccessibility(true);
                for (SemanticNode node : nodes) {
                    if (isNodeExposed(node)) info.addChild(AccessibilityBridgeView.this, node.id);
                }
                return info;
            }

            private AccessibilityNodeInfo createChildNode(SemanticNode node) {
                AccessibilityNodeInfo info = AccessibilityNodeInfo.obtain(AccessibilityBridgeView.this, node.id);
                info.setPackageName(getPackageName());
                info.setSource(AccessibilityBridgeView.this, node.id);
                info.setParent(AccessibilityBridgeView.this);
                info.setClassName(className(node.role));
                info.setEnabled(!node.hasFlag(FLAG_DISABLED));
                info.setSelected(node.hasFlag(FLAG_SELECTED));
                info.setFocusable(isInteractive(node.role));
                info.setFocused(node.hasFlag(FLAG_FOCUSED));
                info.setAccessibilityFocused(node.id == accessibilityFocusedId);
                info.setVisibleToUser(isNodeExposed(node));
                if (Build.VERSION.SDK_INT >= 28) info.setScreenReaderFocusable(true);

                if (node.role == ROLE_TEXT || node.role == ROLE_STATUS) {
                    info.setText(node.label);
                } else {
                    info.setContentDescription(node.label);
                }
                if (!node.valueText.isEmpty()) info.setText(node.valueText);
                if (node.level > 0) info.getExtras().putInt("zapp.tree.level", node.level);
                if (node.hasFlag(FLAG_CHECKED_PRESENT)) {
                    info.setCheckable(true);
                    info.setChecked(node.hasFlag(FLAG_CHECKED));
                }

                Rect local = new Rect(
                    Math.round(node.x),
                    Math.round(node.y),
                    Math.round(node.x + node.width),
                    Math.round(node.y + node.height)
                );
                info.setBoundsInParent(local);
                int[] location = new int[2];
                getLocationOnScreen(location);
                Rect screen = new Rect(local);
                screen.offset(location[0], location[1]);
                info.setBoundsInScreen(screen);

                if (!node.hasFlag(FLAG_DISABLED)) addActions(info, node);
                return info;
            }

            private boolean isNodeVisible(SemanticNode node) {
                return node.x + node.width > 0 && node.y + node.height > 0 &&
                    node.x < getWidth() && node.y < getHeight();
            }

            private boolean isNodeExposed(SemanticNode node) {
                if (!isNodeVisible(node)) return false;
                boolean hasModal = false;
                for (SemanticNode candidate : nodes) {
                    if (candidate.hasFlag(FLAG_MODAL)) {
                        hasModal = true;
                        break;
                    }
                }
                return !hasModal || node.hasFlag(FLAG_MODAL);
            }

            private void addActions(AccessibilityNodeInfo info, SemanticNode node) {
                if (node.id == accessibilityFocusedId) {
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_CLEAR_ACCESSIBILITY_FOCUS);
                } else {
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_ACCESSIBILITY_FOCUS);
                }
                if (node.role == ROLE_BUTTON || node.role == ROLE_CHECKBOX || node.role == ROLE_SWITCH ||
                    node.role == ROLE_NAVIGATION_ITEM || node.role == ROLE_TREE_ITEM) {
                    info.setClickable(true);
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_CLICK);
                }
                if (node.role == ROLE_SLIDER) {
                    info.setScrollable(true);
                    if (!Float.isNaN(node.value)) {
                        info.setRangeInfo(AccessibilityNodeInfo.RangeInfo.obtain(
                            AccessibilityNodeInfo.RangeInfo.RANGE_TYPE_FLOAT, 0, 1, node.value
                        ));
                    }
                    if (Float.isNaN(node.value) || node.value < 1) {
                        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD);
                    }
                    if (Float.isNaN(node.value) || node.value > 0) {
                        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD);
                    }
                }
                if (node.role == ROLE_TEXT_FIELD) {
                    info.setEditable(true);
                    info.setClickable(true);
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_CLICK);
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_TEXT);
                }
                if (node.hasFlag(FLAG_EXPANDED_PRESENT)) {
                    info.addAction(node.hasFlag(FLAG_EXPANDED)
                        ? AccessibilityNodeInfo.AccessibilityAction.ACTION_COLLAPSE
                        : AccessibilityNodeInfo.AccessibilityAction.ACTION_EXPAND);
                }
                if (node.hasFlag(FLAG_SCROLLABLE)) {
                    boolean canForward = node.hasFlag(FLAG_CAN_SCROLL_FORWARD);
                    boolean canBackward = node.hasFlag(FLAG_CAN_SCROLL_BACKWARD);
                    info.setScrollable(canForward || canBackward);
                    if (canForward) {
                        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD);
                        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_DOWN);
                    }
                    if (canBackward) {
                        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD);
                        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_UP);
                    }
                }
            }

            @Override
            public boolean performAction(int virtualViewId, int action, Bundle arguments) {
                if (virtualViewId == HOST_VIEW_ID) {
                    return AccessibilityBridgeView.this.performAccessibilityAction(action, arguments);
                }
                SemanticNode node = findNode(virtualViewId);
                if (node == null || node.hasFlag(FLAG_DISABLED)) return false;
                if (action == AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS) {
                    if (accessibilityFocusedId == virtualViewId) return false;
                    accessibilityFocusedId = virtualViewId;
                    nativeAccessibilityAction(virtualViewId, ACCESSIBILITY_ACTION_FOCUS, null);
                    sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED);
                    return true;
                }
                if (action == AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS) {
                    if (accessibilityFocusedId != virtualViewId) return false;
                    accessibilityFocusedId = View.NO_ID;
                    sendVirtualEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED);
                    return true;
                }
                int nativeAction;
                String text = null;
                if (action == AccessibilityNodeInfo.ACTION_CLICK) {
                    nativeAction = ACCESSIBILITY_ACTION_CLICK;
                } else if (action == AccessibilityNodeInfo.ACTION_SCROLL_FORWARD ||
                    action == AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_DOWN.getId()) {
                    if (node.role == ROLE_SLIDER) {
                        nativeAction = ACCESSIBILITY_ACTION_INCREMENT;
                    } else if (node.hasFlag(FLAG_SCROLLABLE) &&
                        node.hasFlag(FLAG_CAN_SCROLL_FORWARD)) {
                        nativeAction = ACCESSIBILITY_ACTION_SCROLL_FORWARD;
                    } else {
                        return false;
                    }
                } else if (action == AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD ||
                    action == AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_UP.getId()) {
                    if (node.role == ROLE_SLIDER) {
                        nativeAction = ACCESSIBILITY_ACTION_DECREMENT;
                    } else if (node.hasFlag(FLAG_SCROLLABLE) &&
                        node.hasFlag(FLAG_CAN_SCROLL_BACKWARD)) {
                        nativeAction = ACCESSIBILITY_ACTION_SCROLL_BACKWARD;
                    } else {
                        return false;
                    }
                } else if (action == AccessibilityNodeInfo.ACTION_SET_TEXT) {
                    nativeAction = ACCESSIBILITY_ACTION_SET_TEXT;
                    if (arguments != null) {
                        CharSequence value = arguments.getCharSequence(
                            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE
                        );
                        text = value == null ? "" : value.toString();
                    }
                } else if (action == AccessibilityNodeInfo.ACTION_EXPAND) {
                    nativeAction = ACCESSIBILITY_ACTION_EXPAND;
                } else if (action == AccessibilityNodeInfo.ACTION_COLLAPSE) {
                    nativeAction = ACCESSIBILITY_ACTION_COLLAPSE;
                } else {
                    return false;
                }
                nativeAccessibilityAction(virtualViewId, nativeAction, text);
                boolean isScroll = nativeAction == ACCESSIBILITY_ACTION_SCROLL_FORWARD ||
                    nativeAction == ACCESSIBILITY_ACTION_SCROLL_BACKWARD;
                sendVirtualEvent(
                    virtualViewId,
                    isScroll ? AccessibilityEvent.TYPE_VIEW_SCROLLED : AccessibilityEvent.TYPE_VIEW_CLICKED
                );
                return true;
            }

            @Override
            public AccessibilityNodeInfo findFocus(int focus) {
                if (focus == AccessibilityNodeInfo.FOCUS_ACCESSIBILITY && accessibilityFocusedId != View.NO_ID) {
                    return createAccessibilityNodeInfo(accessibilityFocusedId);
                }
                if (focus == AccessibilityNodeInfo.FOCUS_INPUT) {
                    for (SemanticNode node : nodes) {
                        if (node.hasFlag(FLAG_FOCUSED)) return createChildNode(node);
                    }
                }
                return null;
            }

            @Override
            public List<AccessibilityNodeInfo> findAccessibilityNodeInfosByText(String text, int virtualViewId) {
                if (text == null) return Collections.emptyList();
                String query = text.toLowerCase();
                ArrayList<AccessibilityNodeInfo> results = new ArrayList<>();
                for (SemanticNode node : nodes) {
                    if (node.label.toLowerCase().contains(query) || node.valueText.toLowerCase().contains(query)) {
                        results.add(createChildNode(node));
                    }
                }
                return results;
            }

            private String className(int role) {
                switch (role) {
                    case ROLE_BUTTON: return "android.widget.Button";
                    case ROLE_CHECKBOX: return "android.widget.CheckBox";
                    case ROLE_SWITCH: return "android.widget.Switch";
                    case ROLE_SLIDER: return "android.widget.SeekBar";
                    case ROLE_TEXT_FIELD: return "android.widget.EditText";
                    case ROLE_NAVIGATION:
                    case ROLE_GROUP:
                    case ROLE_LIST:
                    case ROLE_TREE: return "android.view.ViewGroup";
                    case ROLE_NAVIGATION_ITEM:
                    case ROLE_TREE_ITEM: return "android.widget.Button";
                    case ROLE_DIALOG: return "android.app.Dialog";
                    case ROLE_PROGRESS_BAR: return "android.widget.ProgressBar";
                    default: return "android.widget.TextView";
                }
            }

            private boolean isInteractive(int role) {
                return role == ROLE_BUTTON || role == ROLE_CHECKBOX || role == ROLE_SWITCH ||
                    role == ROLE_SLIDER || role == ROLE_TEXT_FIELD || role == ROLE_NAVIGATION_ITEM ||
                    role == ROLE_TREE_ITEM;
            }
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
