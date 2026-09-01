package notification.listener.service;

import android.content.Context;
import android.util.Log;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Shared on-disk queue. The listener may run in process {@code :nls} while
 * Flutter runs in the default process — both share this app's data dir.
 */
public final class NotificationQueueStore {
    private static final String TAG = "NotificationQueue";
    public static final String FILE_NAME = "pending_notifications.jsonl";

    private NotificationQueueStore() {}

    public static File[] files(Context context) {
        Context app = context.getApplicationContext();
        File filesDir = new File(app.getFilesDir(), FILE_NAME);
        File flutterDir = new File(app.getApplicationInfo().dataDir, "app_flutter");
        if (!flutterDir.exists()) {
            // noinspection ResultOfMethodCallIgnored
            flutterDir.mkdirs();
        }
        File flutterFile = new File(flutterDir, FILE_NAME);
        return new File[] {flutterFile, filesDir};
    }

    public static synchronized void append(Context context, JSONObject json) {
        byte[] line = (json.toString() + "\n").getBytes(StandardCharsets.UTF_8);
        for (File file : files(context)) {
            try {
                File parent = file.getParentFile();
                if (parent != null && !parent.exists()) {
                    // noinspection ResultOfMethodCallIgnored
                    parent.mkdirs();
                }
                FileOutputStream fos = new FileOutputStream(file, true);
                try {
                    fos.write(line);
                    fos.flush();
                } finally {
                    fos.close();
                }
            } catch (Exception e) {
                Log.w(TAG, "append failed for " + file + ": " + e.getMessage());
            }
        }
    }

    public static synchronized List<Map<String, Object>> drain(Context context) {
        List<Map<String, Object>> items = new ArrayList<>();
        for (File file : files(context)) {
            if (!file.exists() || file.length() == 0) continue;
            try {
                RandomAccessFile raf = new RandomAccessFile(file, "rw");
                try {
                    byte[] buf = new byte[(int) Math.min(file.length(), 2 * 1024 * 1024)];
                    int read = raf.read(buf);
                    raf.setLength(0);
                    if (read <= 0) continue;
                    String raw = new String(buf, 0, read, StandardCharsets.UTF_8);
                    for (String line : raw.split("\n")) {
                        String trimmed = line.trim();
                        if (trimmed.isEmpty()) continue;
                        try {
                            items.add(jsonToMap(new JSONObject(trimmed)));
                        } catch (Exception ignored) {
                        }
                    }
                } finally {
                    raf.close();
                }
            } catch (Exception e) {
                Log.w(TAG, "drain failed for " + file + ": " + e.getMessage());
            }
        }
        return items;
    }

    private static Map<String, Object> jsonToMap(JSONObject o) {
        Map<String, Object> map = new HashMap<>();
        Iterator<String> keys = o.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = o.opt(key);
            if (value == null || value == JSONObject.NULL) continue;
            map.put(key, value);
        }
        return map;
    }
}
