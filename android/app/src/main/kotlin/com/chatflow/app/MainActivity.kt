package com.chatflow.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import android.media.MediaMetadataRetriever
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
                "getVideoThumbnail" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        Thread {
                            try {
                                val file = File(filePath)
                                if (file.exists()) {
                                    val retriever = MediaMetadataRetriever()
                                    retriever.setDataSource(filePath)
                                    val bitmap = retriever.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                        ?: retriever.frameAtTime
                                    retriever.release()
                                    if (bitmap != null) {
                                        val scaled = if (bitmap.width > 360) {
                                            val ratio = 360f / bitmap.width
                                            android.graphics.Bitmap.createScaledBitmap(bitmap, 360, (bitmap.height * ratio).toInt(), true)
                                        } else {
                                            bitmap
                                        }
                                        val stream = java.io.ByteArrayOutputStream()
                                        scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, stream)
                                        val bytes = stream.toByteArray()
                                        runOnUiThread {
                                            result.success(bytes)
                                        }
                                        return@Thread
                                    }
                                }
                            } catch (_: Exception) {}
                            runOnUiThread {
                                result.success(null)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "playVideoFullscreen" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        try {
                            val videoFile = File(filePath)
                            val dialog = android.app.Dialog(this, android.R.style.Theme_Black_NoTitleBar_Fullscreen)
                            dialog.requestWindowFeature(android.view.Window.FEATURE_NO_TITLE)
                            dialog.window?.setFlags(
                                android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN,
                                android.view.WindowManager.LayoutParams.FLAG_FULLSCREEN
                            )
                            dialog.window?.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

                            val root = android.widget.FrameLayout(this).apply {
                                setBackgroundColor(android.graphics.Color.BLACK)
                                layoutParams = android.widget.FrameLayout.LayoutParams(
                                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT
                                )
                            }

                            val videoView = android.widget.VideoView(this).apply {
                                layoutParams = android.widget.FrameLayout.LayoutParams(
                                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                                    android.view.Gravity.CENTER
                                )
                            }
                            root.addView(videoView)

                            val mediaController = android.widget.MediaController(this)
                            mediaController.setAnchorView(videoView)
                            videoView.setMediaController(mediaController)

                            val topBar = android.widget.RelativeLayout(this).apply {
                                setBackgroundColor(android.graphics.Color.parseColor("#99000000"))
                                val dp12 = (12 * resources.displayMetrics.density).toInt()
                                val dp36 = (36 * resources.displayMetrics.density).toInt()
                                setPadding(dp12, dp36, dp12, dp12)
                                layoutParams = android.widget.FrameLayout.LayoutParams(
                                    android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                                    android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
                                    android.view.Gravity.TOP
                                )
                            }

                            val closeBtn = android.widget.ImageView(this).apply {
                                id = android.view.View.generateViewId()
                                val dp40 = (40 * resources.displayMetrics.density).toInt()
                                val dp8 = (8 * resources.displayMetrics.density).toInt()
                                layoutParams = android.widget.RelativeLayout.LayoutParams(dp40, dp40).apply {
                                    addRule(android.widget.RelativeLayout.ALIGN_PARENT_START)
                                    addRule(android.widget.RelativeLayout.CENTER_VERTICAL)
                                }
                                setPadding(dp8, dp8, dp8, dp8)
                                setImageResource(android.R.drawable.ic_menu_revert)
                                setColorFilter(android.graphics.Color.WHITE)
                                setOnClickListener { dialog.dismiss() }
                            }
                            topBar.addView(closeBtn)

                            val titleView = android.widget.TextView(this).apply {
                                val dp8 = (8 * resources.displayMetrics.density).toInt()
                                layoutParams = android.widget.RelativeLayout.LayoutParams(
                                    android.widget.RelativeLayout.LayoutParams.WRAP_CONTENT,
                                    android.widget.RelativeLayout.LayoutParams.WRAP_CONTENT
                                ).apply {
                                    addRule(android.widget.RelativeLayout.RIGHT_OF, closeBtn.id)
                                    addRule(android.widget.RelativeLayout.CENTER_VERTICAL)
                                    setMargins(dp8, 0, dp8, 0)
                                }
                                text = videoFile.name
                                setTextColor(android.graphics.Color.WHITE)
                                textSize = 15f
                                setTypeface(null, android.graphics.Typeface.BOLD)
                                maxLines = 1
                                ellipsize = android.text.TextUtils.TruncateAt.END
                            }
                            topBar.addView(titleView)

                            val actionsLayout = android.widget.LinearLayout(this).apply {
                                orientation = android.widget.LinearLayout.HORIZONTAL
                                layoutParams = android.widget.RelativeLayout.LayoutParams(
                                    android.widget.RelativeLayout.LayoutParams.WRAP_CONTENT,
                                    android.widget.RelativeLayout.LayoutParams.WRAP_CONTENT
                                ).apply {
                                    addRule(android.widget.RelativeLayout.ALIGN_PARENT_END)
                                    addRule(android.widget.RelativeLayout.CENTER_VERTICAL)
                                }
                            }

                            val saveBtn = android.widget.ImageView(this).apply {
                                val dp40 = (40 * resources.displayMetrics.density).toInt()
                                val dp8 = (8 * resources.displayMetrics.density).toInt()
                                layoutParams = android.widget.LinearLayout.LayoutParams(dp40, dp40).apply {
                                    setMargins(0, 0, dp8, 0)
                                }
                                setPadding(dp8, dp8, dp8, dp8)
                                setImageResource(android.R.drawable.ic_menu_save)
                                setColorFilter(android.graphics.Color.WHITE)
                                setOnClickListener {
                                    try {
                                        val picturesDir = File("/storage/emulated/0/Pictures/Chatflow")
                                        if (!picturesDir.exists()) picturesDir.mkdirs()
                                        val target = File(picturesDir, videoFile.name)
                                        videoFile.copyTo(target, overwrite = true)
                                        android.widget.Toast.makeText(this@MainActivity, "Saved to Pictures/Chatflow!", android.widget.Toast.LENGTH_SHORT).show()
                                    } catch (e: Exception) {
                                        android.widget.Toast.makeText(this@MainActivity, "Save failed: ${e.message}", android.widget.Toast.LENGTH_SHORT).show()
                                    }
                                }
                            }
                            actionsLayout.addView(saveBtn)

                            val shareBtn = android.widget.ImageView(this).apply {
                                val dp40 = (40 * resources.displayMetrics.density).toInt()
                                val dp8 = (8 * resources.displayMetrics.density).toInt()
                                layoutParams = android.widget.LinearLayout.LayoutParams(dp40, dp40)
                                setPadding(dp8, dp8, dp8, dp8)
                                setImageResource(android.R.drawable.ic_menu_share)
                                setColorFilter(android.graphics.Color.WHITE)
                                setOnClickListener {
                                    try {
                                        val uri = androidx.core.content.FileProvider.getUriForFile(
                                            this@MainActivity,
                                            "${packageName}.fileprovider",
                                            videoFile
                                        )
                                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                            type = "video/mp4"
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                        startActivity(Intent.createChooser(shareIntent, "Share Status Video"))
                                    } catch (e: Exception) {
                                        android.widget.Toast.makeText(this@MainActivity, "Share failed: ${e.message}", android.widget.Toast.LENGTH_SHORT).show()
                                    }
                                }
                            }
                            actionsLayout.addView(shareBtn)
                            topBar.addView(actionsLayout)

                            root.addView(topBar)

                            dialog.setContentView(root)

                            videoView.setVideoPath(filePath)
                            videoView.setOnPreparedListener { mp ->
                                mp.isLooping = true
                                videoView.start()
                            }
                            dialog.setOnDismissListener {
                                videoView.stopPlayback()
                            }

                            dialog.show()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PLAY_ERROR", e.message, null)
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
