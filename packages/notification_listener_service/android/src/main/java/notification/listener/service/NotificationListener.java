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
import android.os.Parcelable;
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
        // Removals are not useful for history — skip early.
        if (isRemoved) {
            return;
        }
        try {
            String packageName = notification.getPackageName();
            if (packageName == null || packageName.isEmpty()) {
                return;
            }
            // Ignore our own foreground/service notifications.
            if (packageName.equals(getPackageName())) {
                return;
            }

            Notification notif = notification.getNotification();
            // Group summaries often replace useful child posts — skip them.
            if ((notif.flags & Notification.FLAG_GROUP_SUMMARY) != 0) {
                return;
            }

            Bundle extras = notif.extras;
            boolean isOngoing = (notif.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            byte[] appIcon = getAppIcon(packageName);
            byte[] largeIcon = null;
            Action action = NotificationUtils.getQuickReplyAction(notif, packageName);

            if (Build.VERSION.SDK_INT >= VERSION_CODES.M) {
                largeIcon = getNotificationLargeIcon(getApplicationContext(), notif);
            }

            Intent intent = new Intent(NotificationConstants.INTENT);
            intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
            intent.putExtra(NotificationConstants.ID, notification.getId());
            intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
            intent.putExtra(NotificationConstants.IS_ONGOING, isOngoing);
            intent.putExtra(NotificationConstants.POST_TIME, notification.getPostTime());
            if (notification.getTag() != null) {
                intent.putExtra(NotificationConstants.TAG, notification.getTag());
            }
            if (Build.VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
                intent.putExtra(NotificationConstants.KEY, notification.getKey());
            }
            if (Build.VERSION.SDK_INT >= VERSION_CODES.O && notif.getChannelId() != null) {
                intent.putExtra(NotificationConstants.CHANNEL_ID, notif.getChannelId());
            }

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

            String title = null;
            String content = null;
            String sender = null;
            if (extras != null) {
                MessagingParts messaging = extractMessagingParts(extras);
                sender = messaging.sender;
                content = firstNonEmpty(messaging.text, extractBestContent(extras));
                // Prefer real person name for chat apps; fall back to title extras.
                title = firstNonEmpty(
                        sender,
                        charSeq(extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)),
                        charSeq(extras.getCharSequence(Notification.EXTRA_TITLE)),
                        charSeq(extras.getCharSequence(Notification.EXTRA_TITLE_BIG))
                );

                intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, title);
                intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, content);
                if (sender != null) {
                    intent.putExtra(NotificationConstants.SENDER, sender);
                }
                intent.putExtra(NotificationConstants.IS_REMOVED, false);

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

            // Nothing useful to store
            if ((title == null || title.isEmpty()) && (content == null || content.isEmpty())) {
                return;
            }

            sendBroadcast(intent);
        } catch (Exception e) {
            // Never let a single malformed notification (e.g. TikTok media) crash the process
            Log.e(TAG, "Failed to handle notification from " +
                    (notification != null ? notification.getPackageName() : "unknown"), e);
        }
    }

    private static String charSeq(CharSequence cs) {
        return cs == null ? null : cs.toString().trim();
    }

    private static String firstNonEmpty(String... values) {
        if (values == null) return null;
        for (String v : values) {
            if (v != null && !v.isEmpty()) return v;
        }
        return null;
    }

    /**
     * Messaging apps often put the real body in BIG_TEXT / TEXT_LINES / MessagingStyle,
     * not EXTRA_TEXT — missing those causes "lost" notifications.
     */
    @RequiresApi(api = VERSION_CODES.KITKAT)
    private static String extractBestContent(Bundle extras) {
        String text = charSeq(extras.getCharSequence(Notification.EXTRA_TEXT));
        String bigText = charSeq(extras.getCharSequence(Notification.EXTRA_BIG_TEXT));
        String infoText = charSeq(extras.getCharSequence(Notification.EXTRA_INFO_TEXT));
        String subText = charSeq(extras.getCharSequence(Notification.EXTRA_SUB_TEXT));
        String summary = charSeq(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT));

        // Prefer the longest meaningful body (BIG_TEXT usually has full message).
        String best = firstNonEmpty(bigText, text, infoText, subText, summary);

        CharSequence[] lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES);
        if (lines != null && lines.length > 0) {
            // Last line is usually the newest message in stacked notifications.
            String lastLine = charSeq(lines[lines.length - 1]);
            if (lastLine != null && !lastLine.isEmpty()) {
                if (best == null || lastLine.length() >= best.length()) {
                    best = lastLine;
                }
            }
        }

        // MessagingStyle: take the last message text when available.
        MessagingParts messaging = extractMessagingParts(extras);
        if (messaging.text != null && !messaging.text.isEmpty()) {
            best = messaging.text;
        }

        return best;
    }

    private static final class MessagingParts {
        final String sender;
        final String text;

        MessagingParts(String sender, String text) {
            this.sender = sender;
            this.text = text;
        }
    }

    /**
     * Pulls person name + last message from MessagingStyle EXTRA_MESSAGES.
     */
    @RequiresApi(api = VERSION_CODES.KITKAT)
    private static MessagingParts extractMessagingParts(Bundle extras) {
        String sender = null;
        String text = null;
        try {
            Object raw = null;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                raw = extras.get(Notification.EXTRA_MESSAGES);
            }
            Object[] messages = null;
            if (raw instanceof Object[]) {
                messages = (Object[]) raw;
            } else if (raw instanceof Parcelable[]) {
                Parcelable[] parcelables = (Parcelable[]) raw;
                messages = new Object[parcelables.length];
                System.arraycopy(parcelables, 0, messages, 0, parcelables.length);
            }
            if (messages != null && messages.length > 0) {
                Object last = messages[messages.length - 1];
                if (last instanceof Bundle) {
                    Bundle msg = (Bundle) last;
                    text = charSeq(msg.getCharSequence("text"));
                    Object senderObj = msg.get("sender");
                    if (senderObj instanceof CharSequence) {
                        sender = charSeq((CharSequence) senderObj);
                    } else if (senderObj instanceof Bundle) {
                        sender = charSeq(((Bundle) senderObj).getCharSequence("name"));
                    }
                }
            }
        } catch (Throwable e) {
            Log.d(TAG, "EXTRA_MESSAGES parse skipped: " + e.getMessage());
        }
        return new MessagingParts(sender, text);
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

            if ((notification.flags & Notification.FLAG_GROUP_SUMMARY) != 0) {
                continue;
            }

            MessagingParts messaging = extras != null
                    ? extractMessagingParts(extras)
                    : new MessagingParts(null, null);
            String title = extras != null
                    ? firstNonEmpty(
                        messaging.sender,
                        charSeq(extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)),
                        charSeq(extras.getCharSequence(Notification.EXTRA_TITLE)),
                        charSeq(extras.getCharSequence(Notification.EXTRA_TITLE_BIG)))
                    : null;
            String content = extras != null
                    ? firstNonEmpty(messaging.text, extractBestContent(extras))
                    : null;

            notifData.put("id", sbn.getId());
            notifData.put("packageName", sbn.getPackageName());
            notifData.put("title", title);
            notifData.put("content", content);
            notifData.put("sender", messaging.sender);
            notifData.put("postTime", sbn.getPostTime());
            if (Build.VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
                notifData.put("key", sbn.getKey());
            }
            if (sbn.getTag() != null) {
                notifData.put("tag", sbn.getTag());
            }
            boolean isOngoing = (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            notifData.put("onGoing", isOngoing);

            if ((title == null || title.isEmpty()) && (content == null || content.isEmpty())) {
                continue;
            }
            notificationList.add(notifData);
        }
        return notificationList;
    }

}
