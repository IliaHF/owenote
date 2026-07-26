package com.iliahf.owenote

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.iliahf.owenote/updater"
    private val preferencesName = "owenote_updater"
    private val downloadIdKey = "download_id"
    private val downloadVersionKey = "download_version"
    private val downloadPathKey = "download_path"
    private var pendingApk: File? = null

    private val downloadManager: DownloadManager
        get() = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cleanupInstalledUpdate()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getVersion" -> result.success(currentVersion())
                        "getDownloadStatus" -> result.success(downloadStatus())
                        "startDownload" -> {
                            val url = call.argument<String>("url")
                            val version = call.argument<String>("version")
                            if (url.isNullOrBlank() || version.isNullOrBlank()) {
                                result.error(
                                    "invalid_download",
                                    "The update download information is incomplete.",
                                    null
                                )
                            } else {
                                result.success(startDownload(url, version))
                            }
                        }
                        "installDownloadedUpdate" -> {
                            installDownloadedUpdate()
                            result.success(null)
                        }
                        "openUrl" -> {
                            val url = call.argument<String>("url")
                            if (url.isNullOrBlank()) {
                                result.error("invalid_url", "The link is invalid.", null)
                            } else {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "update_error",
                        error.message ?: "The update operation failed.",
                        null
                    )
                }
            }
    }

    private fun currentVersion(): String =
        packageManager.getPackageInfo(packageName, 0).versionName ?: "Unknown"

    private fun startDownload(url: String, version: String): Map<String, Any?> {
        val existingVersion = updaterPreferences().getString(downloadVersionKey, null)
        val existingStatus = downloadStatus()
        if (existingVersion == version &&
            (existingStatus["phase"] == "downloading" ||
                existingStatus["phase"] == "ready")
        ) {
            return existingStatus
        }

        clearStoredDownload()
        val downloadsDirectory =
            getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: throw IllegalStateException("Update storage is unavailable.")
        val apk = File(downloadsDirectory, "OweNote-$version.apk")
        if (apk.exists() && !isValidApk(apk)) apk.delete()
        if (isValidApk(apk)) {
            updaterPreferences().edit()
                .putString(downloadVersionKey, version)
                .putString(downloadPathKey, apk.absolutePath)
                .apply()
            return statusMap("ready", version, apk.length(), apk.length())
        }

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("OweNote $version")
            .setDescription("Downloading app update")
            .setMimeType("application/vnd.android.package-archive")
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setDestinationInExternalFilesDir(
                this,
                Environment.DIRECTORY_DOWNLOADS,
                apk.name
            )
        request.addRequestHeader("User-Agent", "OweNote Android updater")
        val downloadId = downloadManager.enqueue(request)
        updaterPreferences().edit()
            .putLong(downloadIdKey, downloadId)
            .putString(downloadVersionKey, version)
            .putString(downloadPathKey, apk.absolutePath)
            .apply()
        return statusMap("downloading", version, 0, 0)
    }

    private fun downloadStatus(): Map<String, Any?> {
        val preferences = updaterPreferences()
        val version = preferences.getString(downloadVersionKey, null)
            ?: return statusMap("idle", null, 0, 0)
        val path = preferences.getString(downloadPathKey, null)
        val apk = path?.let(::File)
        val downloadId = preferences.getLong(downloadIdKey, -1L)

        if (downloadId < 0) {
            return if (apk != null && isValidApk(apk)) {
                statusMap("ready", version, apk.length(), apk.length())
            } else {
                statusMap("idle", null, 0, 0)
            }
        }

        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query)?.use { cursor ->
            if (!cursor.moveToFirst()) {
                return if (apk != null && isValidApk(apk)) {
                    statusMap("ready", version, apk.length(), apk.length())
                } else {
                    statusMap("failed", version, 0, 0, "Download was interrupted.")
                }
            }

            val status = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            )
            val downloaded = cursor.getLong(
                cursor.getColumnIndexOrThrow(
                    DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR
                )
            )
            val total = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            )
            return when (status) {
                DownloadManager.STATUS_SUCCESSFUL ->
                    if (apk != null && isValidApk(apk)) {
                        statusMap("ready", version, downloaded, total)
                    } else {
                        statusMap("failed", version, downloaded, total, "Downloaded APK is invalid.")
                    }
                DownloadManager.STATUS_FAILED -> {
                    val reason = cursor.getInt(
                        cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
                    )
                    statusMap(
                        "failed",
                        version,
                        downloaded,
                        total,
                        "Android download error $reason."
                    )
                }
                else -> statusMap("downloading", version, downloaded, total)
            }
        }
        return statusMap("failed", version, 0, 0, "Download status is unavailable.")
    }

    private fun statusMap(
        phase: String,
        version: String?,
        downloadedBytes: Long,
        totalBytes: Long,
        error: String? = null
    ): Map<String, Any?> = hashMapOf(
        "phase" to phase,
        "version" to version,
        "downloadedBytes" to downloadedBytes.coerceAtLeast(0),
        "totalBytes" to totalBytes.coerceAtLeast(0),
        "error" to error
    )

    private fun installDownloadedUpdate() {
        val path = updaterPreferences().getString(downloadPathKey, null)
        val apk = path?.let(::File)
        if (apk == null || !isValidApk(apk)) {
            throw IllegalStateException("The downloaded update could not be found.")
        }
        installApk(apk)
    }

    private fun isValidApk(apk: File): Boolean =
        apk.exists() && packageManager.getPackageArchiveInfo(apk.absolutePath, 0) != null

    private fun installApk(apk: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingApk = apk
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
            return
        }

        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
        pendingApk = null
    }

    private fun cleanupInstalledUpdate() {
        val preferences = updaterPreferences()
        if (preferences.getString(downloadVersionKey, null) == currentVersion()) {
            clearStoredDownload()
        }
    }

    private fun clearStoredDownload() {
        val preferences = updaterPreferences()
        val downloadId = preferences.getLong(downloadIdKey, -1L)
        if (downloadId >= 0) downloadManager.remove(downloadId)
        preferences.getString(downloadPathKey, null)?.let { File(it).delete() }
        preferences.edit().clear().apply()
    }

    private fun updaterPreferences() =
        getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

    override fun onResume() {
        super.onResume()
        val apk = pendingApk ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
        ) {
            installApk(apk)
        }
    }
}
