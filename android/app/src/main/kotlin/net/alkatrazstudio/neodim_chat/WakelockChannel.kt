package net.alkatrazstudio.neodim_chat

import android.app.Activity
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "net.alkatrazstudio.neodim_chat/wakelock"

private fun set(isEnable: Boolean, activity: Activity) {
    if(isEnable)
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    else
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
}

private fun onMethodCall(call: MethodCall, result: MethodChannel.Result, activity: Activity) {
    try {
        when(call.method) {
            "set" -> set(call.arguments<Boolean>() ?: true, activity)
            else -> result.notImplemented()
        }
    } catch(e: Throwable) {
        result.error(e.javaClass.name, e.message, null)
    }
}

class WakelockChannel {
    companion object {
        fun register(flutterEngine: FlutterEngine, activity: Activity) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result -> onMethodCall(call, result, activity)
            }
        }
    }
}
