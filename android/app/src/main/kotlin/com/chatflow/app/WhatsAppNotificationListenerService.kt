package com.chatflow.app

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WhatsAppNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val FILE_NAME = "chatflow_captured_notifications.json"
        private const val MAX_MESSAGES = 1000

        private val TARGET_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "com.gbwhatsapp",
            "com.yowhatsapp",
            "com.fmwhatsapp"
        )

        var onNewMessageCallback: ((Map<String, Any>) -> Unit)? = null

        @Synchronized
        fun getArchivedNotifications(context: Context): List<Map<String, Any>> {
            val list = mutableListOf<Map<String, Any>>()
            try {
                val file = File(context.filesDir, FILE_NAME)
                if (!file.exists()) return list

                val content = file.readText()
                if (content.isEmpty()) return list

                val jsonArray = JSONArray(content)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val map = mutableMapOf<String, Any>()
                    map["id"] = obj.optString("id", "")
                    map["sender"] = obj.optString("sender", "")
                    map["message"] = obj.optString("message", "")
                    map["isDeleted"] = obj.optBoolean("isDeleted", false)
                    map["packageName"] = obj.optString("packageName", "com.whatsapp")
                    map["timestamp"] = obj.optString("timestamp", "")
                    map["type"] = obj.optString("type", "text")
                    list.add(map)
                }
            } catch (_: Exception) {}
            return list
        }

        @Synchronized
        fun clearArchivedNotifications(context: Context): Boolean {
            return try {
                val file = File(context.filesDir, FILE_NAME)
                if (file.exists()) {
                    file.delete()
                } else true
            } catch (_: Exception) {
                false
            }
        }

        @Synchronized
        fun saveNotificationItem(context: Context, item: JSONObject) {
            try {
                val file = File(context.filesDir, FILE_NAME)
                val jsonArray = if (file.exists() && file.length() > 0) {
                    try {
                        JSONArray(file.readText())
                    } catch (_: Exception) {
                        JSONArray()
                    }
                } else {
                    JSONArray()
                }

                val isDeleted = item.optBoolean("isDeleted", false)
                val sender = item.optString("sender", "")

                if (isDeleted && sender.isNotEmpty()) {
                    var marked = false
                    // Search backward for the most recent message from this sender
                    for (i in jsonArray.length() - 1 downTo 0) {
                        val prev = jsonArray.getJSONObject(i)
                        if (prev.optString("sender") == sender && !prev.optBoolean("isDeleted", false)) {
                            prev.put("isDeleted", true)
                            marked = true
                            break
                        }
                    }
                    if (!marked) {
                        jsonArray.put(item)
                    }
                } else {
                    // Check duplicate consecutive notification within short time
                    val message = item.optString("message", "")
                    var isDup = false
                    if (jsonArray.length() > 0) {
                        val last = jsonArray.getJSONObject(jsonArray.length() - 1)
                        if (last.optString("sender") == sender &&
                            last.optString("message") == message &&
                            !last.optBoolean("isDeleted", false)
                        ) {
                            isDup = true
                        }
                    }
                    if (!isDup) {
                        jsonArray.put(item)
                    }
                }

                // Trim to MAX_MESSAGES
                val trimmedArray = if (jsonArray.length() > MAX_MESSAGES) {
                    val newArr = JSONArray()
                    val start = jsonArray.length() - MAX_MESSAGES
                    for (i in start until jsonArray.length()) {
                        newArr.put(jsonArray.getJSONObject(i))
                    }
                    newArr
                } else {
                    jsonArray
                }

                file.writeText(trimmedArray.toString())
            } catch (_: Exception) {}
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName ?: return

        if (!TARGET_PACKAGES.contains(packageName)) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim() ?: ""
        val conversationTitle = extras.getCharSequence("android.conversationTitle")?.toString()?.trim()

        if (title.isEmpty() && text.isEmpty()) return

        val lowerText = text.lowercase()
        val lowerTitle = title.lowercase()
        if (isIgnoredNotification(lowerTitle, lowerText)) return

        var senderName = title
        var messageText = text

        if (!conversationTitle.isNullOrEmpty()) {
            senderName = conversationTitle
            if (title.isNotEmpty() && !messageText.startsWith("$title:")) {
                messageText = "$title: $messageText"
            }
        }

        if (senderName.isEmpty()) {
            senderName = "WhatsApp User"
        }

        val isDeleted = isDeletedNotice(lowerText)

        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
        val timestamp = sdf.format(Date(sbn.postTime))

        val jsonObj = JSONObject().apply {
            put("id", "${sbn.id}_${sbn.postTime}")
            put("sender", senderName)
            put("message", if (isDeleted) "This message was deleted" else messageText)
            put("isDeleted", isDeleted)
            put("packageName", packageName)
            put("timestamp", timestamp)
            put("type", "text")
        }

        saveNotificationItem(applicationContext, jsonObj)

        try {
            val map = mutableMapOf<String, Any>()
            map["id"] = jsonObj.getString("id")
            map["sender"] = jsonObj.getString("sender")
            map["message"] = jsonObj.getString("message")
            map["isDeleted"] = jsonObj.getBoolean("isDeleted")
            map["packageName"] = jsonObj.getString("packageName")
            map["timestamp"] = jsonObj.getString("timestamp")
            map["type"] = "text"

            onNewMessageCallback?.invoke(map)
        } catch (_: Exception) {}
    }

    private fun isDeletedNotice(lower: String): Boolean {
        return lower.contains("this message was deleted") ||
                lower.contains("message was deleted") ||
                lower.contains("deleted this message") ||
                lower.contains("message has been deleted") ||
                lower.contains("you deleted this message") ||
                lower.contains("यह संदेश हटा दिया गया") ||
                lower.contains("संदेश हटा दिया गया था") ||
                lower.contains("delete kar diya")
    }

    private fun isIgnoredNotification(lowerTitle: String, lowerText: String): Boolean {
        val combined = "$lowerTitle $lowerText"
        return combined.contains("checking for new messages") ||
                combined.contains("whatsapp web is currently active") ||
                combined.contains("whatsapp web logged in") ||
                combined.contains("backup in progress") ||
                combined.contains("finished backup") ||
                combined.contains("searching for new messages") ||
                combined.contains("calling...") ||
                combined.contains("incoming call") ||
                combined.contains("missed voice call") ||
                combined.contains("missed video call") ||
                combined.contains("outgoing call")
    }
}

