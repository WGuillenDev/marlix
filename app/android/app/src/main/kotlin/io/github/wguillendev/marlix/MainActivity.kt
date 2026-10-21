package io.github.wguillendev.marlix

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Free space where the app keeps the voice model (S6-2): Dart has no API for it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "marlix/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "freeBytes") {
                    result.success(StatFs(filesDir.path).availableBytes)
                } else {
                    result.notImplemented()
                }
            }
    }
}
