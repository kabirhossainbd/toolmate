package notification.listener.service;

import static notification.listener.service.NotificationConstants.*;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import io.flutter.plugin.common.EventChannel.EventSink;

import java.util.HashMap;

public class NotificationReceiver extends BroadcastReceiver {

    private static final String TAG = "NotificationReceiver";
    private EventSink eventSink;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public NotificationReceiver(EventSink eventSink) {
        this.eventSink = eventSink;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || eventSink == null) return;

        HashMap<String, Object> data = new HashMap<>();
        data.put("id", intent.getIntExtra(ID, -1));
        data.put("packageName", intent.getStringExtra(PACKAGE_NAME));
        data.put("title", intent.getStringExtra(NOTIFICATION_TITLE));
        data.put("content", intent.getStringExtra(NOTIFICATION_CONTENT));
        data.put("sender", intent.getStringExtra(SENDER));
        data.put("key", intent.getStringExtra(KEY));
        data.put("tag", intent.getStringExtra(TAG));
        data.put("channelId", intent.getStringExtra(CHANNEL_ID));
        data.put("postTime", intent.getLongExtra(POST_TIME, 0L));
        data.put("notificationIcon", intent.getByteArrayExtra(NOTIFICATIONS_ICON));
        data.put("notificationExtrasPicture", intent.getByteArrayExtra(EXTRAS_PICTURE));
        data.put("haveExtraPicture", intent.getBooleanExtra(HAVE_EXTRA_PICTURE, false));
        data.put("largeIcon", intent.getByteArrayExtra(NOTIFICATIONS_LARGE_ICON));
        data.put("hasRemoved", intent.getBooleanExtra(IS_REMOVED, false));
        data.put("canReply", intent.getBooleanExtra(CAN_REPLY, false));
        data.put("onGoing", intent.getBooleanExtra(IS_ONGOING, false));

        final EventSink sink = eventSink;
        mainHandler.post(() -> {
            try {
                if (sink != null) sink.success(data);
            } catch (Exception e) {
                Log.w(TAG, "EventSink failed: " + e.getMessage());
            }
        });
    }
}
