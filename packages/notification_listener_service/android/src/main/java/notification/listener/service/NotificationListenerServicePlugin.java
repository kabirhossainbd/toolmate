package notification.listener.service;

import static notification.listener.service.NotificationUtils.isPermissionGranted;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.content.ActivityNotFoundException;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import notification.listener.service.models.Action;
import notification.listener.service.models.ActionCache;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class NotificationListenerServicePlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener, EventChannel.StreamHandler {

    private static final String CHANNEL_TAG = "x-slayer/notifications_channel";
    private static final String EVENT_TAG = "x-slayer/notifications_event";
    private static final String TAG = "NotificationPlugin";

    private MethodChannel channel;
    private EventChannel eventChannel;
    private NotificationReceiver notificationReceiver;
    private Context context;
    private Activity mActivity;

    private Result pendingPermissionResult;
    final int REQUEST_CODE_FOR_NOTIFICATIONS = 1199;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_TAG);
        channel.setMethodCallHandler(this);
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EVENT_TAG);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("isPermissionGranted")) {
            result.success(isPermissionGranted(context));
        } else if (call.method.equals("requestPermission")) {
            if (mActivity == null) {
                result.error("NO_ACTIVITY", "Activity is not attached", null);
                return;
            }
            // Don't reply here — reply once in onActivityResult when the user returns
            pendingPermissionResult = result;
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            try {
                mActivity.startActivityForResult(intent, REQUEST_CODE_FOR_NOTIFICATIONS);
            } catch (ActivityNotFoundException e) {
                Log.e(TAG, "ActivityNotFoundException: " + e.getMessage());
                pendingPermissionResult = null;
                result.error("ACTIVITY_NOT_FOUND", "No activity found to handle notification listener settings", null);
            }
        } else if (call.method.equals("sendReply")) {
            final String message = call.argument("message");
            final Integer notificationId = call.argument("notificationId");

            if (notificationId == null) {
                result.error("Notification", "notificationId is required", null);
                return;
            }

            final Action action = ActionCache.cachedNotifications.get(notificationId);
            if (action == null) {
                result.error("Notification", "Can't find this cached notification", null);
                return;
            }
            try {
                action.sendReply(context, message);
                result.success(true);
            } catch (PendingIntent.CanceledException e) {
                result.success(false);
                e.printStackTrace();
            }
        } else if (call.method.equals("getActiveNotifications")) {
            NotificationListener service = NotificationListener.getInstance();
            if (service != null) {
                List<Map<String, Object>> notifications = service.getActiveNotificationData();
                result.success(notifications);
            } else {
                result.success(new ArrayList<>());
            }
        } else if (call.method.equals("drainPendingQueue")) {
            result.success(NotificationQueueStore.drain(context));
        } else if (call.method.equals("requestRebind")) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    NotificationListener.requestRebind(
                            new android.content.ComponentName(
                                    context, NotificationListener.class));
                } catch (Exception e) {
                    Log.w(TAG, "requestRebind failed: " + e.getMessage());
                }
            }
            result.success(true);
        } else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        this.mActivity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        this.mActivity = null;
    }

    @SuppressLint("WrongConstant")
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(NotificationConstants.INTENT);
        notificationReceiver = new NotificationReceiver(events);
        // API 33+ requires an exported flag. Same-app broadcasts use NOT_EXPORTED.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                    notificationReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(notificationReceiver, intentFilter);
        }
        // NotificationReceiver is a BroadcastReceiver — do NOT startService it.
        // registerReceiver above is enough to receive notification broadcasts.
        Log.i(TAG, "Registered the notifications tracking receiver.");
    }

    @Override
    public void onCancel(Object arguments) {
        if (notificationReceiver != null) {
            try {
                context.unregisterReceiver(notificationReceiver);
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "Receiver already unregistered");
            }
            notificationReceiver = null;
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_CODE_FOR_NOTIFICATIONS) {
            return false;
        }

        Result result = pendingPermissionResult;
        pendingPermissionResult = null;
        if (result == null) {
            // Already replied or no pending request — ignore safely
            return true;
        }

        // Settings screen usually returns RESULT_CANCELED; check actual grant state
        try {
            result.success(isPermissionGranted(context));
        } catch (IllegalStateException e) {
            Log.w(TAG, "Permission result already submitted: " + e.getMessage());
        }
        return true;
    }
}
