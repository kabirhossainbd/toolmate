package notification.listener.service;

import static notification.listener.service.NotificationUtils.getBitmapFromDrawable;
import static notification.listener.service.models.ActionCache.cachedNotifications;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.HashMap;

import androidx.annotation.RequiresApi;

import java.io.ByteArrayOutputStream;

import notification.listener.service.models.Action;


@SuppressLint("OverrideAbstract")
@RequiresApi(api = VERSION_CODES.JELLY_BEAN_MR2)
public class NotificationListener extends NotificationListenerService {
    private static final String TAG = "NotificationListener";
    // Binder extras must stay well under ~1MB. TikTok/media notifs often exceed this.
    private static final int MAX_ICON_BYTES = 100 * 1024;
    private static final int MAX_PICTURE_BYTES = 200 * 1024;
    private static final int ICON_MAX_DIMENSION = 192;

    private static NotificationListener instance;

    public static NotificationListener getInstance() {
        return instance;
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationPosted(StatusBarNotification notification) {
        handleNotification(notification, false);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        handleNotification(sbn, true);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void handleNotification(StatusBarNotification notification, boolean isRemoved) {
        try {
            String packageName = notification.getPackageName();
            Bundle extras = notification.getNotification().extras;
            boolean isOngoing = (notification.getNotification().flags & Notification.FLAG_ONGOING_EVENT) != 0;
            byte[] appIcon = getAppIcon(packageName);
            byte[] largeIcon = null;
            Action action = NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName);

            if (Build.VERSION.SDK_INT >= VERSION_CODES.M) {
                largeIcon = getNotificationLargeIcon(getApplicationContext(), notification.getNotification());
            }

            Intent intent = new Intent(NotificationConstants.INTENT);
            intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
            intent.putExtra(NotificationConstants.ID, notification.getId());
            intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
            intent.putExtra(NotificationConstants.IS_ONGOING, isOngoing);

            if (action != null) {
                cachedNotifications.put(notification.getId(), action);
            }

            // Only attach icons if they fit Binder limits (TikTok BigPicture notifs crash otherwise)
            if (appIcon != null && appIcon.length <= MAX_ICON_BYTES) {
                intent.putExtra(NotificationConstants.NOTIFICATIONS_ICON, appIcon);
            }
            if (largeIcon != null && largeIcon.length <= MAX_ICON_BYTES) {
                intent.putExtra(NotificationConstants.NOTIFICATIONS_LARGE_ICON, largeIcon);
            }

            if (extras != null) {
                CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
                CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);

                intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, title == null ? null : title.toString());
                intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, text == null ? null : text.toString());
                intent.putExtra(NotificationConstants.IS_REMOVED, isRemoved);

                boolean hasPicture = extras.containsKey(Notification.EXTRA_PICTURE);
                intent.putExtra(NotificationConstants.HAVE_EXTRA_PICTURE, hasPicture);

                if (hasPicture) {
                    try {
                        Object pictureObj = extras.get(Notification.EXTRA_PICTURE);
                        if (pictureObj instanceof Bitmap) {
                            byte[] pictureBytes = compressBitmap((Bitmap) pictureObj, MAX_PICTURE_BYTES);
                            if (pictureBytes != null) {
                                intent.putExtra(NotificationConstants.EXTRAS_PICTURE, pictureBytes);
                            }
                        } else {
                            Log.w(TAG, "EXTRA_PICTURE is not a Bitmap: " +
                                    (pictureObj == null ? "null" : pictureObj.getClass().getName()));
                        }
                    } catch (Exception e) {
                        Log.w(TAG, "Skipping EXTRA_PICTURE: " + e.getMessage());
                    }
                }
            }
            sendBroadcast(intent);
        } catch (Exception e) {
            // Never let a single malformed notification (e.g. TikTok media) crash the process
            Log.e(TAG, "Failed to handle notification from " +
                    (notification != null ? notification.getPackageName() : "unknown"), e);
        }
    }


    public byte[] getAppIcon(String packageName) {
        try {
            PackageManager manager = getBaseContext().getPackageManager();
            Drawable icon = manager.getApplicationIcon(packageName);
            Bitmap bitmap = getBitmapFromDrawable(icon);
            if (bitmap == null) {
                return null;
            }
            return compressBitmap(bitmap, MAX_ICON_BYTES);
        } catch (Exception e) {
            Log.w(TAG, "getAppIcon failed for " + packageName + ": " + e.getMessage());
            return null;
        }
    }

    @RequiresApi(api = VERSION_CODES.M)
    private byte[] getNotificationLargeIcon(Context context, Notification notification) {
        try {
            Icon largeIcon = notification.getLargeIcon();
            if (largeIcon == null) {
                return null;
            }
            Drawable iconDrawable = largeIcon.loadDrawable(context);
            if (iconDrawable == null) {
                return null;
            }
            Bitmap iconBitmap;
            if (iconDrawable instanceof BitmapDrawable
                    && ((BitmapDrawable) iconDrawable).getBitmap() != null) {
                iconBitmap = ((BitmapDrawable) iconDrawable).getBitmap();
            } else {
                iconBitmap = getBitmapFromDrawable(iconDrawable);
            }
            if (iconBitmap == null) {
                return null;
            }
            return compressBitmap(iconBitmap, MAX_ICON_BYTES);
        } catch (Exception e) {
            Log.d(TAG, "getNotificationLargeIcon: " + e.getMessage());
            return null;
        }
    }

    /**
     * Downscale + JPEG-compress a bitmap so Intent extras stay under Binder limits.
     * Returns null if the result is still too large.
     */
    private static byte[] compressBitmap(Bitmap source, int maxBytes) {
        try {
            Bitmap bitmap = source;
            int width = bitmap.getWidth();
            int height = bitmap.getHeight();
            if (width <= 0 || height <= 0) {
                return null;
            }

            if (width > ICON_MAX_DIMENSION || height > ICON_MAX_DIMENSION) {
                float scale = Math.min(
                        (float) ICON_MAX_DIMENSION / width,
                        (float) ICON_MAX_DIMENSION / height);
                int newW = Math.max(1, Math.round(width * scale));
                int newH = Math.max(1, Math.round(height * scale));
                bitmap = Bitmap.createScaledBitmap(bitmap, newW, newH, true);
            }

            int quality = 80;
            byte[] bytes = null;
            while (quality >= 40) {
                ByteArrayOutputStream stream = new ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream);
                bytes = stream.toByteArray();
                if (bytes.length <= maxBytes) {
                    return bytes;
                }
                quality -= 20;
            }
            // Still too large after compression — drop it rather than crash
            return null;
        } catch (Exception e) {
            Log.w(TAG, "compressBitmap failed: " + e.getMessage());
            return null;
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public List<Map<String, Object>> getActiveNotificationData() {
        List<Map<String, Object>> notificationList = new ArrayList<>();
        StatusBarNotification[] activeNotifications = getActiveNotifications();

        for (StatusBarNotification sbn : activeNotifications) {
            Map<String, Object> notifData = new HashMap<>();
            Notification notification = sbn.getNotification();
            Bundle extras = notification.extras;

            notifData.put("id", sbn.getId());
            notifData.put("packageName", sbn.getPackageName());
            notifData.put("title", extras.getCharSequence(Notification.EXTRA_TITLE) != null
                    ? extras.getCharSequence(Notification.EXTRA_TITLE).toString()
                    : null);
            notifData.put("content", extras.getCharSequence(Notification.EXTRA_TEXT) != null
                    ? extras.getCharSequence(Notification.EXTRA_TEXT).toString()
                    : null);
            boolean isOngoing = (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            notifData.put("onGoing", isOngoing);

            notificationList.add(notifData);
        }
        return notificationList;
    }

}
