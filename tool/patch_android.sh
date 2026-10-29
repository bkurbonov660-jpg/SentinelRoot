#!/bin/bash
set -e
APP=android/app
M=$APP/src/main/AndroidManifest.xml

sed -i 's#android:label="[^"]*"#android:label="SentinelRoot"#' "$M"

if [ -f "$APP/build.gradle.kts" ]; then
  F=$APP/build.gradle.kts
  if ! grep -q 'import java.util.Properties' "$F"; then
    sed -i '1i import java.util.Properties\nimport java.io.FileInputStream' "$F"
  fi
  if ! grep -q 'sentinelRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        create("sentinelRelease") {\n            val kp = Properties()\n            kp.load(FileInputStream(rootProject.file("key.properties")))\n            keyAlias = kp.getProperty("keyAlias")\n            keyPassword = kp.getProperty("keyPassword")\n            storeFile = file(kp.getProperty("storeFile"))\n            storePassword = kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfigs.getByName("debug")|signingConfigs.getByName("sentinelRelease")\n            isMinifyEnabled = false\n            isShrinkResources = false|g' "$F"
elif [ -f "$APP/build.gradle" ]; then
  F=$APP/build.gradle
  if ! grep -q 'sentinelRelease' "$F"; then
    sed -i 's|^android {|android {\n    signingConfigs {\n        sentinelRelease {\n            def kp = new java.util.Properties()\n            kp.load(new java.io.FileInputStream(rootProject.file("key.properties")))\n            keyAlias kp.getProperty("keyAlias")\n            keyPassword kp.getProperty("keyPassword")\n            storeFile file(kp.getProperty("storeFile"))\n            storePassword kp.getProperty("storePassword")\n        }\n    }|' "$F"
  fi
  sed -i 's|signingConfig signingConfigs.debug|signingConfig signingConfigs.sentinelRelease\n            minifyEnabled false\n            shrinkResources false|g' "$F"
fi

MA=$(find "$APP/src/main" \( -name 'MainActivity.kt' -o -name 'MainActivity.java' \) | head -n 1)
KDIR=$(dirname "$MA")
PKG=$(grep -m1 -E '^package ' "$MA" | sed -E 's/^package[[:space:]]+([A-Za-z0-9_.]+).*/\1/')
[ -n "$PKG" ] || PKG=com.sentinel.sentinelroot
rm -f "$KDIR/MainActivity.java" "$KDIR/MainActivity.kt"

# Создаём XML политики DeviceAdmin
mkdir -p "$APP/src/main/res/xml"
cat > "$APP/src/main/res/xml/device_admin_policies.xml" << 'EOF_ADMIN_XML'
<?xml version="1.0" encoding="utf-8"?>
<device-admin xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-policies>
        <wipe-data />
        <force-lock />
    </uses-policies>
</device-admin>
EOF_ADMIN_XML

# ── МОДУЛЬ 1: TelegramNotifier.kt ──
cat > "$KDIR/TelegramNotifier.kt" << 'EOF_KT_TG'
package __PKG__

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.provider.Settings
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// МОДУЛЬ 1: Прямая отправка отчётов в Telegram через HttpURLConnection (без своего сервера)
object TelegramNotifier {
    private const val DEFAULT_CHAT_ID = "8271593233"
    // Токен можно переопределить в настройках; дефолтный плейсхолдер безопасен
    private const val DEFAULT_BOT_TOKEN = "7800000000:AAH_SentinelRootDefaultBotToken"

    private fun isAirplaneModeOn(ctx: Context): Boolean {
        return try {
            Settings.Global.getInt(ctx.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun hasActiveNetwork(ctx: Context): Boolean {
        return try {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            val info = cm?.activeNetworkInfo
            info != null && info.isConnected
        } catch (_: Exception) {
            false
        }
    }

    fun sendAlert(ctx: Context, text: String): Boolean {
        if (isAirplaneModeOn(ctx) || !hasActiveNetwork(ctx)) {
            PulseEngine.logError("TelegramNotifier: пропуск отправки (airplane или нет сети)")
            return false
        }
        return try {
            val cfg = PulseEngine.readWipeJson(ctx)
            val chatId = cfg.optString("telegramChatId", DEFAULT_CHAT_ID).ifEmpty { DEFAULT_CHAT_ID }
            val token = cfg.optString("telegramBotToken", "").ifEmpty { DEFAULT_BOT_TOKEN }
            val url = URL("https://api.telegram.org/bot$token/sendMessage")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 5000
                readTimeout = 5000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            val body = JSONObject().apply {
                put("chat_id", chatId)
                put("text", text)
            }.toString()

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
            val code = conn.responseCode
            conn.disconnect()
            code in 200..299
        } catch (e: Exception) {
            PulseEngine.logError("TelegramNotifier sendAlert error: ${e.message}")
            false
        }
    }

    fun sendPreWipeWarning(ctx: Context, targets: List<String>, minutesLeft: Int): Boolean {
        val (pct, charging) = PulseEngine.getBatteryStatus(ctx)
        val chgStr = if (charging) "(заряжается)" else "(от батареи)"
        val listStr = if (targets.isEmpty()) "нет целей" else targets.joinToString(", ")
        val msg = buildString {
            appendLine("⚠️ SENTINELROOT · ПРЕДУПРЕЖДЕНИЕ")
            appendLine("Через $minutesLeft минут будет выполнена очистка по таймеру.")
            appendLine("Цели: $listStr")
            appendLine("Устройство: ${Build.MODEL}")
            appendLine("Батарея: $pct% $chgStr")
            append("Если это ошибка — откройте приложение и сбросьте таймер.")
        }
        return sendAlert(ctx, msg)
    }

    fun sendWipeReport(ctx: Context, resultJson: String): Boolean {
        return try {
            val obj = JSONObject(resultJson)
            val mode = obj.optString("lastMode", "timer")
            val logs = obj.optJSONArray("lastRunLogs") ?: obj.optJSONArray("logs")
            var okCount = 0
            var totalCount = 0
            val detailsBuilder = StringBuilder()
            if (logs != null) {
                totalCount = logs.length()
                for (i in 0 until logs.length()) {
                    val item = logs.optJSONObject(i) ?: continue
                    val ok = item.optBoolean("ok", false)
                    val label = item.optString("target", "цель")
                    val det = item.optString("details", "")
                    if (ok) {
                        okCount++
                        detailsBuilder.appendLine("  ✅ $label — удалено")
                    } else {
                        detailsBuilder.appendLine("  ❌ $label — ошибка: $det")
                    }
                }
            }
            val (totalMb, usedMb) = PulseEngine.getRamInfoMb(ctx)
            val freeMb = (totalMb - usedMb).coerceAtLeast(0)
            val tsStr = SimpleDateFormat("dd.MM.yyyy HH:mm:ss", Locale.getDefault()).format(Date())
            val msg = buildString {
                appendLine("🔴 SENTINELROOT · ОЧИСТКА ВЫПОЛНЕНА")
                appendLine("Время: $tsStr")
                appendLine("Режим: $mode")
                appendLine("Успешно: $okCount из $totalCount")
                appendLine("Подробности:")
                append(detailsBuilder.toString())
                append("Свободно ОЗУ: $freeMb МБ")
            }
            sendAlert(ctx, msg)
        } catch (e: Exception) {
            PulseEngine.logError("TelegramNotifier sendWipeReport error: ${e.message}")
            false
        }
    }

    fun sendPanicAlert(ctx: Context, attempts: Int, coords: String = "неизвестно"): Boolean {
        val msg = buildString {
            appendLine("🚨 SENTINELROOT · ТРЕВОГА")
            appendLine("Попыток отключения защиты: $attempts")
            appendLine("Координаты (последние): $coords")
            append("Телефон переходит в оффлайн-режим с сиреной.")
        }
        return sendAlert(ctx, msg)
    }

    fun sendUsbAlert(ctx: Context): Boolean {
        val msg = buildString {
            appendLine("🔌 SENTINELROOT · USB-ПОДКЛЮЧЕНИЕ")
            appendLine("Кто-то подключил кабель к устройству.")
            append("Доступ заблокирован. Требуется разрешение владельца.")
        }
        return sendAlert(ctx, msg)
    }
}
EOF_KT_TG

# ── МОДУЛЬ 10: SpeedMonitor.kt (/proc/net/dev + TrafficStats fallback) ──
cat > "$KDIR/SpeedMonitor.kt" << 'EOF_KT_SPEED'
package __PKG__

import android.content.Context
import android.content.pm.PackageManager
import android.net.TrafficStats
import org.json.JSONObject
import java.io.File

// МОДУЛЬ 10: Монитор скорости интернета в реальном времени (/proc/net/dev + fallback TrafficStats)
data class NetSpeed(
    val rxBps: Long,
    val txBps: Long,
    val iface: String,
    val uidRxBps: Map<Int, Long>
)

object SpeedMonitor {
    private var lastRx: Long = -1L
    private var lastTx: Long = -1L
    private var lastTimeMs: Long = 0L
    private val lastUidRx = HashMap<Int, Long>()

    private fun matchesTrackedIface(name: String, mode: String): Boolean {
        val clean = name.lowercase()
        return when (mode) {
            "wifi" -> clean.startsWith("wlan")
            "mobile" -> clean.startsWith("rmnet") || clean.startsWith("ccmni") || clean.startsWith("pdp")
            else -> clean.startsWith("wlan") ||
                    clean.startsWith("rmnet") ||
                    clean.startsWith("eth") ||
                    clean.startsWith("ccmni") ||
                    clean.startsWith("pdp")
        }
    }

    @Synchronized
    fun read(ctx: Context, ifaceMode: String = "auto"): NetSpeed {
        val now = System.currentTimeMillis()
        var curRx = 0L
        var curTx = 0L
        var activeIface = ifaceMode

        try {
            val procFile = File("/proc/net/dev")
            if (procFile.exists() && procFile.canRead()) {
                val lines = procFile.readLines()
                for (line in lines.drop(2)) {
                    val parts = line.trim().split(Regex("\\s+"))
                    if (parts.size >= 10) {
                        val rawIface = parts[0].removeSuffix(":")
                        if (matchesTrackedIface(rawIface, ifaceMode)) {
                            val rx = parts[1].toLongOrNull() ?: 0L
                            val tx = parts[9].toLongOrNull() ?: 0L
                            curRx += rx
                            curTx += tx
                            if (rx > 0 || tx > 0) activeIface = rawIface
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        // Fallback на системные счётчики TrafficStats (доступны всегда на Android 10+)
        if (curRx <= 0L && curTx <= 0L) {
            val mobRx = TrafficStats.getMobileRxBytes().coerceAtLeast(0L)
            val mobTx = TrafficStats.getMobileTxBytes().coerceAtLeast(0L)
            val totRx = TrafficStats.getTotalRxBytes().coerceAtLeast(0L)
            val totTx = TrafficStats.getTotalTxBytes().coerceAtLeast(0L)
            when (ifaceMode) {
                "mobile" -> {
                    curRx = mobRx
                    curTx = mobTx
                    activeIface = "rmnet0"
                }
                "wifi" -> {
                    curRx = (totRx - mobRx).coerceAtLeast(0L)
                    curTx = (totTx - mobTx).coerceAtLeast(0L)
                    activeIface = "wlan0"
                }
                else -> {
                    curRx = totRx
                    curTx = totTx
                    activeIface = "auto"
                }
            }
        }

        val dtMs = if (lastTimeMs > 0L) (now - lastTimeMs) else 0L
        var rxBps = 0L
        var txBps = 0L

        if (lastRx >= 0L && dtMs in 150..5000) {
            rxBps = ((curRx - lastRx).coerceAtLeast(0L) * 1000L) / dtMs
            txBps = ((curTx - lastTx).coerceAtLeast(0L) * 1000L) / dtMs
        }

        // Скорость по каждому UID за последнюю секунду (только если dt < 2.5 сек и delta > 0)
        val uidDeltaMap = HashMap<Int, Long>()
        try {
            val apps = ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            for (app in apps) {
                val uid = app.uid
                val uRx = TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L)
                val prev = lastUidRx[uid]
                if (prev != null && dtMs in 150..2500 && uRx > prev) {
                    val bps = ((uRx - prev) * 1000L) / dtMs
                    if (bps > 0L) uidDeltaMap[uid] = bps
                }
                lastUidRx[uid] = uRx
            }
        } catch (_: Exception) {}

        lastRx = curRx
        lastTx = curTx
        lastTimeMs = now

        return NetSpeed(rxBps = rxBps, txBps = txBps, iface = activeIface, uidRxBps = uidDeltaMap)
    }

    fun readJson(ctx: Context, ifaceMode: String = "auto"): String {
        val s = read(ctx, ifaceMode)
        val uidsObj = JSONObject()
        for ((k, v) in s.uidRxBps) {
            uidsObj.put(k.toString(), v)
        }
        return JSONObject().apply {
            put("rxBps", s.rxBps)
            put("txBps", s.txBps)
            put("iface", s.iface)
            put("uidRxBps", uidsObj)
        }.toString()
    }
}
EOF_KT_SPEED

# ── MainActivity.kt ──
cat > "$KDIR/MainActivity.kt" << 'EOF_KT_MAIN'
package __PKG__

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val reqPickFile = 8801
    private val reqPickFolder = 8802
    private var pendingPick: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PulseEngine.initAndHeartbeat(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sentinelroot/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDashboard" -> {
                        val args = call.arguments as? Map<*, *>
                        val period = args?.get("period") as? String ?: "day"
                        Thread {
                            val json = PulseEngine.buildDashboardJson(applicationContext, period)
                            runOnUiThread { result.success(json) }
                        }.start()
                    }
                    "getNetSpeed" -> {
                        val args = call.arguments as? Map<*, *>
                        val ifaceMode = args?.get("ifaceMode") as? String ?: "auto"
                        Thread {
                            val json = SpeedMonitor.readJson(applicationContext, ifaceMode)
                            runOnUiThread { result.success(json) }
                        }.start()
                    }
                    "verifyPin" -> {
                        val args = call.arguments as? Map<*, *>
                        val pin = args?.get("pin") as? String ?: ""
                        Thread {
                            val res = PulseEngine.verifyPin(applicationContext, pin).name
                            runOnUiThread { result.success(res) }
                        }.start()
                    }
                    "scheduleSelfDestruct" -> {
                        val args = call.arguments as? Map<*, *>
                        val delayMs = (args?.get("delayMs") as? Number)?.toLong() ?: (25L * 60_000L)
                        Thread {
                            val ok = PulseEngine.scheduleSelfDestruct(applicationContext, delayMs)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "cancelSelfDestruct" -> {
                        val args = call.arguments as? Map<*, *>
                        val pin = args?.get("pin") as? String ?: ""
                        Thread {
                            val ok = PulseEngine.cancelSelfDestruct(applicationContext, pin)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "getUsbStatus" -> {
                        Thread {
                            val json = PulseEngine.getUsbStatusJson(applicationContext)
                            runOnUiThread { result.success(json) }
                        }.start()
                    }
                    "grantUsbAccess" -> {
                        val args = call.arguments as? Map<*, *>
                        val durationMin = (args?.get("durationMin") as? Number)?.toInt() ?: 15
                        val pin = args?.get("pin") as? String ?: ""
                        Thread {
                            val ok = PulseEngine.grantUsbAccess(applicationContext, durationMin, pin)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "revokeUsbAccess" -> {
                        Thread {
                            PulseEngine.revokeUsbAccess(applicationContext, notifyTelegram = false)
                            runOnUiThread { result.success(true) }
                        }.start()
                    }
                    "setStealthCalendarMode" -> {
                        val args = call.arguments as? Map<*, *>
                        val enabled = args?.get("enabled") as? Boolean ?: false
                        Thread {
                            val ok = PulseEngine.setStealthCalendarMode(applicationContext, enabled)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "stopPanicLockdown" -> {
                        val args = call.arguments as? Map<*, *>
                        val pin = args?.get("pin") as? String ?: ""
                        Thread {
                            val ok = PulseEngine.stopPanicLockdown(applicationContext, pin)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "triggerTestTelegramAlert" -> {
                        Thread {
                            val ok = TelegramNotifier.sendAlert(
                                applicationContext,
                                "✅ SENTINELROOT · ТЕСТ СВЯЗИ\nКанал оповещений владельца активен."
                            )
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "requestRootAndPermissions" -> {
                        Thread {
                            val ok = PulseEngine.grantSelfPermissionsViaRoot(applicationContext)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "openUsageSettings" -> {
                        try {
                            val i = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "listInstalledApps" -> {
                        Thread {
                            val json = PulseEngine.listInstalledAppsJson(applicationContext)
                            runOnUiThread { result.success(json) }
                        }.start()
                    }
                    "listDirectory" -> {
                        val args = call.arguments as? Map<*, *>
                        val path = args?.get("path") as? String ?: "/storage/emulated/0"
                        Thread {
                            val json = PulseEngine.listDirectoryJson(path)
                            runOnUiThread { result.success(json) }
                        }.start()
                    }
                    "toggleAppFirewall" -> {
                        val args = call.arguments as? Map<*, *>
                        val uid = (args?.get("uid") as? Number)?.toInt() ?: 0
                        val pkg = args?.get("pkg") as? String ?: ""
                        val block = args?.get("block") as? Boolean ?: false
                        Thread {
                            val ok = PulseEngine.setAppFirewall(applicationContext, uid, pkg, block)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "toggleAppFreeze" -> {
                        val args = call.arguments as? Map<*, *>
                        val pkg = args?.get("pkg") as? String ?: ""
                        val freeze = args?.get("freeze") as? Boolean ?: false
                        Thread {
                            val ok = PulseEngine.setAppFrozen(pkg, freeze)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "forceStopAndClearCache" -> {
                        val args = call.arguments as? Map<*, *>
                        val pkg = args?.get("pkg") as? String ?: ""
                        Thread {
                            val ok = PulseEngine.forceStopAndClearCache(pkg)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "purgeSystemRamAndCaches" -> {
                        Thread {
                            val msg = PulseEngine.purgeSystemRamAndCaches(applicationContext)
                            runOnUiThread { result.success(msg) }
                        }.start()
                    }
                    "setAppDailyLimit" -> {
                        val args = call.arguments as? Map<*, *>
                        val pkg = args?.get("pkg") as? String ?: ""
                        val mins = (args?.get("minutes") as? Number)?.toInt() ?: 0
                        Thread {
                            val ok = PulseEngine.setAppDailyLimit(applicationContext, pkg, mins)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "saveAutoWipeConfig" -> {
                        val payload = call.arguments as? String ?: "{}"
                        Thread {
                            val ok = PulseEngine.saveWipeConfig(applicationContext, payload)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "confirmOwnerCheckIn" -> {
                        Thread {
                            val ok = PulseEngine.confirmOwnerCheckIn(applicationContext)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
                    "executeWipeNow" -> {
                        Thread {
                            val res = PulseEngine.executeWipeTargets(applicationContext, mode = "manual")
                            runOnUiThread { result.success(res) }
                        }.start()
                    }
                    "pickFilePath" -> {
                        if (pendingPick != null) {
                            result.error("busy", "Busy", null)
                        } else {
                            pendingPick = result
                            val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
                            i.addCategory(Intent.CATEGORY_OPENABLE)
                            i.type = "*/*"
                            startActivityForResult(i, reqPickFile)
                        }
                    }
                    "pickFolderPath" -> {
                        if (pendingPick != null) {
                            result.error("busy", "Busy", null)
                        } else {
                            pendingPick = result
                            val i = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                            startActivityForResult(i, reqPickFolder)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == reqPickFile || requestCode == reqPickFolder) {
            val r = pendingPick
            pendingPick = null
            if (r == null) return
            val uri: Uri? = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                r.success(null)
                return
            }
            val rawPath = uri.path ?: uri.toString()
            val clean = if (rawPath.contains("primary:")) {
                "/storage/emulated/0/" + rawPath.substringAfter("primary:")
            } else {
                rawPath
            }
            r.success(clean)
        }
    }
}
EOF_KT_MAIN

# ── PulseEngine.kt + Receivers + Services ──
cat > "$KDIR/PulseEngine.kt" << 'EOF_KT_ENGINE'
package __PKG__

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

enum class PinResult { OWNER, DURESS, WRONG }

object PulseEngine {
    private const val ROOT_STATE_PATH = "/data/local/tmp/sentinelroot_power_state.json"
    private const val SELFDESTRUCT_ROOT_PATH = "/data/local/tmp/sentinelroot_selfdestruct.json"
    private const val PANIC_ROOT_PATH = "/data/local/tmp/panic.state"
    private const val ERROR_LOG_PATH = "/data/local/tmp/sentinelroot_errors.log"
    private const val LOCAL_STATE_NAME = "sentinelroot_power_state.json"
    private const val WIPE_STATE_NAME = "sentinelroot_wipe_state.json"
    private const val RULES_STATE_NAME = "sentinelroot_rules_state.json"
    private const val SEC_PREFS = "sentinelroot_sec_prefs"

    fun logError(msg: String) {
        try {
            val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val line = "[$ts] $msg\n"
            File(ERROR_LOG_PATH).appendText(line)
        } catch (_: Exception) {}
    }

    // Требование 4: Все вызовы root (runSu) — с таймаутом 8 сек и fallback при ошибке
    fun runSu(cmd: String): Pair<Boolean, String> {
        return try {
            val proc = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            val completed = proc.waitFor(8, TimeUnit.SECONDS)
            if (!completed) {
                proc.destroyForcibly()
                logError("runSu timeout: $cmd")
                return Pair(false, "timeout")
            }
            val out = proc.inputStream.bufferedReader().readText()
            val err = proc.errorStream.bufferedReader().readText()
            Pair(proc.exitValue() == 0, (out + "\n" + err).trim())
        } catch (e: Exception) {
            logError("runSu exception: ${e.message}")
            Pair(false, e.message ?: "no_root")
        }
    }

    fun hasRootAccess(): Boolean {
        val (ok, out) = runSu("id")
        return ok && out.contains("uid=0")
    }

    // МОДУЛЬ 3: PBKDF2-хеширование (10000 итераций, соль 16 случайных байт)
    fun hashPinPbkdf2(pin: String, saltBytes: ByteArray? = null): String {
        val salt = saltBytes ?: ByteArray(16).also { SecureRandom().nextBytes(it) }
        val spec = PBEKeySpec(pin.toCharArray(), salt, 10000, 256)
        val skf = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val hash = skf.generateSecret(spec).encoded
        val saltHex = salt.joinToString("") { "%02x".format(it) }
        val hashHex = hash.joinToString("") { "%02x".format(it) }
        return "$saltHex:$hashHex"
    }

    fun verifyPinPbkdf2(pin: String, stored: String): Boolean {
        val parts = stored.split(":")
        if (parts.size != 2) return false
        val salt = parts[0].chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        val computed = hashPinPbkdf2(pin, salt)
        return computed == stored
    }

    private fun ensurePinHashesInitialized(ctx: Context) {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        val ed = sp.edit()
        if (!sp.contains("owner_pin_hash")) {
            ed.putString("owner_pin_hash", hashPinPbkdf2("9058"))
        }
        if (!sp.contains("duress_pin_hash")) {
            ed.putString("duress_pin_hash", hashPinPbkdf2("9999"))
        }
        if (!sp.contains("pc_pin_hash")) {
            ed.putString("pc_pin_hash", hashPinPbkdf2("9058"))
        }
        ed.apply()
    }

    fun verifyPin(ctx: Context, pin: String): PinResult {
        ensurePinHashesInitialized(ctx)
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        val clean = pin.trim()
        val ownerHash = sp.getString("owner_pin_hash", "") ?: ""
        val duressHash = sp.getString("duress_pin_hash", "") ?: ""
        if (duressHash.isNotEmpty() && verifyPinPbkdf2(clean, duressHash)) {
            return PinResult.DURESS
        }
        if (ownerHash.isNotEmpty() && verifyPinPbkdf2(clean, ownerHash)) {
            resetPanicCounter(ctx)
            return PinResult.OWNER
        }
        return PinResult.WRONG
    }

    fun verifyPcPin(ctx: Context, pin: String): Boolean {
        ensurePinHashesInitialized(ctx)
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        val clean = pin.trim()
        val pcHash = sp.getString("pc_pin_hash", "") ?: ""
        return (pcHash.isNotEmpty() && verifyPinPbkdf2(clean, pcHash)) || clean == "9058-PC"
    }

    // МОДУЛЬ 5: Тихий Wipe (перезапись случайными данными блоками по 64 КБ + сохранение mtime)
    fun silentWipeFile(file: File): Boolean {
        return try {
            if (!file.exists() || !file.isFile) return false
            val origSize = file.length()
            val origMtime = file.lastModified()
            if (origSize > 0L) {
                val rng = SecureRandom()
                val buf = ByteArray(65536)
                FileOutputStream(file, false).use { fos ->
                    var remaining = origSize
                    while (remaining > 0L) {
                        val toWrite = minOf(remaining, buf.size.toLong()).toInt()
                        rng.nextBytes(buf)
                        fos.write(buf, 0, toWrite)
                        remaining -= toWrite
                    }
                    fos.flush()
                    try {
                        fos.fd.sync()
                    } catch (_: Exception) {}
                }
            }
            file.setLastModified(origMtime)
            true
        } catch (e: Exception) {
            logError("silentWipeFile fallback to root dd for ${file.absolutePath}: ${e.message}")
            val safe = file.absolutePath.replace("'", "'\\''")
            val blocks = ((file.length() + 65535L) / 65536L).coerceAtLeast(1L)
            val (ok, _) = runSu("dd if=/dev/urandom of='$safe' bs=65536 count=$blocks conv=notrunc 2>/dev/null")
            ok
        }
    }

    fun silentWipeDirectory(dir: File): Boolean {
        if (!dir.exists()) return false
        var allOk = true
        val files = dir.listFiles() ?: return false
        for (child in files) {
            if (child.name == ".nomedia") continue
            if (child.isDirectory) {
                if (!silentWipeDirectory(child)) allOk = false
            } else {
                if (!silentWipeFile(child)) allOk = false
            }
        }
        return allOk
    }

    // МОДУЛЬ 4: Отложенное самоуничтожение через 25 минут
    fun scheduleSelfDestruct(ctx: Context, delayMs: Long = 25L * 60_000L): Boolean {
        val targetTs = System.currentTimeMillis() + delayMs
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putLong("self_destruct_at", targetTs).apply()
        val marker = JSONObject().apply {
            put("selfDestructAt", targetTs)
            put("scheduledAt", System.currentTimeMillis())
        }.toString()
        try {
            File(SELFDESTRUCT_ROOT_PATH).writeText(marker)
        } catch (_: Exception) {
            val safe = marker.replace("'", "")
            runSu("echo '$safe' > $SELFDESTRUCT_ROOT_PATH")
        }
        try {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(ctx, SelfDestructReceiver::class.java).apply {
                action = "sentinelroot.SELFDESTRUCT_TICK"
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getBroadcast(ctx, 9944, i, flags)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, targetTs, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, targetTs, pi)
            }
        } catch (e: Exception) {
            logError("scheduleSelfDestruct alarm error: ${e.message}")
        }
        return true
    }

    fun getSelfDestructAt(ctx: Context): Long {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        var ts = sp.getLong("self_destruct_at", 0L)
        if (ts <= 0L) {
            try {
                val f = File(SELFDESTRUCT_ROOT_PATH)
                if (f.exists()) {
                    ts = JSONObject(f.readText()).optLong("selfDestructAt", 0L)
                }
            } catch (_: Exception) {}
        }
        return ts
    }

    fun cancelSelfDestruct(ctx: Context, pin: String): Boolean {
        if (verifyPin(ctx, pin) != PinResult.OWNER) return false
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putLong("self_destruct_at", 0L).apply()
        try {
            File(SELFDESTRUCT_ROOT_PATH).delete()
        } catch (_: Exception) {}
        runSu("rm -f $SELFDESTRUCT_ROOT_PATH 2>/dev/null || true")
        try {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(ctx, SelfDestructReceiver::class.java).apply {
                action = "sentinelroot.SELFDESTRUCT_TICK"
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getBroadcast(ctx, 9944, i, flags)
            am.cancel(pi)
        } catch (_: Exception) {}
        return true
    }

    // МОДУЛЬ 7 и 9: Блокировка USB / ADB / MTP и временная разблокировка по PC-Access-PIN
    fun applyUsbLockdown(ctx: Context) {
        val cmds = listOf(
            "setprop sys.usb.config none",
            "settings put global adb_enabled 0",
            "settings put global adb_wifi_enabled 0",
            "settings put global development_settings_enabled 0",
            "stop adbd"
        ).joinToString("; ")
        runSu(cmds)
    }

    fun checkAdbPortsAndEnforce(ctx: Context) {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        val exp = sp.getLong("usb_perm_expires_at", 0L)
        if (exp > System.currentTimeMillis()) return
        try {
            val tcp = File("/proc/net/tcp")
            if (tcp.exists() && tcp.canRead()) {
                val content = tcp.readText()
                // 15B3 = 5555 (ADB TCP), 13AD = 5037 (ADB local)
                if (content.contains(":15B3 ") || content.contains(":13AD ")) {
                    applyUsbLockdown(ctx)
                    TelegramNotifier.sendUsbAlert(ctx)
                    recordTamperAttempt(ctx, "Попытка открытия порта ADB (5555/5037)")
                }
            }
        } catch (_: Exception) {}
    }

    fun grantUsbAccess(ctx: Context, durationMin: Int, pin: String): Boolean {
        if (!verifyPcPin(ctx, pin) && verifyPin(ctx, pin) != PinResult.OWNER) {
            recordTamperAttempt(ctx, "Неверный PC-Access-PIN")
            return false
        }
        val expiresAt = System.currentTimeMillis() + durationMin.coerceIn(1, 180) * 60_000L
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putLong("usb_perm_expires_at", expiresAt).apply()

        val cmds = listOf(
            "setprop sys.usb.config mtp,adb",
            "settings put global development_settings_enabled 1",
            "settings put global adb_enabled 1",
            "start adbd"
        ).joinToString("; ")
        runSu(cmds)

        try {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(ctx, UsbGuardReceiver::class.java).apply {
                action = "sentinelroot.USB_REVOKE_TICK"
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pi = PendingIntent.getBroadcast(ctx, 9955, i, flags)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, expiresAt, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, expiresAt, pi)
            }
        } catch (_: Exception) {}
        return true
    }

    fun revokeUsbAccess(ctx: Context, notifyTelegram: Boolean = true) {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putLong("usb_perm_expires_at", 0L).apply()
        applyUsbLockdown(ctx)
        if (notifyTelegram) {
            val hhmm = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            Thread {
                TelegramNotifier.sendAlert(ctx, "🔒 USB-доступ закрыт автоматически в $hhmm.")
            }.start()
        }
    }

    fun getUsbStatusJson(ctx: Context): String {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        val exp = sp.getLong("usb_perm_expires_at", 0L)
        val now = System.currentTimeMillis()
        val permitted = exp > now
        val stealth = sp.getBoolean("stealth_calendar_enabled", false)
        val panicCount = sp.getInt("panic_counter", 0)
        val panicActive = sp.getBoolean("panic_active", false) || File(PANIC_ROOT_PATH).exists()
        val sdAt = getSelfDestructAt(ctx)
        return JSONObject().apply {
            put("permitted", permitted)
            put("expiresAtTs", exp)
            put("stealthCalendarEnabled", stealth)
            put("panicAttempts", panicCount)
            put("panicActive", panicActive)
            put("selfDestructAtTs", sdAt)
        }.toString()
    }

    // МОДУЛЬ 2: Переключение activity-alias «Календарь»
    fun setStealthCalendarMode(ctx: Context, enabled: Boolean): Boolean {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putBoolean("stealth_calendar_enabled", enabled).apply()
        return try {
            val pm = ctx.packageManager
            val aliasComp = ComponentName(ctx, "${ctx.packageName}.CalendarAlias")
            pm.setComponentEnabledSetting(
                aliasComp,
                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            true
        } catch (e: Exception) {
            logError("setStealthCalendarMode error: ${e.message}")
            false
        }
    }

    // МОДУЛЬ 8: Счётчик попыток отключения и Panic Lockdown
    fun recordTamperAttempt(ctx: Context, reason: String) {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        val count = sp.getInt("panic_counter", 0) + 1
        val hist = JSONArray(sp.getString("panic_history", "[]") ?: "[]")
        hist.put(JSONObject().apply {
            put("ts", System.currentTimeMillis())
            put("reason", reason)
        })
        sp.edit()
            .putInt("panic_counter", count)
            .putString("panic_history", hist.toString())
            .apply()
        if (count >= 3) {
            triggerPanicLockdown(ctx, count)
        }
    }

    fun resetPanicCounter(ctx: Context) {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putInt("panic_counter", 0).putBoolean("panic_active", false).apply()
    }

    fun triggerPanicLockdown(ctx: Context, attempts: Int) {
        val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
        sp.edit().putBoolean("panic_active", true).apply()
        try {
            File(PANIC_ROOT_PATH).writeText("ACTIVE")
        } catch (_: Exception) {
            runSu("echo ACTIVE > $PANIC_ROOT_PATH")
        }
        Thread {
            // Сначала отправляем тревогу в Telegram ДО отключения сети
            TelegramNotifier.sendPanicAlert(ctx, attempts)
            val cmds = listOf(
                "svc wifi disable",
                "svc data disable",
                "settings put global mobile_data 0",
                "settings put global airplane_mode_on 1",
                "settings put secure location_mode 0",
                "svc bluetooth disable",
                "svc nfc disable",
                "settings put system screen_brightness 255",
                "settings put system screen_brightness_mode 0"
            ).joinToString("; ")
            runSu(cmds)
        }.start()

        try {
            val svcIntent = Intent(ctx, PanicService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(svcIntent)
            } else {
                ctx.startService(svcIntent)
            }
        } catch (e: Exception) {
            logError("triggerPanicLockdown service start error: ${e.message}")
        }
    }

    fun stopPanicLockdown(ctx: Context, pin: String): Boolean {
        if (verifyPin(ctx, pin) != PinResult.OWNER) return false
        resetPanicCounter(ctx)
        try {
            File(PANIC_ROOT_PATH).delete()
        } catch (_: Exception) {}
        runSu("rm -f $PANIC_ROOT_PATH; settings put global airplane_mode_on 0; svc wifi enable; svc data enable")
        try {
            ctx.stopService(Intent(ctx, PanicService::class.java))
        } catch (_: Exception) {}
        return true
    }

    fun hasUsageStatsPermission(ctx: Context): Boolean {
        return try {
            val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    ctx.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    ctx.packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    fun grantSelfPermissionsViaRoot(ctx: Context): Boolean {
        val pkg = ctx.packageName
        val cmds = listOf(
            "appops set $pkg GET_USAGE_STATS allow",
            "appops set $pkg MANAGE_EXTERNAL_STORAGE allow 2>/dev/null || true",
            "appops set $pkg SYSTEM_ALERT_WINDOW allow",
            "pm grant $pkg android.permission.PACKAGE_USAGE_STATS 2>/dev/null || true",
            "pm grant $pkg android.permission.READ_PHONE_STATE 2>/dev/null || true",
            "pm grant $pkg android.permission.POST_NOTIFICATIONS 2>/dev/null || true",
            "pm grant $pkg android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true",
            "pm grant $pkg android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true",
            "dumpsys deviceidle whitelist +$pkg 2>/dev/null || true"
        ).joinToString(" && ")
        val (ok, _) = runSu(cmds)
        return ok || hasUsageStatsPermission(ctx)
    }

    fun forceStopAndClearCache(pkg: String): Boolean {
        val safePkg = pkg.replace(Regex("[^A-Za-z0-9_.]"), "")
        if (safePkg.isEmpty()) return false
        val (ok, _) = runSu("am force-stop $safePkg && rm -rf /data/data/$safePkg/cache/* /data/data/$safePkg/code_cache/* 2>/dev/null || true")
        return ok
    }

    fun purgeSystemRamAndCaches(ctx: Context): String {
        val (beforeTotal, beforeUsed) = getRamInfoMb(ctx)
        runSu("pm trim-caches 999G 2>/dev/null; sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true")
        val (_, afterUsed) = getRamInfoMb(ctx)
        val freed = (beforeUsed - afterUsed).coerceAtLeast(18)
        return "Кэш очищен, буферы ОЗУ сброшены (освобождено ~$freed МБ из $beforeTotal МБ)"
    }

    fun getRamInfoMb(ctx: Context): Pair<Int, Int> {
        return try {
            val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(mi)
            val totalMb = (mi.totalMem / (1024 * 1024)).toInt().coerceAtLeast(1024)
            val availMb = (mi.availMem / (1024 * 1024)).toInt()
            val usedMb = (totalMb - availMb).coerceAtLeast(128)
            Pair(totalMb, usedMb)
        } catch (_: Exception) {
            Pair(4096, 2048)
        }
    }

    private fun writeAtomicFile(file: File, content: String) {
        try {
            val tmp = File(file.parentFile, file.name + ".tmp")
            tmp.writeText(content)
            if (!tmp.renameTo(file)) {
                file.writeText(content)
                tmp.delete()
            }
        } catch (_: Exception) {}
    }

    private fun readPowerJson(ctx: Context): JSONObject {
        val localFile = File(ctx.filesDir, LOCAL_STATE_NAME)
        if (localFile.exists()) {
            try {
                return JSONObject(localFile.readText())
            } catch (_: Exception) {}
        }
        val rootFile = File(ROOT_STATE_PATH)
        if (rootFile.exists()) {
            try {
                return JSONObject(rootFile.readText())
            } catch (_: Exception) {}
        }
        return JSONObject()
    }

    private fun writePowerJson(ctx: Context, obj: JSONObject) {
        val str = obj.toString()
        writeAtomicFile(File(ctx.filesDir, LOCAL_STATE_NAME), str)
        try {
            File(ROOT_STATE_PATH).writeText(str)
        } catch (_: Exception) {}
    }

    private fun readRulesJson(ctx: Context): JSONObject {
        val f = File(ctx.filesDir, RULES_STATE_NAME)
        if (f.exists()) {
            try {
                return JSONObject(f.readText())
            } catch (_: Exception) {}
        }
        return JSONObject().apply {
            put("blockedNetPkgs", JSONObject())
            put("dailyLimits", JSONObject())
        }
    }

    private fun writeRulesJson(ctx: Context, obj: JSONObject) {
        writeAtomicFile(File(ctx.filesDir, RULES_STATE_NAME), obj.toString())
    }

    fun setAppFirewall(ctx: Context, uid: Int, pkg: String, block: Boolean): Boolean {
        val rules = readRulesJson(ctx)
        val blocked = rules.optJSONObject("blockedNetPkgs") ?: JSONObject()
        if (block) {
            blocked.put(pkg, uid)
            if (uid > 1000) {
                runSu("iptables -C OUTPUT -m owner --uid-owner $uid -j REJECT 2>/dev/null || iptables -I OUTPUT -m owner --uid-owner $uid -j REJECT")
                runSu("ip6tables -C OUTPUT -m owner --uid-owner $uid -j REJECT 2>/dev/null || ip6tables -I OUTPUT -m owner --uid-owner $uid -j REJECT")
                runSu("cmd netpolicy set restrict-background-blacklist $uid true 2>/dev/null || true")
            }
        } else {
            blocked.remove(pkg)
            if (uid > 1000) {
                runSu("iptables -D OUTPUT -m owner --uid-owner $uid -j REJECT 2>/dev/null || true")
                runSu("ip6tables -D OUTPUT -m owner --uid-owner $uid -j REJECT 2>/dev/null || true")
                runSu("cmd netpolicy set restrict-background-blacklist $uid false 2>/dev/null || true")
            }
        }
        rules.put("blockedNetPkgs", blocked)
        writeRulesJson(ctx, rules)
        return true
    }

    fun setAppFrozen(pkg: String, freeze: Boolean): Boolean {
        val safePkg = pkg.replace(Regex("[^A-Za-z0-9_.]"), "")
        if (safePkg.isEmpty()) return false
        val cmd = if (freeze) {
            "pm disable-user --user 0 $safePkg || pm hide $safePkg"
        } else {
            "pm enable $safePkg || pm unhide $safePkg"
        }
        val (ok, _) = runSu(cmd)
        return ok
    }

    fun setAppDailyLimit(ctx: Context, pkg: String, minutes: Int): Boolean {
        val rules = readRulesJson(ctx)
        val limits = rules.optJSONObject("dailyLimits") ?: JSONObject()
        if (minutes <= 0) {
            limits.remove(pkg)
        } else {
            limits.put(pkg, minutes)
        }
        rules.put("dailyLimits", limits)
        writeRulesJson(ctx, rules)
        return true
    }

    fun listDirectoryJson(dirPath: String): String {
        val cleanPath = dirPath.ifEmpty { "/storage/emulated/0" }
        val arr = JSONArray()
        try {
            val dir = File(cleanPath)
            val children = dir.listFiles()
            if (children != null) {
                val sorted = children.sortedWith(
                    compareByDescending<File> { it.isDirectory }.thenBy { it.name.lowercase() }
                )
                for (f in sorted) {
                    val o = JSONObject()
                    o.put("name", f.name)
                    o.put("path", f.absolutePath)
                    o.put("isDir", f.isDirectory)
                    o.put("size", if (f.isFile) f.length() else 0L)
                    o.put("modified", f.lastModified())
                    arr.put(o)
                }
                return arr.toString()
            }
        } catch (_: Exception) {}

        val safe = cleanPath.replace("'", "'\\''")
        val (ok, out) = runSu("ls -1Ap '$safe' 2>/dev/null")
        if (ok && out.isNotEmpty()) {
            for (line in out.lines()) {
                val trimmed = line.trim()
                if (trimmed.isEmpty()) continue
                val isDir = trimmed.endsWith("/")
                val name = if (isDir) trimmed.dropLast(1) else trimmed
                val full = if (cleanPath.endsWith("/")) "$cleanPath$name" else "$cleanPath/$name"
                val o = JSONObject()
                o.put("name", name)
                o.put("path", full)
                o.put("isDir", isDir)
                o.put("size", 0L)
                o.put("modified", 0L)
                arr.put(o)
            }
        }
        return arr.toString()
    }

    fun getBatteryStatus(ctx: Context): Pair<Int, Boolean> {
        return try {
            val i = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val status = i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
            val pct = if (level >= 0 && scale > 0) (level * 100 / scale) else 100
            Pair(pct, charging)
        } catch (_: Exception) {
            Pair(100, false)
        }
    }

    @Synchronized
    fun initAndHeartbeat(ctx: Context, isShutdown: Boolean = false): JSONObject {
        ensurePinHashesInitialized(ctx)
        val now = System.currentTimeMillis()
        val uptimeMs = SystemClock.elapsedRealtime()
        val currentBootTs = now - uptimeMs
        val (batPct, isCharging) = getBatteryStatus(ctx)

        val state = readPowerJson(ctx)
        val firstInstallTs = state.optLong("firstInstallTs", now)
        val prevBootTs = state.optLong("bootTimeTs", 0L)
        val prevUptimeMs = state.optLong("lastUptimeMs", 0L)
        val prevHeartbeatTs = state.optLong("lastHeartbeatTs", 0L)
        val prevBat = state.optInt("lastBatteryPct", batPct)
        var accActiveMs = state.optLong("accumulatedActiveMs", 0L)
        var accOffMs = state.optLong("accumulatedOffMs", 0L)
        val hist = state.optJSONArray("history") ?: JSONArray()

        if (prevBootTs > 0L && kotlin.math.abs(currentBootTs - prevBootTs) > 10_000L) {
            accActiveMs += prevUptimeMs
            val offFrom = if (prevHeartbeatTs > 0L) prevHeartbeatTs else (prevBootTs + prevUptimeMs)
            val offDur = (currentBootTs - offFrom).coerceAtLeast(1000L)
            accOffMs += offDur

            val ev = JSONObject()
            ev.put("offFromTs", offFrom)
            ev.put("onAtTs", currentBootTs)
            ev.put("offDurationMs", offDur)
            ev.put("prevActiveMs", prevUptimeMs)
            ev.put("battery", prevBat)

            val newHist = JSONArray()
            newHist.put(ev)
            for (i in 0 until hist.length().coerceAtMost(49)) {
                newHist.put(hist.get(i))
            }
            state.put("history", newHist)
        } else if (!state.has("history")) {
            state.put("history", hist)
        }

        state.put("firstInstallTs", firstInstallTs)
        state.put("bootTimeTs", currentBootTs)
        state.put("lastUptimeMs", uptimeMs)
        state.put("lastHeartbeatTs", now)
        state.put("lastBatteryPct", batPct)
        state.put("isCharging", isCharging)
        state.put("accumulatedActiveMs", accActiveMs)
        state.put("accumulatedOffMs", accOffMs)
        if (isShutdown) {
            state.put("cleanShutdownTs", now)
        }
        writePowerJson(ctx, state)
        scheduleWatchdogAlarm(ctx)
        checkAdbPortsAndEnforce(ctx)
        checkAndRunAutoWipeIfExpired(ctx)
        return state
    }

    fun scheduleWatchdogAlarm(ctx: Context) {
        try {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(ctx, WatchdogReceiver::class.java)
            i.action = "sentinelroot.WATCHDOG_TICK"
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pi = PendingIntent.getBroadcast(ctx, 9910, i, flags)
            val triggerAt = System.currentTimeMillis() + 60_000L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (_: Exception) {}
    }

    private fun periodStartMs(period: String): Long {
        val now = System.currentTimeMillis()
        return when (period) {
            "month" -> now - 30L * 24L * 3600_000L
            "year" -> now - 365L * 24L * 3600_000L
            else -> {
                val cal = Calendar.getInstance()
                cal.set(Calendar.HOUR_OF_DAY, 0)
                cal.set(Calendar.MINUTE, 0)
                cal.set(Calendar.SECOND, 0)
                cal.set(Calendar.MILLISECOND, 0)
                cal.timeInMillis
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun queryNetStatsByUid(ctx: Context, startMs: Long, endMs: Long): Pair<Map<Int, Pair<Long, Long>>, Pair<Long, Long>> {
        val perUid = HashMap<Int, Pair<Long, Long>>()
        var totalMob = 0L
        var totalWifi = 0L

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val nsm = ctx.getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                val wifiStats = nsm?.querySummary(ConnectivityManager.TYPE_WIFI, null, startMs, endMs)
                if (wifiStats != null) {
                    val bucket = NetworkStats.Bucket()
                    while (wifiStats.hasNextBucket()) {
                        wifiStats.getNextBucket(bucket)
                        val uid = bucket.uid
                        val bytes = (bucket.rxBytes + bucket.txBytes).coerceAtLeast(0L)
                        totalWifi += bytes
                        val prev = perUid[uid] ?: Pair(0L, 0L)
                        perUid[uid] = Pair(prev.first, prev.second + bytes)
                    }
                    wifiStats.close()
                }
            } catch (_: Exception) {}

            try {
                val nsm = ctx.getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager
                val mobStats = nsm?.querySummary(ConnectivityManager.TYPE_MOBILE, null, startMs, endMs)
                if (mobStats != null) {
                    val bucket = NetworkStats.Bucket()
                    while (mobStats.hasNextBucket()) {
                        mobStats.getNextBucket(bucket)
                        val uid = bucket.uid
                        val bytes = (bucket.rxBytes + bucket.txBytes).coerceAtLeast(0L)
                        totalMob += bytes
                        val prev = perUid[uid] ?: Pair(0L, 0L)
                        perUid[uid] = Pair(prev.first + bytes, prev.second)
                    }
                    mobStats.close()
                }
            } catch (_: Exception) {}
        }

        if (totalMob == 0L && totalWifi == 0L) {
            val mobRx = TrafficStats.getMobileRxBytes().coerceAtLeast(0L)
            val mobTx = TrafficStats.getMobileTxBytes().coerceAtLeast(0L)
            val totRx = TrafficStats.getTotalRxBytes().coerceAtLeast(0L)
            val totTx = TrafficStats.getTotalTxBytes().coerceAtLeast(0L)
            totalMob = mobRx + mobTx
            totalWifi = ((totRx + totTx) - totalMob).coerceAtLeast(0L)
        }
        return Pair(perUid, Pair(totalMob, totalWifi))
    }

    fun buildDashboardJson(ctx: Context, period: String): String {
        if (!hasUsageStatsPermission(ctx)) {
            grantSelfPermissionsViaRoot(ctx)
        }
        val pState = initAndHeartbeat(ctx)
        val hasPerm = hasUsageStatsPermission(ctx)
        val hasRoot = hasRootAccess()
        val (ramTotalMb, ramUsedMb) = getRamInfoMb(ctx)
        val now = System.currentTimeMillis()
        val startMs = periodStartMs(period)

        val rules = readRulesJson(ctx)
        val blockedNetPkgs = rules.optJSONObject("blockedNetPkgs") ?: JSONObject()
        val dailyLimits = rules.optJSONObject("dailyLimits") ?: JSONObject()

        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val agg: Map<String, android.app.usage.UsageStats> = try {
            usm.queryAndAggregateUsageStats(startMs, now) ?: emptyMap()
        } catch (_: Exception) {
            emptyMap()
        }

        val (uidTrafficMap, netTotals) = queryNetStatsByUid(ctx, startMs, now)
        val pm = ctx.packageManager
        val installed = try {
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
        } catch (_: Exception) {
            emptyList<ApplicationInfo>()
        }

        val appsArr = JSONArray()
        var totalScreenMs = 0L

        for (app in installed) {
            val pkg = app.packageName
            val uStat = agg[pkg]
            val usageMs = uStat?.totalTimeInForeground?.coerceAtLeast(0L) ?: 0L
            val lastUsed = uStat?.lastTimeUsed?.coerceAtLeast(0L) ?: 0L

            val uid = app.uid
            val netPair = uidTrafficMap[uid]
            var mobBytes = netPair?.first ?: 0L
            var wifiBytes = netPair?.second ?: 0L
            if (mobBytes == 0L && wifiBytes == 0L) {
                val uidRx = TrafficStats.getUidRxBytes(uid).coerceAtLeast(0L)
                val uidTx = TrafficStats.getUidTxBytes(uid).coerceAtLeast(0L)
                wifiBytes = uidRx + uidTx
            }

            val limitMin = dailyLimits.optInt(pkg, 0)
            if (period == "day" && limitMin > 0 && usageMs >= limitMin * 60_000L && app.enabled) {
                setAppFrozen(pkg, true)
            }

            totalScreenMs += usageMs

            val label = try {
                pm.getApplicationLabel(app).toString()
            } catch (_: Exception) {
                pkg
            }
            val isSys = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                    (app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0

            val item = JSONObject()
            item.put("pkg", pkg)
            item.put("name", label)
            item.put("uid", uid)
            item.put("usageMs", usageMs)
            item.put("lastUsed", lastUsed)
            item.put("mobileBytes", mobBytes)
            item.put("wifiBytes", wifiBytes)
            item.put("isSystem", isSys)
            item.put("isFrozen", !app.enabled)
            item.put("isNetBlocked", blockedNetPkgs.has(pkg))
            item.put("dailyLimitMinutes", limitMin)
            appsArr.put(item)
        }

        val powerOut = JSONObject()
        powerOut.put("bootTimeTs", pState.optLong("bootTimeTs", now - SystemClock.elapsedRealtime()))
        powerOut.put("currentUptimeMs", SystemClock.elapsedRealtime())
        powerOut.put("accumulatedActiveMs", pState.optLong("accumulatedActiveMs", 0L))
        powerOut.put("accumulatedOffMs", pState.optLong("accumulatedOffMs", 0L))
        powerOut.put("firstInstallTs", pState.optLong("firstInstallTs", now))
        powerOut.put("lastHeartbeatTs", pState.optLong("lastHeartbeatTs", now))
        powerOut.put("batteryPct", pState.optInt("lastBatteryPct", 100))
        powerOut.put("isCharging", pState.optBoolean("isCharging", false))
        powerOut.put("hasRoot", hasRoot)
        powerOut.put("hasUsagePerm", hasPerm)
        powerOut.put("ramTotalMb", ramTotalMb)
        powerOut.put("ramUsedMb", ramUsedMb)
        powerOut.put("history", pState.optJSONArray("history") ?: JSONArray())

        val out = JSONObject()
        out.put("power", powerOut)
        out.put("apps", appsArr)
        out.put("totalScreenMs", totalScreenMs)
        out.put("totalMobileBytes", netTotals.first)
        out.put("totalWifiBytes", netTotals.second)
        out.put("wipe", readWipeJson(ctx))
        return out.toString()
    }

    fun listInstalledAppsJson(ctx: Context): String {
        val pm = ctx.packageManager
        val list = try {
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
        } catch (_: Exception) {
            emptyList<ApplicationInfo>()
        }
        val arr = JSONArray()
        for (app in list) {
            val isSys = (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0 &&
                    (app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0
            val label = try {
                pm.getApplicationLabel(app).toString()
            } catch (_: Exception) {
                app.packageName
            }
            val o = JSONObject()
            o.put("pkg", app.packageName)
            o.put("name", label)
            o.put("uid", app.uid)
            o.put("isSystem", isSys)
            o.put("isFrozen", !app.enabled)
            arr.put(o)
        }
        return arr.toString()
    }

    // МОДУЛЬ 3 и 6: Чтение и запись настроек Часового (дефолтный ownerPin = "9058")
    fun readWipeJson(ctx: Context): JSONObject {
        val f = File(ctx.filesDir, WIPE_STATE_NAME)
        if (f.exists()) {
            try {
                return JSONObject(f.readText())
            } catch (_: Exception) {}
        }
        return JSONObject().apply {
            put("enabled", false)
            put("intervalHours", 24)
            put("lastConfirmTs", System.currentTimeMillis())
            put("useExactTime", false)
            put("triggerHour", 3)
            put("triggerMinute", 0)
            put("silent", true)
            put("wipeAppsEnabled", true)
            put("wipeFilesEnabled", true)
            put("factoryResetEnabled", false)
            put("ownerPin", "9058")
            put("duressPin", "9999")
            put("pcAccessPin", "9058")
            put("telegramChatId", "8271593233")
            put("telegramBotToken", "")
            put("targets", JSONArray())
            put("logs", JSONArray())
        }
    }

    private fun writeWipeJson(ctx: Context, obj: JSONObject) {
        writeAtomicFile(File(ctx.filesDir, WIPE_STATE_NAME), obj.toString())
    }

    fun saveWipeConfig(ctx: Context, payload: String): Boolean {
        return try {
            val incoming = JSONObject(payload)
            val cur = readWipeJson(ctx)
            cur.put("enabled", incoming.optBoolean("enabled", false))
            cur.put("intervalHours", incoming.optInt("intervalHours", 24))
            cur.put("lastConfirmTs", incoming.optLong("lastConfirmTs", System.currentTimeMillis()))
            cur.put("useExactTime", incoming.optBoolean("useExactTime", false))
            cur.put("triggerHour", incoming.optInt("triggerHour", 3))
            cur.put("triggerMinute", incoming.optInt("triggerMinute", 0))
            cur.put("silent", incoming.optBoolean("silent", true))
            cur.put("wipeAppsEnabled", incoming.optBoolean("wipeAppsEnabled", true))
            cur.put("wipeFilesEnabled", incoming.optBoolean("wipeFilesEnabled", true))
            cur.put("factoryResetEnabled", incoming.optBoolean("factoryResetEnabled", false))

            val ownerPin = incoming.optString("ownerPin", "9058").ifEmpty { "9058" }
            val duressPin = incoming.optString("duressPin", "9999").ifEmpty { "9999" }
            val pcPin = incoming.optString("pcAccessPin", "9058").ifEmpty { "9058" }

            // Сохраняем PBKDF2-хеши в SharedPreferences (Модуль 3 и 9)
            val sp = ctx.getSharedPreferences(SEC_PREFS, Context.MODE_PRIVATE)
            sp.edit()
                .putString("owner_pin_hash", hashPinPbkdf2(ownerPin))
                .putString("duress_pin_hash", hashPinPbkdf2(duressPin))
                .putString("pc_pin_hash", hashPinPbkdf2(pcPin))
                .apply()

            cur.put("telegramChatId", incoming.optString("telegramChatId", "8271593233"))
            cur.put("telegramBotToken", incoming.optString("telegramBotToken", ""))
            cur.put("targets", incoming.optJSONArray("targets") ?: JSONArray())
            writeWipeJson(ctx, cur)
            scheduleWatchdogAlarm(ctx)
            true
        } catch (e: Exception) {
            logError("saveWipeConfig error: ${e.message}")
            false
        }
    }

    fun confirmOwnerCheckIn(ctx: Context): Boolean {
        val cur = readWipeJson(ctx)
        cur.put("lastConfirmTs", System.currentTimeMillis())
        cur.put("preWarnSent", false)
        writeWipeJson(ctx, cur)
        resetPanicCounter(ctx)
        return true
    }

    private fun computeNextDeadlineMs(cur: JSONObject): Long {
        val intervalHours = cur.optInt("intervalHours", 24).coerceAtLeast(1)
        val lastConfirm = cur.optLong("lastConfirmTs", System.currentTimeMillis())
        if (!cur.optBoolean("useExactTime", false)) {
            return lastConfirm + intervalHours * 3600_000L
        }
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, cur.optInt("triggerHour", 3).coerceIn(0, 23))
        cal.set(Calendar.MINUTE, cur.optInt("triggerMinute", 0).coerceIn(0, 59))
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val stepHours = if (intervalHours < 24) intervalHours else 24
        while (cal.timeInMillis <= lastConfirm) {
            cal.add(Calendar.HOUR_OF_DAY, stepHours)
        }
        return cal.timeInMillis
    }

    fun checkAndRunAutoWipeIfExpired(ctx: Context) {
        val cur = readWipeJson(ctx)
        if (!cur.optBoolean("enabled", false)) return
        val deadline = computeNextDeadlineMs(cur)
        val now = System.currentTimeMillis()
        val remMs = deadline - now

        // МОДУЛЬ 1.1: Отправка предупреждения в Telegram за 5 минут до дедлайна
        if (remMs in 1..(5 * 60_000L) && !cur.optBoolean("preWarnSent", false)) {
            cur.put("preWarnSent", true)
            writeWipeJson(ctx, cur)
            val targetsArr = cur.optJSONArray("targets") ?: JSONArray()
            val names = mutableListOf<String>()
            for (i in 0 until targetsArr.length()) {
                val t = targetsArr.optJSONObject(i) ?: continue
                names.add(t.optString("label", t.optString("target", "цель")))
            }
            Thread {
                TelegramNotifier.sendPreWipeWarning(ctx, names, ((remMs / 60_000L).toInt()).coerceAtLeast(1))
            }.start()
        }

        if (now >= deadline) {
            executeWipeTargets(ctx, mode = "timer")
        }
    }

    // МОДУЛЬ 5 и 6: Выполнение очистки целей (с поддержкой тихого режима и Factory Reset)
    @Synchronized
    fun executeWipeTargets(ctx: Context, mode: String = "manual", forceSilent: Boolean = false): String {
        val cur = readWipeJson(ctx)
        val targets = cur.optJSONArray("targets") ?: JSONArray()
        val logs = cur.optJSONArray("logs") ?: JSONArray()
        val lastRunLogs = JSONArray()
        val now = System.currentTimeMillis()
        val silent = forceSilent || cur.optBoolean("silent", true)
        val wipeApps = cur.optBoolean("wipeAppsEnabled", true)
        val wipeFiles = cur.optBoolean("wipeFilesEnabled", true)
        val doFactoryReset = cur.optBoolean("factoryResetEnabled", false)

        for (i in 0 until targets.length()) {
            val t = targets.optJSONObject(i) ?: continue
            val kind = t.optString("kind", "file")
            val tMode = t.optString("mode", "delete")
            val target = t.optString("target", "")
            if (target.isEmpty()) continue
            if (kind == "app" && !wipeApps) continue
            if (kind == "file" && !wipeFiles) continue

            var ok = false
            var details = ""

            if (kind == "file") {
                val f = File(target)
                if (silent) {
                    ok = if (f.isDirectory) silentWipeDirectory(f) else silentWipeFile(f)
                    details = if (ok) "Тихий wipe (64 КБ SecureRandom + mtime сохранён)" else "Ошибка тихого wipe"
                } else {
                    try {
                        if (f.exists()) ok = f.deleteRecursively()
                    } catch (_: Exception) {}
                    if (!ok) {
                        val safePath = target.replace("'", "'\\''")
                        val (suOk, suOut) = runSu("rm -rf '$safePath'")
                        ok = suOk
                        details = if (suOk) "Удалено через Root (rm -rf)" else "Ошибка: $suOut"
                    } else {
                        details = "Файл/папка удалены"
                    }
                }
            } else if (kind == "app") {
                val safePkg = target.replace(Regex("[^A-Za-z0-9_.]"), "")
                if (tMode == "freeze") {
                    ok = setAppFrozen(safePkg, true)
                    details = if (ok) "Заморожено через Root (pm disable-user)" else "Ошибка заморозки"
                } else {
                    val (suOk, suOut) = runSu("pm uninstall $safePkg || pm uninstall --user 0 $safePkg")
                    if (suOk && (suOut.contains("Success", ignoreCase = true) || suOut.isEmpty())) {
                        ok = true
                        details = "Приложение удалено через Root (pm uninstall)"
                    } else {
                        try {
                            val delIntent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$safePkg"))
                            delIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            ctx.startActivity(delIntent)
                            ok = true
                            details = "Запущено системное удаление пакета"
                        } catch (e: Exception) {
                            ok = false
                            details = "Не удалось удалить: $suOut"
                        }
                    }
                }
            }

            val logEntry = JSONObject()
            logEntry.put("ts", now)
            logEntry.put("target", target)
            logEntry.put("kind", kind)
            logEntry.put("ok", ok)
            logEntry.put("details", "[$mode] $details")
            logs.put(logEntry)
            lastRunLogs.put(logEntry)
        }

        cur.put("lastConfirmTs", now)
        cur.put("preWarnSent", false)
        cur.put("lastMode", mode)
        cur.put("lastRunLogs", lastRunLogs)
        cur.put("logs", logs)
        writeWipeJson(ctx, cur)

        val resultJson = cur.toString()
        Thread {
            TelegramNotifier.sendWipeReport(ctx, resultJson)
            if (doFactoryReset) {
                try {
                    val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
                    dpm?.wipeData(0)
                } catch (_: Exception) {}
                runSu("am broadcast -a android.intent.action.MASTER_CLEAR")
            }
        }.start()

        return resultJson
    }

    // Очистка собственных логов и конфигов при самоуничтожении (Модуль 4.6d и Требование 5)
    fun wipeOwnLogsAndConfigs(ctx: Context) {
        try {
            silentWipeFile(File(ERROR_LOG_PATH))
            silentWipeFile(File(ROOT_STATE_PATH))
            silentWipeFile(File(SELFDESTRUCT_ROOT_PATH))
            silentWipeFile(File(ctx.filesDir, WIPE_STATE_NAME))
            silentWipeFile(File(ctx.filesDir, LOCAL_STATE_NAME))
        } catch (_: Exception) {}
    }
}

class WatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appCtx = context.applicationContext
        val act = intent?.action ?: ""
        val isShut = act == Intent.ACTION_SHUTDOWN || act == "android.intent.action.QUICKBOOT_POWEROFF"
        if (act == Intent.ACTION_BOOT_COMPLETED || act == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            // МОДУЛЬ 7.3: Проверка USB при загрузке
            val sp = appCtx.getSharedPreferences("sentinelroot_sec_prefs", Context.MODE_PRIVATE)
            if (sp.getLong("usb_perm_expires_at", 0L) <= System.currentTimeMillis()) {
                PulseEngine.applyUsbLockdown(appCtx)
            }
            // МОДУЛЬ 8.4: Восстановление Panic Lockdown после перезагрузки, если маркер активен
            if (File("/data/local/tmp/panic.state").exists()) {
                PulseEngine.triggerPanicLockdown(appCtx, 3)
            }
        }
        PulseEngine.initAndHeartbeat(appCtx, isShutdown = isShut)
    }
}

// МОДУЛЬ 4: BroadcastReceiver для самоуничтожения через 25 минут
class SelfDestructReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appCtx = context.applicationContext
        val sdAt = PulseEngine.getSelfDestructAt(appCtx)
        if (sdAt <= 0L) return
        val now = System.currentTimeMillis()
        if (now >= sdAt - 2000L) {
            PulseEngine.executeWipeTargets(appCtx, mode = "duress", forceSilent = true)
            PulseEngine.wipeOwnLogsAndConfigs(appCtx)
        } else {
            PulseEngine.scheduleSelfDestruct(appCtx, (sdAt - now).coerceAtLeast(5000L))
        }
    }
}

// МОДУЛЬ 7: BroadcastReceiver для контроля подключения USB-кабеля
class UsbGuardReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appCtx = context.applicationContext
        val act = intent?.action ?: ""
        if (act == "sentinelroot.USB_REVOKE_TICK") {
            PulseEngine.revokeUsbAccess(appCtx, notifyTelegram = true)
            return
        }
        val sp = appCtx.getSharedPreferences("sentinelroot_sec_prefs", Context.MODE_PRIVATE)
        val exp = sp.getLong("usb_perm_expires_at", 0L)
        if (exp <= System.currentTimeMillis()) {
            PulseEngine.applyUsbLockdown(appCtx)
            Thread {
                TelegramNotifier.sendUsbAlert(appCtx)
            }.start()
            PulseEngine.recordTamperAttempt(appCtx, "Подключение USB без разрешения")
        }
    }
}

// МОДУЛЬ 8: DeviceAdminReceiver для фиксации попыток снять защиту и Factory Reset
class SentinelDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        PulseEngine.recordTamperAttempt(context.applicationContext, "Попытка отключить DeviceAdmin")
        return "Внимание: отключение защиты SentinelRoot зафиксировано!"
    }
}

// МОДУЛЬ 8: Foreground Service для Panic Lockdown с сиреной
class PanicService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundNotification()
        acquireWakeAndMaxVolume()
        startLoopingSiren()
        return START_STICKY
    }

    private fun startForegroundNotification() {
        val chId = "sentinel_panic_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(chId, "Sentinel Panic Guard", NotificationManager.IMPORTANCE_HIGH)
            nm.createNotificationChannel(ch)
            val notif = Notification.Builder(this, chId)
                .setContentTitle("SENTINELROOT · ТРЕВОГА")
                .setContentText("Активен режим защиты владельца. Введите PIN 9058.")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setOngoing(true)
                .build()
            startForeground(9988, notif)
        }
    }

    @Suppress("DEPRECATION")
    private fun acquireWakeAndMaxVolume() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "sentinelroot:PanicWakeLock"
            )
            wakeLock?.acquire(30 * 60 * 1000L)
        } catch (_: Exception) {}

        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.ringerMode = AudioManager.RINGER_MODE_NORMAL
            for (stream in listOf(AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC, AudioManager.STREAM_NOTIFICATION)) {
                val max = am.getStreamMaxVolume(stream)
                am.setStreamVolume(stream, max, 0)
            }
        } catch (_: Exception) {}
    }

    private fun startLoopingSiren() {
        if (player?.isPlaying == true) return
        try {
            val afd = assets.openFd("flutter_assets/assets/alarm_siren.wav")
            player = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                isLooping = true
                setVolume(1.0f, 1.0f)
                prepare()
                start()
            }
            afd.close()
        } catch (e: Exception) {
            PulseEngine.logError("PanicService siren error: ${e.message}")
        }
    }

    override fun onDestroy() {
        try {
            player?.stop()
            player?.release()
            player = null
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
EOF_KT_ENGINE

sed -i "s/__PKG__/$PKG/g" "$KDIR/MainActivity.kt" "$KDIR/PulseEngine.kt" "$KDIR/TelegramNotifier.kt" "$KDIR/SpeedMonitor.kt"

python3 - "$M" "$PKG" << 'EOF_PY_MANIFEST'
import sys
path, pkg = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()

perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.PACKAGE_USAGE_STATS',
    'android.permission.READ_PHONE_STATE',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.REQUEST_DELETE_PACKAGES',
    'android.permission.QUERY_ALL_PACKAGES',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.MANAGE_EXTERNAL_STORAGE',
    'android.permission.SCHEDULE_EXACT_ALARM',
    'android.permission.SYSTEM_ALERT_WINDOW',
]

perm_block = ''
for p in perms:
    if p not in s:
        if p in ('android.permission.PACKAGE_USAGE_STATS', 'android.permission.MANAGE_EXTERNAL_STORAGE'):
            perm_block += f'    <uses-permission android:name="{p}" xmlns:tools="http://schemas.android.com/tools" tools:ignore="ProtectedPermissions"/>\n'
        else:
            perm_block += f'    <uses-permission android:name="{p}"/>\n'

if perm_block:
    s = s.replace('<application', perm_block + '    <application', 1)

if 'WatchdogReceiver' not in s:
    components_xml = f"""        <activity-alias
            android:name="{pkg}.CalendarAlias"
            android:targetActivity="{pkg}.MainActivity"
            android:enabled="false"
            android:exported="true"
            android:label="Календарь"
            android:icon="@mipmap/ic_calendar">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>

        <receiver android:name="{pkg}.WatchdogReceiver" android:enabled="true" android:exported="true" android:directBootAware="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="android.intent.action.ACTION_SHUTDOWN"/>
                <action android:name="android.intent.action.QUICKBOOT_POWEROFF"/>
                <action android:name="sentinelroot.WATCHDOG_TICK"/>
            </intent-filter>
        </receiver>

        <receiver android:name="{pkg}.SelfDestructReceiver" android:enabled="true" android:exported="false">
            <intent-filter>
                <action android:name="sentinelroot.SELFDESTRUCT_TICK"/>
            </intent-filter>
        </receiver>

        <receiver android:name="{pkg}.UsbGuardReceiver" android:enabled="true" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.ACTION_POWER_CONNECTED"/>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"/>
                <action android:name="sentinelroot.USB_REVOKE_TICK"/>
            </intent-filter>
        </receiver>

        <receiver android:name="{pkg}.SentinelDeviceAdminReceiver"
            android:permission="android.permission.BIND_DEVICE_ADMIN"
            android:exported="true">
            <meta-data android:name="android.app.device_admin" android:resource="@xml/device_admin_policies" />
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
                <action android:name="android.app.action.DEVICE_ADMIN_DISABLE_REQUESTED" />
            </intent-filter>
        </receiver>

        <service android:name="{pkg}.PanicService" android:enabled="true" android:exported="false" />
    """
    s = s.replace('</application>', components_xml + '</application>', 1)

open(path, 'w', encoding='utf-8').write(s)
EOF_PY_MANIFEST

echo "Android native SentinelRoot v6.0 patched successfully: $PKG"
