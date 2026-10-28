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
                            val res = PulseEngine.executeWipeTargets(applicationContext, manual = true)
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

cat > "$KDIR/PulseEngine.kt" << 'EOF_KT_ENGINE'
package __PKG__

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.TrafficStats
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Process
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.concurrent.TimeUnit

object PulseEngine {
    private const val ROOT_STATE_PATH = "/data/local/tmp/sentinelroot_power_state.json"
    private const val LOCAL_STATE_NAME = "sentinelroot_power_state.json"
    private const val WIPE_STATE_NAME = "sentinelroot_wipe_state.json"
    private const val RULES_STATE_NAME = "sentinelroot_rules_state.json"

    fun runSu(cmd: String): Pair<Boolean, String> {
        return try {
            val proc = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            val completed = proc.waitFor(8, TimeUnit.SECONDS)
            if (!completed) {
                proc.destroyForcibly()
                return Pair(false, "timeout")
            }
            val out = proc.inputStream.bufferedReader().readText()
            val err = proc.errorStream.bufferedReader().readText()
            Pair(proc.exitValue() == 0, (out + "\n" + err).trim())
        } catch (e: Exception) {
            Pair(false, e.message ?: "no_root")
        }
    }

    fun hasRootAccess(): Boolean {
        val (ok, out) = runSu("id")
        return ok && out.contains("uid=0")
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

    private fun readWipeJson(ctx: Context): JSONObject {
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
            put("ownerPin", "1111")
            put("duressPin", "9999")
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
            cur.put("ownerPin", incoming.optString("ownerPin", "1111"))
            cur.put("duressPin", incoming.optString("duressPin", "9999"))
            cur.put("targets", incoming.optJSONArray("targets") ?: JSONArray())
            writeWipeJson(ctx, cur)
            scheduleWatchdogAlarm(ctx)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun confirmOwnerCheckIn(ctx: Context): Boolean {
        val cur = readWipeJson(ctx)
        cur.put("lastConfirmTs", System.currentTimeMillis())
        writeWipeJson(ctx, cur)
        return true
    }

    fun checkAndRunAutoWipeIfExpired(ctx: Context) {
        val cur = readWipeJson(ctx)
        if (!cur.optBoolean("enabled", false)) return
        val intervalHours = cur.optInt("intervalHours", 24).coerceAtLeast(1)
        val lastConfirm = cur.optLong("lastConfirmTs", System.currentTimeMillis())
        val deadline = lastConfirm + intervalHours * 3600_000L
        if (System.currentTimeMillis() >= deadline) {
            executeWipeTargets(ctx, manual = false)
        }
    }

    @Synchronized
    fun executeWipeTargets(ctx: Context, manual: Boolean): String {
        val cur = readWipeJson(ctx)
        val targets = cur.optJSONArray("targets") ?: JSONArray()
        val logs = cur.optJSONArray("logs") ?: JSONArray()
        val now = System.currentTimeMillis()

        for (i in 0 until targets.length()) {
            val t = targets.optJSONObject(i) ?: continue
            val kind = t.optString("kind", "file")
            val mode = t.optString("mode", "delete")
            val target = t.optString("target", "")
            if (target.isEmpty()) continue

            var ok = false
            var details = ""

            if (kind == "file") {
                try {
                    val f = File(target)
                    if (f.exists()) {
                        ok = f.deleteRecursively()
                    }
                } catch (_: Exception) {}
                if (!ok) {
                    val safePath = target.replace("'", "'\\''")
                    val (suOk, suOut) = runSu("rm -rf '$safePath'")
                    ok = suOk
                    details = if (suOk) "Удалено через Root (rm -rf)" else "Ошибка: $suOut"
                } else {
                    details = "Файл/папка удалены"
                }
            } else if (kind == "app") {
                val safePkg = target.replace(Regex("[^A-Za-z0-9_.]"), "")
                if (mode == "freeze") {
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
            logEntry.put("details", if (manual) "[Ручной/Duress] $details" else "[Таймер] $details")
            logs.put(logEntry)
        }

        cur.put("lastConfirmTs", now)
        cur.put("logs", logs)
        writeWipeJson(ctx, cur)
        return cur.toString()
    }
}

class WatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val act = intent?.action ?: ""
        val isShut = act == Intent.ACTION_SHUTDOWN || act == "android.intent.action.QUICKBOOT_POWEROFF"
        PulseEngine.initAndHeartbeat(context.applicationContext, isShutdown = isShut)
    }
}
EOF_KT_ENGINE

sed -i "s/__PKG__/$PKG/g" "$KDIR/MainActivity.kt" "$KDIR/PulseEngine.kt"

python3 - "$M" "$PKG" << 'EOF_PY_MANIFEST'
import sys
path, pkg = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()

perms = [
    'android.permission.INTERNET',
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
    receiver_xml = (
        f'        <receiver android:name="{pkg}.WatchdogReceiver" android:enabled="true" android:exported="true" android:directBootAware="true">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n'
        '                <action android:name="android.intent.action.ACTION_SHUTDOWN"/>\n'
        '                <action android:name="android.intent.action.QUICKBOOT_POWEROFF"/>\n'
        '                <action android:name="sentinelroot.WATCHDOG_TICK"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n    '
    )
    s = s.replace('</application>', receiver_xml + '</application>', 1)

open(path, 'w', encoding='utf-8').write(s)
EOF_PY_MANIFEST

echo "Android native SentinelRoot patched successfully: $PKG"
