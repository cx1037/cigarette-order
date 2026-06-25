package com.example.flutter_application_1

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class LogistaAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "SmokeAutomation"
        private var instance: LogistaAccessibilityService? = null

        private var isRunning = false
        private var _currentStep = 0
        private var _totalSteps = 0
        private var _statusMessage = ""
        private var _steps: List<Map<String, Any?>> = emptyList()
        private var _pendingFinish = false

        var onStatusUpdate: ((String) -> Unit)? = null
        var onStepUpdate: ((Int, Int) -> Unit)? = null
        var onFinished: (() -> Unit)? = null
        var onError: ((String) -> Unit)? = null

        fun setSteps(steps: List<Map<String, Any?>>) {
            _steps = steps
        }

        fun startAutomation() {
            isRunning = true
            _currentStep = 0
            _totalSteps = _steps.size
            _pendingFinish = false
            _statusMessage = "等待浏览器打开..."
            onStatusUpdate?.invoke(_statusMessage)
            instance?._startMonitoring()
        }

        fun stopAutomation() {
            isRunning = false
            _currentStep = 0
            _totalSteps = 0
            _statusMessage = "已停止"
            _pendingFinish = false
            onStatusUpdate?.invoke(_statusMessage)
            onFinished?.invoke()
            instance?._stopMonitoring()
        }

        fun getState(): Map<String, Any?> {
            return mapOf(
                "isRunning" to isRunning,
                "currentStep" to _currentStep,
                "totalSteps" to _totalSteps,
                "statusMessage" to _statusMessage
            )
        }

        fun isServiceReady(): Boolean = instance != null

        private val browserPackages = setOf(
            "com.android.chrome",
            "com.sec.android.app.sbrowser",
            "org.mozilla.firefox",
            "com.opera.browser",
            "com.microsoft.emmx",
            "com.brave.browser",
            "com.chrome.beta",
            "com.android.webview",
            "org.chromium.webview"
        )
    }

    private val handler = Handler(Looper.getMainLooper())
    private var _monitoring = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        _statusMessage = "辅助服务已连接"
        onStatusUpdate?.invoke(_statusMessage)
        Log.d(TAG, "Accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!isRunning || _pendingFinish) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            val pkg = event.packageName?.toString() ?: ""
            val isBrowser = browserPackages.any { pkg.contains(it) } ||
                    pkg.contains("browser", ignoreCase = true) ||
                    pkg.contains("chrome", ignoreCase = true) ||
                    pkg.contains("webview", ignoreCase = true)

            if (isBrowser && !_monitoring) {
                _monitoring = true
                _statusMessage = "检测到浏览器，等待页面加载..."
                onStatusUpdate?.invoke(_statusMessage)
                handler.removeCallbacksAndMessages(null)
                handler.postDelayed({
                    if (isRunning && !_pendingFinish) _executeSteps()
                }, 2000)
            }
        }
    }

    private fun _startMonitoring() {
        _monitoring = false
    }

    private fun _stopMonitoring() {
        _monitoring = false
        handler.removeCallbacksAndMessages(null)
    }

    private fun _executeSteps() {
        if (!isRunning) return
        _executeStep(0)
    }

    private fun _executeStep(index: Int) {
        if (!isRunning || _pendingFinish || index >= _steps.size) {
            _finishAutomation()
            return
        }

        _currentStep = index + 1
        _totalSteps = _steps.size
        onStepUpdate?.invoke(_currentStep, _totalSteps)

        val step = _steps[index]
        val type = (step["type"] as? String) ?: ""
        val value = (step["value"] as? String) ?: ""
        val timeoutMs = (step["timeoutMs"] as? Number)?.toLong() ?: 5000L

        _statusMessage = "步骤 $_currentStep/$_totalSteps: ${_stepLabel(type, value)}"
        onStatusUpdate?.invoke(_statusMessage)
        Log.d(TAG, "Step $index: type=$type value=$value")

        when (type) {
            "check_text" -> _checkText(value, index)
            "check_input_empty" -> _checkInputEmpty(value, index)
            "click_text" -> _tryClickText(value, index)
            "click_desc" -> _tryClickDesc(value, index)
            "wait" -> {
                val waitMs = value.toLongOrNull() ?: timeoutMs
                _statusMessage = "等待 ${waitMs}ms..."
                onStatusUpdate?.invoke(_statusMessage)
                handler.postDelayed({ _executeStep(index + 1) }, waitMs)
            }
            "navigate_back" -> {
                performGlobalAction(GLOBAL_ACTION_BACK)
                handler.postDelayed({ _executeStep(index + 1) }, 600)
            }
            "finish" -> _finishAutomation()
            else -> {
                _statusMessage = "未知操作: $type"
                onError?.invoke("未知操作类型: $type")
                _finishAutomation()
            }
        }
    }

    private fun _stepLabel(type: String, value: String): String = when (type) {
        "check_text" -> "检查文字: $value"
        "check_input_empty" -> "检查输入框: $value"
        "click_text" -> "点击「$value」"
        "click_desc" -> "点击「$value」"
        "wait" -> "等待 ${value}ms"
        "navigate_back" -> "返回"
        "finish" -> "完成"
        else -> type
    }

    private fun _checkText(text: String, index: Int) {
        _statusMessage = "检查页面是否包含: $text"
        onStatusUpdate?.invoke(_statusMessage)
        handler.postDelayed({
            if (!isRunning || _pendingFinish) return@postDelayed
            if (_containsText(text)) {
                _statusMessage = "检测到登录页面，请先登录Logista"
                onStatusUpdate?.invoke(_statusMessage)
                onError?.invoke("检测到登录页面，请先在浏览器中登录Logista后再执行自动化")
                _finishAutomation()
            } else {
                _executeStep(index + 1)
            }
        }, 1000)
    }

    private fun _containsText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val found = _searchText(root, text)
        root.recycle()
        return found
    }

    private fun _searchText(node: AccessibilityNodeInfo, text: String): Boolean {
        val nodeText = node.text?.toString() ?: ""
        val nodeDesc = node.contentDescription?.toString() ?: ""
        if (nodeText.contains(text, ignoreCase = true) || nodeDesc.contains(text, ignoreCase = true)) {
            return true
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (_searchText(child, text)) {
                child.recycle()
                return true
            }
            child.recycle()
        }
        return false
    }

    private fun _checkInputEmpty(text: String, index: Int) {
        _statusMessage = "检查输入框是否为空: $text"
        onStatusUpdate?.invoke(_statusMessage)
        handler.postDelayed({
            if (!isRunning || _pendingFinish) return@postDelayed
            if (_isInputFieldEmpty(text)) {
                _statusMessage = "请输入$text后再执行自动化"
                onStatusUpdate?.invoke(_statusMessage)
                onError?.invoke("检测到「$text」输入框为空，请在浏览器中先填写账号密码后再执行自动化")
                _finishAutomation()
            } else {
                _executeStep(index + 1)
            }
        }, 1000)
    }

    private fun _isInputFieldEmpty(hint: String): Boolean {
        val root = rootInActiveWindow ?: return true
        val isEmpty = _findEmptyField(root, hint)
        root.recycle()
        return isEmpty
    }

    private fun _findEmptyField(node: AccessibilityNodeInfo, hint: String): Boolean {
        val isEditText = node.className?.toString()?.contains("EditText", ignoreCase = true) == true
        if (isEditText || node.isEditable) {
            val nodeHint = node.hintText?.toString() ?: ""
            val nodeDesc = node.contentDescription?.toString() ?: ""
            if (nodeHint.contains(hint, ignoreCase = true) || nodeDesc.contains(hint, ignoreCase = true)) {
                val text = node.text?.toString() ?: ""
                return text.trim().isEmpty()
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = _findEmptyField(child, hint)
            child.recycle()
            if (found) return true
        }
        return false
    }

    private fun _tryClickText(text: String, index: Int) {
        if (_doClickByText(text)) {
            handler.postDelayed({ _executeStep(index + 1) }, 800)
        } else {
            handler.postDelayed({
                if (isRunning && !_pendingFinish) {
                    if (_doClickByText(text)) {
                        handler.postDelayed({ _executeStep(index + 1) }, 800)
                    } else {
                        _statusMessage = "未找到: $text"
                        onError?.invoke("未找到包含文字「$text」的按钮/链接，请检查步骤配置")
                        _finishAutomation()
                    }
                }
            }, 1500)
        }
    }

    private fun _tryClickDesc(desc: String, index: Int) {
        if (_doClickByDesc(desc)) {
            handler.postDelayed({ _executeStep(index + 1) }, 800)
        } else {
            handler.postDelayed({
                if (isRunning && !_pendingFinish) {
                    if (_doClickByDesc(desc)) {
                        handler.postDelayed({ _executeStep(index + 1) }, 800)
                    } else {
                        _statusMessage = "未找到: $desc"
                        onError?.invoke("未找到描述为「$desc」的元素，请检查步骤配置")
                        _finishAutomation()
                    }
                }
            }, 1500)
        }
    }

    private fun _doClickByText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val candidates = mutableListOf<AccessibilityNodeInfo>()
        _collectClickableByText(root, text, candidates)

        var clicked = false
        for (node in candidates) {
            if (node.isVisibleToUser) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                clicked = true
                node.recycle()
                break
            }
        }
        if (!clicked && candidates.isNotEmpty()) {
            candidates.first().performAction(AccessibilityNodeInfo.ACTION_CLICK)
            clicked = true
        }
        candidates.forEach { it.recycle() }
        root.recycle()
        return clicked
    }

    private fun _doClickByDesc(desc: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val candidates = mutableListOf<AccessibilityNodeInfo>()
        _collectClickableByDesc(root, desc, candidates)

        var clicked = false
        for (node in candidates) {
            if (node.isVisibleToUser) {
                node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                clicked = true
                node.recycle()
                break
            }
        }
        if (!clicked && candidates.isNotEmpty()) {
            candidates.first().performAction(AccessibilityNodeInfo.ACTION_CLICK)
            clicked = true
        }
        candidates.forEach { it.recycle() }
        root.recycle()
        return clicked
    }

    private fun _collectClickableByText(
        node: AccessibilityNodeInfo,
        text: String,
        results: MutableList<AccessibilityNodeInfo>
    ) {
        val nodeText = node.text?.toString() ?: ""
        val nodeDesc = node.contentDescription?.toString() ?: ""
        if ((nodeText.contains(text, ignoreCase = true) || nodeDesc.contains(text, ignoreCase = true))
            && node.isClickable
        ) {
            results.add(node)
            return
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            _collectClickableByText(child, text, results)
        }
    }

    private fun _collectClickableByDesc(
        node: AccessibilityNodeInfo,
        desc: String,
        results: MutableList<AccessibilityNodeInfo>
    ) {
        val nodeDesc = node.contentDescription?.toString() ?: ""
        if (nodeDesc.contains(desc, ignoreCase = true) && node.isClickable) {
            results.add(node)
            return
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            _collectClickableByDesc(child, desc, results)
        }
    }

    private fun _finishAutomation() {
        _pendingFinish = true
        isRunning = false
        _currentStep = 0
        _totalSteps = 0
        _statusMessage = "自动化完成"
        _monitoring = false
        onStatusUpdate?.invoke(_statusMessage)
        onFinished?.invoke()
        handler.removeCallbacksAndMessages(null)
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
        isRunning = false
        _monitoring = false
        _pendingFinish = true
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isRunning = false
        _monitoring = false
        _pendingFinish = true
        handler.removeCallbacksAndMessages(null)
    }
}
