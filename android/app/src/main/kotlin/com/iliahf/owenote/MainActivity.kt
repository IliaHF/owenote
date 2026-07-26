package com.iliahf.owenote

import android.Manifest
import android.app.DownloadManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.iliahf.owenote/updater"
    private val backupChannelName = "com.iliahf.owenote/backup"
    private val storagePermissionRequestCode = 4102
    private val preferencesName = "owenote_updater"
    private val downloadIdKey = "download_id"
    private val downloadVersionKey = "download_version"
    private val downloadPathKey = "download_path"
    private var pendingApk: File? = null

    private data class PendingBackup(
        val fileName: String,
        val contents: String,
        val result: MethodChannel.Result
    )

    private var pendingBackup: PendingBackup? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveBackup") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val fileName = call.argument<String>("fileName")
                val contents = call.argument<String>("contents")
                if (fileName.isNullOrBlank() || contents == null) {
                    result.error(
                        "invalid_backup",
                        "The backup export information is incomplete.",
                        null
                    )
                } else {
                    saveBackupWithPermission(fileName, contents, result)
                }
            }
    }

    private fun saveBackupWithPermission(
        fileName: String,
        contents: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.M until Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingBackup != null) {
                result.error("backup_busy", "Another backup export is in progress.", null)
                return
            }
            pendingBackup = PendingBackup(fileName, contents, result)
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                storagePermissionRequestCode
            )
            return
        }
        completeBackupSave(fileName, contents, result)
    }

    private fun completeBackupSave(
        fileName: String,
        contents: String,
        result: MethodChannel.Result
    ) {
        try {
            result.success(saveBackupToDownloads(fileName, contents))
        } catch (error: Exception) {
            result.error(
                "backup_error",
                error.message ?: "The backup could not be saved.",
                null
            )
        }
    }

    private fun saveBackupToDownloads(fileName: String, contents: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values
            ) ?: throw IllegalStateException("Android Downloads is unavailable.")
            try {
                val output = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("The backup file could not be opened.")
                output.bufferedWriter(Charsets.UTF_8).use { writer ->
                    writer.write(contents)
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            return "${Environment.DIRECTORY_DOWNLOADS}/$fileName"
        }

        val directory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Android Downloads is unavailable.")
        }
        val file = File(directory, fileName)
        file.writeText(contents, Charsets.UTF_8)
        return file.absolutePath
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != storagePermissionRequestCode) return
        val backup = pendingBackup ?: return
        pendingBackup = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            completeBackupSave(backup.fileName, backup.contents, backup.result)
        } else {
            backup.result.error(
                "storage_permission_denied",
                "Storage permission is required to save the backup to Downloads.",
                null
            )
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
