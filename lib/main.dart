import 'package:flutter/widgets.dart';

import 'app.dart' deferred as app;

/// Smallest possible first frame so Android can drop the native splash.
/// Heavy imports (GetX, Hive, notification history) load only after that.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ColoredBox(
      color: Color(0xFF121212),
      child: SizedBox.expand(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadApp();
  });
}

Future<void> _loadApp() async {
  try {
    await app.loadLibrary();
    app.start();
  } catch (e, st) {
    debugPrint('App load failed: $e\n$st');
  }
}
