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
import android.os.Handler;
import android.os.HandlerThread;
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
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Calendar;
import java.util.Locale;

import org.json.JSONObject;

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
    private HandlerThread workerThread;
    private Handler workerHandler;

    public static NotificationListener getInstance() {
        return instance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        workerThread = new HandlerThread("toolmate-nls");
        workerThread.start();
        workerHandler = new Handler(workerThread.getLooper());
    }

    @Override
    public void onDestroy() {
        if (workerThread != null) {
            workerThread.quitSafely();
            workerThread = null;
            workerHandler = null;
        }
        super.onDestroy();
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
        Log.i(TAG, "Notification listener connected");
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        instance = null;
        Log.w(TAG, "Notification listener disconnected — requesting rebind");
        if (Build.VERSION.SDK_INT >= VERSION_CODES.N) {
            requestRebind(new android.content.ComponentName(this, NotificationListener.class));
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationPosted(StatusBarNotification notification) {
        Handler handler = workerHandler;
        if (handler != null) {
            handler.post(() -> handleNotification(notification, false));
        } else {
            handleNotification(notification, false);
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        // Removals are not stored — ignore.
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void handleNotification(StatusBarNotification notification, boolean isRemoved) {
        if (isRemoved || notification == null) {
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
            if (notif == null) {
                return;
            }

            Bundle extras = notif.extras;
            boolean isOngoing = (notif.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            MessagingParts messaging = extras != null
                    ? extractMessagingParts(extras)
                    : new MessagingParts(null, null);

            String title = extras != null
                    ? firstNonEmpty(
                        messaging.sender,
                        extraText(extras, Notification.EXTRA_CONVERSATION_TITLE),
                        extraText(extras, Notification.EXTRA_TITLE),
                        extraText(extras, Notification.EXTRA_TITLE_BIG))
                    : messaging.sender;
            String content = extras != null
                    ? firstNonEmpty(messaging.text, extractBestContent(extras))
                    : messaging.text;

            // Last-resort fallbacks so chat apps (TikTok/WhatsApp) are not dropped.
            if (isBlank(title) && !isBlank(content)) {
                title = content;
            }
            if (isBlank(content) && !isBlank(title)) {
                content = title;
            }
            if (isBlank(title) && isBlank(content)) {
                Log.d(TAG, "Skipping empty notification from " + packageName);
                return;
            }

            // Do not decode other apps' APK icons here. That loads ApkAssets on
            // the listener thread and used to stall the UI process first frame.
            byte[] largeIcon = null;
            Action action = NotificationUtils.getQuickReplyAction(notif, packageName);

            if (Build.VERSION.SDK_INT >= VERSION_CODES.M) {
                largeIcon = getNotificationLargeIcon(getApplicationContext(), notif);
            }

            Intent intent = new Intent(NotificationConstants.INTENT);
            intent.setPackage(getPackageName());
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
            intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, title);
            intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, content);
            if (messaging.sender != null) {
                intent.putExtra(NotificationConstants.SENDER, messaging.sender);
            }
            intent.putExtra(NotificationConstants.IS_REMOVED, false);

            if (action != null) {
                cachedNotifications.put(notification.getId(), action);
            }

            if (largeIcon != null && largeIcon.length <= MAX_ICON_BYTES) {
                intent.putExtra(NotificationConstants.NOTIFICATIONS_LARGE_ICON, largeIcon);
            }

            boolean hasPicture = extras != null && extras.containsKey(Notification.EXTRA_PICTURE);
            intent.putExtra(NotificationConstants.HAVE_EXTRA_PICTURE, hasPicture);
            if (hasPicture) {
                try {
                    Object pictureObj = extras.get(Notification.EXTRA_PICTURE);
                    if (pictureObj instanceof Bitmap) {
                        byte[] pictureBytes = compressBitmap((Bitmap) pictureObj, MAX_PICTURE_BYTES);
                        if (pictureBytes != null) {
                            intent.putExtra(NotificationConstants.EXTRAS_PICTURE, pictureBytes);
                        }
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Skipping EXTRA_PICTURE: " + e.getMessage());
                }
            }

            persistToQueue(
                    packageName,
                    title,
                    content,
                    notification.getId(),
                    Build.VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP
                            ? notification.getKey()
                            : null,
                    notification.getPostTime(),
                    messaging.sender);
            intent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
            dispatchBroadcast(intent);
        } catch (Exception e) {
            Log.e(TAG, "Failed to handle notification from " +
                    (notification != null ? notification.getPackageName() : "unknown"), e);
        }
    }

    private void dispatchBroadcast(Intent intent) {
        try {
            sendBroadcast(intent);
        } catch (Exception e) {
            Log.w(TAG, "Broadcast with icons failed, retrying without media: " + e.getMessage());
            intent.removeExtra(NotificationConstants.NOTIFICATIONS_ICON);
            intent.removeExtra(NotificationConstants.NOTIFICATIONS_LARGE_ICON);
            intent.removeExtra(NotificationConstants.EXTRAS_PICTURE);
            try {
                sendBroadcast(intent);
            } catch (Exception e2) {
                Log.e(TAG, "Broadcast failed even without media", e2);
            }
        }
    }

    private void persistToQueue(
            String packageName,
            String title,
            String content,
            int id,
            String key,
            long postTime,
            String sender) {
        try {
            long ms = postTime > 0 ? postTime : System.currentTimeMillis();
            JSONObject o = new JSONObject();
            String uniqueId = packageName + "_" + id + "_"
                    + (String.valueOf(title) + String.valueOf(content)).hashCode();
            o.put("id", uniqueId);
            o.put("packageName", packageName);
            o.put("title", title != null ? title : "");
            o.put("text", content != null ? content : "");
            o.put("timestamp", isoTimestamp(ms));
            o.put("postTime", ms);
            o.put("isRead", false);
            o.put("androidId", String.valueOf(id));
            o.put("androidKey", key != null ? key : "");
            o.put("count", 1);
            if (sender != null && !sender.isEmpty()) {
                o.put("sender", sender);
            }

            NotificationQueueStore.append(getApplicationContext(), o);
            Log.i(TAG, "Queued notification from " + packageName);
        } catch (Exception e) {
            Log.w(TAG, "persistToQueue failed: " + e.getMessage());
        }
    }

    private static String isoTimestamp(long ms) {
        Calendar c = Calendar.getInstance();
        c.setTimeInMillis(ms);
        return String.format(
                Locale.US,
                "%04d-%02d-%02dT%02d:%02d:%02d",
                c.get(Calendar.YEAR),
                c.get(Calendar.MONTH) + 1,
                c.get(Calendar.DAY_OF_MONTH),
                c.get(Calendar.HOUR_OF_DAY),
                c.get(Calendar.MINUTE),
                c.get(Calendar.SECOND));
    }

    private static String charSeq(CharSequence cs) {
        return cs == null ? null : cs.toString().trim();
    }

    private static boolean isBlank(String s) {
        return s == null || s.isEmpty();
    }

    private static String extraText(Bundle extras, String key) {
        if (extras == null || key == null) return null;
        Object v = extras.get(key);
        if (v instanceof CharSequence) return charSeq((CharSequence) v);
        return v == null ? null : v.toString().trim();
    }

    private static String personName(Object senderObj) {
        if (senderObj == null) return null;
        if (senderObj instanceof CharSequence) {
            return charSeq((CharSequence) senderObj);
        }
        if (senderObj instanceof Bundle) {
            return charSeq(((Bundle) senderObj).getCharSequence("name"));
        }
        if (Build.VERSION.SDK_INT >= VERSION_CODES.P && senderObj instanceof android.app.Person) {
            return charSeq(((android.app.Person) senderObj).getName());
        }
        return null;
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
                    sender = firstNonEmpty(
                            personName(msg.get("sender_person")),
                            personName(msg.get("sender")));
                }
            }
            if (isBlank(sender)) {
                sender = firstNonEmpty(
                        personName(extras.get("android.messagingUser")),
                        extraText(extras, Notification.EXTRA_CONVERSATION_TITLE),
                        extraText(extras, Notification.EXTRA_SUB_TEXT));
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

            MessagingParts messaging = extras != null
                    ? extractMessagingParts(extras)
                    : new MessagingParts(null, null);
            String title = extras != null
                    ? firstNonEmpty(
                        messaging.sender,
                        extraText(extras, Notification.EXTRA_CONVERSATION_TITLE),
                        extraText(extras, Notification.EXTRA_TITLE),
                        extraText(extras, Notification.EXTRA_TITLE_BIG))
                    : messaging.sender;
            String content = extras != null
                    ? firstNonEmpty(messaging.text, extractBestContent(extras))
                    : messaging.text;

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
