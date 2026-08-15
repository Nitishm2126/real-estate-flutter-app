package com.example.mcp_avadi

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mcp_avadi/app_check"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isAppInstalled") {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    result.success(isPackageInstalled(packageName))
                } else {
                    result.error("INVALID_ARGUMENT", "Package name is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            val pm = context.packageManager
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
