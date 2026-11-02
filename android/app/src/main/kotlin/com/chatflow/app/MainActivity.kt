package com.chatflow.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.chatflow.app/channel"
    private var pendingSafResult: MethodChannel.Result? = null
    private val REQUEST_CODE_SAF = 9921

    private val directWhatsappPaths = listOf(
        // WhatsApp Standard
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
        "/storage/emulated/0/WhatsApp/Media/.Statuses",
        "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
        "/sdcard/WhatsApp/Media/.Statuses",
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/Statuses",
        "/storage/emulated/0/WhatsApp/Media/Statuses",

        // WhatsApp Business
        "/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses",
        "/storage/emulated/0/WhatsApp Business/Media/.Statuses",
        "/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses",
        "/sdcard/WhatsApp Business/Media/.Statuses",
        "/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/Statuses",
        "/storage/emulated/0/WhatsApp Business/Media/Statuses",

        // Cloned / Dual Apps (Samsung Dual Messenger, Xiaomi Dual Apps, OnePlus Parallel)
        "/storage/emulated/999/Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
        "/storage/emulated/999/WhatsApp/Media/.Statuses",
        "/storage/emulated/999/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses",
        "/storage/emulated/999/WhatsApp Business/Media/.Statuses",
        "/storage/emulated/10/Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
        "/storage/emulated/10/WhatsApp/Media/.Statuses",
        "/storage/emulated/11/Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
        "/storage/emulated/11/WhatsApp/Media/.Statuses",

        // Modded WhatsApp variants (GBWhatsApp, YoWhatsApp, FMWhatsApp)
        "/storage/emulated/0/Android/media/com.gbwhatsapp/GBWhatsApp/Media/.Statuses",
        "/storage/emulated/0/GBWhatsApp/Media/.Statuses",
        "/storage/emulated/0/Android/media/com.fmwhatsapp/FMWhatsApp/Media/.Statuses",
        "/storage/emulated/0/Android/media/com.yowhatsapp/YoWhatsApp/Media/.Statuses"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> {
                    val filePath = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = mimeType
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            val chooser = Intent.createChooser(intent, "Share Status via")
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "openFile" -> {
                    val filePath = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mimeType)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "isNotificationAccessGranted" -> {
                    try {
                        val enabledListeners = android.provider.Settings.Secure.getString(
                            contentResolver,
                            "enabled_notification_listeners"
                        )
                        val isGranted = enabledListeners?.contains(packageName) == true
                        result.success(isGranted)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    val title = call.argument<String>("title") ?: "Share via"
                    if (text != null) {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        val chooser = Intent.createChooser(intent, title)
                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(chooser)
                        result.success(true)
                    } else {
                        result.error("INVALID_TEXT", "Text is null", null)
                    }
                }
                "isManageStorageGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "requestManageStorage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val fallbackIntent = Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("PERMISSION_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "requestStatusFolderAccess" -> {
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            val targetUri = Uri.parse("content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses")
                            putExtra("android.provider.extra.INITIAL_URI", targetUri)
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                            )
                        }
                        pendingSafResult = result
                        startActivityForResult(intent, REQUEST_CODE_SAF)
                    } catch (e: Exception) {
                        result.error("SAF_LAUNCH_ERROR", e.message, null)
                    }
                }
                "isStatusFolderPermissionGranted" -> {
                    val prefs = getSharedPreferences("chatflow_prefs", Context.MODE_PRIVATE)
                    val savedUri = prefs.getString("status_tree_uri", null)
                    result.success(savedUri != null)
                }
                "getStatusMedia" -> {
                    Thread {
                        val fileList = mutableListOf<String>()
                        val visitedPaths = HashSet<String>()

                        val searchPaths = mutableListOf<String>()
                        searchPaths.addAll(directWhatsappPaths)

                        val extDir = Environment.getExternalStorageDirectory()
                        if (extDir != null) {
                            searchPaths.add(File(extDir, "Android/media/com.whatsapp/WhatsApp/Media/.Statuses").absolutePath)
                            searchPaths.add(File(extDir, "WhatsApp/Media/.Statuses").absolutePath)
                            searchPaths.add(File(extDir, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses").absolutePath)
                            searchPaths.add(File(extDir, "WhatsApp Business/Media/.Statuses").absolutePath)
                            searchPaths.add(File(extDir, "Android/media/com.whatsapp/WhatsApp/Media/Statuses").absolutePath)
                            searchPaths.add(File(extDir, "WhatsApp/Media/Statuses").absolutePath)
                            searchPaths.add(File(extDir, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/Statuses").absolutePath)
                            searchPaths.add(File(extDir, "WhatsApp Business/Media/Statuses").absolutePath)
                        }

                        // 1. Direct scan without restrictive canRead or exists check (handles all Android 11-16 versions)
                        for (dirPath in searchPaths) {
                            try {
                                val dir = File(dirPath)
                                val files = dir.listFiles()
                                if (files != null && files.isNotEmpty()) {
                                    for (f in files) {
                                        if (f.isFile && !f.name.startsWith(".nomedia") && !f.name.endsWith(".tmp") && !f.name.endsWith(".thumb")) {
                                            val ext = f.name.substringAfterLast('.', "").lowercase()
                                            if (ext in listOf("jpg", "jpeg", "png", "webp", "mp4", "mkv", "3gp", "mov", "gif")) {
                                                if (visitedPaths.add(f.absolutePath)) {
                                                    fileList.add(f.absolutePath)
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch (_: Exception) {}
                        }

                        // 2. Legacy SAF Tree Uri fallback (if previously granted)
                        val prefs = getSharedPreferences("chatflow_prefs", Context.MODE_PRIVATE)
                        val savedUriStr = prefs.getString("status_tree_uri", null)
                        if (savedUriStr != null) {
                            try {
                                val treeUri = Uri.parse(savedUriStr)
                                val rootDoc = DocumentFile.fromTreeUri(applicationContext, treeUri)
                                val files = rootDoc?.listFiles()
                                val cacheDir = File(cacheDir, "statuses_cache")
                                if (!cacheDir.exists()) cacheDir.mkdirs()

                                if (files != null) {
                                    for (doc in files) {
                                        if (doc.isFile && doc.name != null && !doc.name!!.startsWith(".nomedia") && !doc.name!!.endsWith(".tmp")) {
                                            val ext = doc.name!!.substringAfterLast('.', "").lowercase()
                                            if (ext in listOf("jpg", "jpeg", "png", "webp", "mp4", "mkv", "3gp", "mov", "gif")) {
                                                val cachedFile = File(cacheDir, doc.name!!)
                                                if (!cachedFile.exists() || cachedFile.length() != doc.length()) {
                                                    contentResolver.openInputStream(doc.uri)?.use { input ->
                                                        cachedFile.outputStream().use { output ->
                                                            input.copyTo(output)
                                                        }
                                                    }
                                                }
                                                if (visitedPaths.add(cachedFile.absolutePath)) {
                                                    fileList.add(cachedFile.absolutePath)
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch (_: Exception) {}
                        }

                        runOnUiThread {
                            result.success(fileList)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SAF) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    getSharedPreferences("chatflow_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .putString("status_tree_uri", uri.toString())
                        .apply()
                    pendingSafResult?.success(true)
                } catch (e: Exception) {
                    pendingSafResult?.success(false)
                }
            } else {
                pendingSafResult?.success(false)
            }
            pendingSafResult = null
        }
    }
}
