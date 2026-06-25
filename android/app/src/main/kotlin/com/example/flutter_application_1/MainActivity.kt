package com.example.flutter_application_1

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_application_1/accessibility"
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceReady" -> {
                    result.success(LogistaAccessibilityService.isServiceReady())
                }
                "startAutomation" -> {
                    val stepsRaw = call.argument<String>("steps")
                    if (stepsRaw != null) {
                        val steps = parseSteps(stepsRaw)
                        LogistaAccessibilityService.setSteps(steps)
                    }
                    LogistaAccessibilityService.startAutomation()
                    result.success(true)
                }
                "stopAutomation" -> {
                    LogistaAccessibilityService.stopAutomation()
                    result.success(true)
                }
                "getState" -> {
                    result.success(LogistaAccessibilityService.getState())
                }
                "setSteps" -> {
                    val stepsRaw = call.argument<String>("steps")
                    if (stepsRaw != null) {
                        val steps = parseSteps(stepsRaw)
                        LogistaAccessibilityService.setSteps(steps)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun parseSteps(json: String): List<Map<String, Any?>> {
        val steps = mutableListOf<Map<String, Any?>>()
        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val map = mutableMapOf<String, Any?>()
                for (key in obj.keys()) {
                    map[key] = when (val v = obj.get(key)) {
                        is JSONObject -> v.toString()
                        is JSONArray -> v.toString()
                        else -> v
                    }
                }
                steps.add(map)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return steps
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
    }
}
